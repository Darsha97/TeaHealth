import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'history_service.dart'; // uses HistoryItem & streamScans(uid)
import '../../core/localization/app_localizations.dart';
import 'home_page.dart';
import 'history_page.dart';
import 'profile_page.dart';

class MapHistoryPage extends StatefulWidget {
  final String uid;
  const MapHistoryPage({super.key, required this.uid});

  @override
  State<MapHistoryPage> createState() => _MapHistoryPageState();
}

class _MapHistoryPageState extends State<MapHistoryPage> {
  GoogleMapController? _map;
  final _markers = <MarkerId, Marker>{};
  StreamSubscription<Position>? _locationSubscription;
  Position? _currentPosition;
  BitmapDescriptor? _redPinIcon;
  bool _mapReady = false;
  bool _updatingLocation = false;
  Timer? _locationUpdateTimer;

  // cache tiny circle bitmaps per color
  final _dotCache = <int, BitmapDescriptor>{};

  // stable color per label (red removed - reserved for current location)
  final _palette = <Color>[
    const Color(0xFF2ECC71), // green
    const Color(0xFF3498DB), // blue
    const Color(0xFFF1C40F), // yellow
    const Color(0xFF9B59B6), // purple
    const Color(0xFFE67E22), // orange
    const Color(0xFF1ABC9C), // teal
    const Color(0xFF34495E), // dark
    const Color(0xFFe84393), // pink
    const Color(0xFF16a085), // green2
    const Color(0xFF95a5a6), // grey
  ];

  @override
  void initState() {
    super.initState();
    // Delay location tracking to avoid initial rebuild issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLocationTracking();
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }

      // Get initial position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        _currentPosition = position;
        // Only update marker if map is ready
        if (_mapReady) {
          _updateCurrentLocationMarker();
        }
      }

      // Start location stream subscription if map is ready
      if (_mapReady && mounted) {
        _startLocationStream();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Location tracking error: $e');
    }
  }

  void _startLocationStream() {
    // Cancel existing subscription if any
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    
    // Start new location stream with debouncing
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      if (mounted && _mapReady && !_updatingLocation) {
        _currentPosition = position;
        
        // Debounce updates to prevent excessive rebuilds (increased to 2 seconds)
        _locationUpdateTimer?.cancel();
        _locationUpdateTimer = Timer(const Duration(milliseconds: 2000), () {
          if (mounted && _mapReady && !_updatingLocation) {
            _updatingLocation = true;
            _updateCurrentLocationMarkerSilent().then((_) {
              _updatingLocation = false;
            });
          }
        });
      }
    });
  }

  Future<void> _updateCurrentLocationMarker() async {
    if (_currentPosition == null || _map == null || !mounted) return;
    
    try {
      final pinIcon = await _createRedPinIcon();
      final localizations = AppLocalizations.of(context);
      final currentLocationMarker = Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: pinIcon,
        anchor: const Offset(0.5, 0.5), // Center the place icon
        infoWindow: InfoWindow(title: localizations?.myLocation ?? 'My Location'),
      );

      if (mounted) {
        setState(() {
          _markers[const MarkerId('current_location')] = currentLocationMarker;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to update location marker: $e');
    }
  }

  Future<void> _updateCurrentLocationMarkerSilent() async {
    if (_currentPosition == null || _map == null || !mounted) return;
    
    try {
      final pinIcon = await _createRedPinIcon();
      final localizations = AppLocalizations.of(context);
      final currentLocationMarker = Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: pinIcon,
        anchor: const Offset(0.5, 0.5), // Center the place icon
        infoWindow: InfoWindow(title: localizations?.myLocation ?? 'My Location'),
      );

      // Update marker map directly
      final markerId = const MarkerId('current_location');
      final oldMarker = _markers[markerId];
      
      // Only update if position actually changed significantly (more than 10 meters)
      if (oldMarker != null) {
        final oldPos = oldMarker.position;
        final newPos = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        final distance = Geolocator.distanceBetween(
          oldPos.latitude, oldPos.longitude,
          newPos.latitude, newPos.longitude,
        );
        if (distance < 10) {
          return; // Position hasn't changed enough, skip update
        }
      }
      
      _markers[markerId] = currentLocationMarker;
      
      // Trigger minimal rebuild only when map is ready and not updating
      if (mounted && _mapReady && !_updatingLocation) {
        setState(() {
          // Minimal state change to update markers
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to update location marker silently: $e');
    }
  }

  // Get individual diseases from a label (handles comma-separated values)
  List<String> _parseDiseases(String label) {
    if (label.isEmpty) return [];
    // Split by comma and clean up whitespace
    return label
        .split(',')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty && d.toLowerCase() != 'unknown')
        .toList();
  }

  // Get color for a single disease name (consistent color per disease)
  Color _colorForDisease(String diseaseName) {
    final h = diseaseName.trim().toLowerCase().hashCode;
    final idx = h.abs() % _palette.length;
    return _palette[idx];
  }

  // Legacy method for backward compatibility
  Color _colorForLabel(String label) {
    // If label contains comma, use first disease for color
    final diseases = _parseDiseases(label);
    if (diseases.isNotEmpty) {
      return _colorForDisease(diseases.first);
    }
    final h = label.toLowerCase().hashCode;
    final idx = h.abs() % _palette.length;
    return _palette[idx];
  }

  // Helper to darken a color
  Color _darkerColor(Color color) {
    return Color.fromRGBO(
      (color.red * 0.7).round().clamp(0, 255),
      (color.green * 0.7).round().clamp(0, 255),
      (color.blue * 0.7).round().clamp(0, 255),
      1.0,
    );
  }

  Future<BitmapDescriptor> _dot(Color color, {double diameter = 16}) async {
    final key = color.value ^ diameter.toInt();
    if (_dotCache.containsKey(key)) return _dotCache[key]!;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = ui.Size(diameter, diameter);

    final paint = Paint()..color = color;
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3);

    final c = Offset(diameter / 2, diameter / 2);
    canvas.drawCircle(c, diameter / 2.4, shadow);
    canvas.drawCircle(c, diameter / 2.6, paint);

    final img = await recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final bmp = BitmapDescriptor.fromBytes(Uint8List.sublistView(bytes!));
    _dotCache[key] = bmp;
    return bmp;
  }

  // Create red place icon for current location using Icons.place_sharp
  Future<BitmapDescriptor> _createRedPinIcon() async {
    if (_redPinIcon != null) return _redPinIcon!;
    
    const double size = 48.0;
    
    // Convert icon to image using TextPainter
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Render the icon using icon font
    final iconData = Icons.place_sharp;
    final iconSize = size * 0.9;
    final textStyle = TextStyle(
      fontFamily: iconData.fontFamily,
      fontSize: iconSize,
      color: const Color(0xFFE74C3C),
    );
    
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    
    // Draw the icon centered
    iconPainter.paint(
      canvas,
      Offset((size - iconPainter.width) / 2, (size - iconPainter.height) / 2),
    );
    
    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    _redPinIcon = BitmapDescriptor.fromBytes(Uint8List.sublistView(bytes!));
    return _redPinIcon!;
  }

  CameraPosition _cameraFromPoints(List<LatLng> pts) {
    if (pts.isEmpty) {
      return const CameraPosition(target: LatLng(7.8731, 80.7718), zoom: 6.0); // Sri Lanka fallback (edit as you like)
    }
    if (pts.length == 1) {
      return CameraPosition(target: pts.first, zoom: 12);
    }
    double minLat =  90, minLng =  180, maxLat = -90, maxLng = -180;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLat = math.max(maxLat, p.latitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    // GoogleMap's fitBounds isn't exposed directly; we'll set initialCamera and then animate once map ready:
    // We'll store and animate in onMapCreated below using a post-frame callback.
    // For initial fallback, center mid.
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    return CameraPosition(target: center, zoom: 6);
  }

  // build legend chips from disease names
  Widget _legend(List<String> diseases, [int? limit]) {
    final displayDiseases = limit != null ? diseases.take(limit).toList() : diseases;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: displayDiseases.map((disease) {
          final c = _colorForDisease(disease);
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: c.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: c.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  disease,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = HistoryService();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              localizations?.teaHealthMap ?? 'TeaHealth Map',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            );
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      
      body: StreamBuilder<List<HistoryItem>>(
        stream: svc.streamScans(widget.uid, limit: 500),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          localizations?.loadingMap ?? 'Loading map...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }
          if (snap.hasError) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                          const SizedBox(height: 16),
                          Builder(
                            builder: (context) {
                              final localizations = AppLocalizations.of(context);
                              return Text(
                                localizations?.failedToLoadHistory ?? 'Failed to load',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snap.error}',
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          final items = (snap.data ?? const <HistoryItem>[])
              .where((e) => e.geo != null)
              .toList();

          // Empty state
          if (items.isEmpty) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.95),
                            Colors.white.withOpacity(0.85),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.map_outlined,
                              size: 60,
                              color: Colors.blue.shade400,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Builder(
                            builder: (context) {
                              final localizations = AppLocalizations.of(context);
                              return Text(
                                localizations?.noScanLocations ?? 'No scan locations',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  letterSpacing: 0.5,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final localizations = AppLocalizations.of(context);
                              return Text(
                                localizations?.scanTeaLeavesToSeeLocations ?? 'Scan some tea leaves to see their locations on the map.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          // Collect unique diseases for legend (from all items)
          final uniqueDiseases = <String>{};
          for (final it in items) {
            final diseases = _parseDiseases(it.label);
            uniqueDiseases.addAll(diseases);
          }

          // prepare markers - create one marker per disease
          final points = <LatLng>[];
          final futures = <Future<void>>[];

          final localMarkers = <MarkerId, Marker>{};

          for (final it in items) {
            final basePos = LatLng(it.geo!.latitude, it.geo!.longitude);
            points.add(basePos);
            
            final diseases = _parseDiseases(it.label);
            
            if (diseases.isEmpty) {
              // Fallback: use label as-is if no valid diseases found
              final color = _colorForLabel(it.label);
              final id = MarkerId(it.id);
              futures.add(_dot(color, diameter: 18).then((icon) {
                localMarkers[id] = Marker(
                  markerId: id,
                  position: basePos,
                  icon: icon,
                  anchor: const Offset(0.5, 0.5),
                  onTap: () => _showInfo(it),
                );
              }));
            } else {
              // Create a marker for each disease, slightly offset
              final offsetDistance = 0.0001; // ~11 meters at equator
              for (int i = 0; i < diseases.length; i++) {
                final disease = diseases[i];
                final color = _colorForDisease(disease);
                // Offset markers in a small circle around the base position
                final angle = (i * 2 * math.pi) / diseases.length;
                final offsetLat = offsetDistance * math.cos(angle);
                final offsetLng = offsetDistance * math.sin(angle);
                final markerPos = LatLng(
                  basePos.latitude + offsetLat,
                  basePos.longitude + offsetLng,
                );
                
                // Create unique ID for each disease marker
                final id = MarkerId('${it.id}_${disease}_$i');
                
                futures.add(_dot(color, diameter: 18).then((icon) {
                  localMarkers[id] = Marker(
                    markerId: id,
                    position: markerPos,
                    icon: icon,
                    anchor: const Offset(0.5, 0.5),
                    onTap: () => _showInfo(it),
                    infoWindow: InfoWindow(
                      title: disease,
                      snippet: it.label,
                    ),
                  );
                }));
              }
            }
          }

          return FutureBuilder(
            future: Future.wait(futures),
            builder: (context, _) {
              if (_.connectionState != ConnectionState.done) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              localizations?.preparingMarkers ?? 'Preparing markers...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }

              // update stateful markers (preserve current location marker if exists)
              final currentLocMarker = _markers[const MarkerId('current_location')];
              
              _markers
                ..clear()
                ..addAll(localMarkers);
              
              // Preserve current location marker if it exists
              if (currentLocMarker != null) {
                _markers[const MarkerId('current_location')] = currentLocMarker;
              }

              final initialCam = _cameraFromPoints(points);
              final allMarkers = Set<Marker>.of(_markers.values);

              return Stack(
                children: [
                  GoogleMap(
                    key: const ValueKey('main_map'), // Stable key to prevent recreation
                    initialCameraPosition: initialCam,
                    myLocationEnabled: false, // Using custom red pin instead
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    markers: allMarkers,
                    onMapCreated: (c) {
                      if (_map == null) { // Only initialize once
                        _map = c;
                        _mapReady = true;
                        
                        // Update location marker once map is ready
                        if (_currentPosition != null) {
                          _updateCurrentLocationMarker();
                        }
                        
                        // Start location stream if not already started
                        if (_locationSubscription == null) {
                          _startLocationStream();
                        }
                        
                        // best-effort fit to all points
                        if (points.length >= 2) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _fitTo(points);
                          });
                        }
                      }
                    },
                  ),
                  // Custom "Center on my location" button
                  SafeArea(
                    child: Positioned(
                      right: 16,
                      top: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _centerOnMyLocation(),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.blue,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Legend
                  if (uniqueDiseases.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 80,
                      child: SafeArea(
                        top: false,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            // boxShadow: [
                            //   BoxShadow(
                            //     color: Colors.black.withOpacity(0.1),
                            //     blurRadius: 8,
                            //     offset: const Offset(0, -2),
                            //   ),
                            // ],
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 700),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Builder(
                                  builder: (_) {
                                    final sortedDiseases = uniqueDiseases.toList()..sort();
                                    return _legend(sortedDiseases, 8); // cap to 8 chips to avoid overflow
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BottomNavigationBar(
                backgroundColor: Colors.white,
                elevation: 12,
                selectedItemColor: Colors.green,
                unselectedItemColor: Colors.black54,
                type: BottomNavigationBarType.fixed,
                currentIndex: 2,
                items: [
                  BottomNavigationBarItem(icon: const Icon(Icons.home), label: localizations?.home ?? 'Home'),
                  BottomNavigationBarItem(icon: const Icon(Icons.history), label: localizations?.history ?? 'History'),
                  BottomNavigationBarItem(icon: const Icon(Icons.map), label: localizations?.map ?? 'Map'),
                  BottomNavigationBarItem(icon: const Icon(Icons.person), label: localizations?.profile ?? 'Profile'),
                ],
            onTap: (index) {
              if (index == 0) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              } else if (index == 1) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryPage()),
                );
              } else if (index == 3) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              }
            },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _fitTo(List<LatLng> pts) async {
    if (_map == null || pts.isEmpty) return;
    double minLat =  90, minLng =  180, maxLat = -90, maxLng = -180;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLat = math.max(maxLat, p.latitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    try {
      await _map!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    } catch (_) {
      // if map not laid out yet, retry shortly
      Future.delayed(const Duration(milliseconds: 200), () {
        _map?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
      });
    }
  }

  Future<void> _centerOnMyLocation() async {
    if (_map == null) return;
    
    try {
      // Use cached position if available, otherwise get fresh one
      Position? position = _currentPosition;
      
      if (position == null) {
        // Check permission
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        
        if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
          if (mounted) {
            final localizations = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations?.locationPermissionDenied ?? 'Location permission denied. Please enable location access in settings.'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // Get current position
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }

      // Animate camera to current location
      await _map!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15.0,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations?.failedToGetLocation ?? 'Failed to get location'}: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showInfo(HistoryItem it) {
    final pct = it.confidence != null ? (it.confidence! * 100).round() : null;
    final diseases = _parseDiseases(it.label);
    final primaryColor = diseases.isNotEmpty 
        ? _colorForDisease(diseases.first)
        : _colorForLabel(it.label);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header with color indicator
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                        if (diseases.length > 1) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: diseases.skip(1).take(3).map((disease) {
                              final color = _colorForDisease(disease);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: color.withOpacity(0.3)),
                                ),
                                child: Text(
                                  disease,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _darkerColor(color),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (pct != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.speed_rounded, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Scan info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 18, color: Colors.grey.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              final localizations = AppLocalizations.of(context);
                              return Text(
                                localizations?.scannedAt ?? 'Scanned at',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${it.createdAt.year}-${_two(it.createdAt.month)}-${_two(it.createdAt.day)} ${_two(it.createdAt.hour)}:${_two(it.createdAt.minute)}',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (it.locName != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.place, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          it.locName!,
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // You already have _ImagePreviewPage in history_page.dart
                    // If you want to reuse it, navigate to your History detail route here.
                    // For now we just close the sheet.
                  },
                  icon: const Icon(Icons.visibility, size: 20),
                  label: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations?.viewDetails ?? 'View Details',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
