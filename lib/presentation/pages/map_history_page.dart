import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'history_service.dart'; // uses HistoryItem & streamScans(uid)

class MapHistoryPage extends StatefulWidget {
  final String uid;
  const MapHistoryPage({super.key, required this.uid});

  @override
  State<MapHistoryPage> createState() => _MapHistoryPageState();
}

class _MapHistoryPageState extends State<MapHistoryPage> {
  GoogleMapController? _map;
  final _markers = <MarkerId, Marker>{};

  // cache tiny circle bitmaps per color
  final _dotCache = <int, BitmapDescriptor>{};

  // stable color per label
  final _palette = <Color>[
    const Color(0xFFE74C3C), // red
    const Color(0xFF2ECC71), // green
    const Color(0xFF3498DB), // blue
    const Color(0xFFF1C40F), // yellow
    const Color(0xFF9B59B6), // purple
    const Color(0xFFE67E22), // orange
    const Color(0xFF1ABC9C), // teal
    const Color(0xFF34495E), // dark
    const Color(0xFFe84393), // pink
    const Color(0xFF16a085), // green2
  ];

  Color _colorForLabel(String label) {
    final h = label.toLowerCase().hashCode;
    final idx = h.abs() % _palette.length;
    return _palette[idx];
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
    final sw = LatLng(minLat, minLng);
    final ne = LatLng(maxLat, maxLng);
    final bounds = LatLngBounds(southwest: sw, northeast: ne);
    // GoogleMap's fitBounds isn't exposed directly; we’ll set initialCamera and then animate once map ready:
    // We'll store and animate in onMapCreated below using a post-frame callback.
    // For initial fallback, center mid.
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    return CameraPosition(target: center, zoom: 6);
  }

  // build legend chips from labels
  Widget _legend(List<String> labels) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: labels.map((l) {
          final c = _colorForLabel(l);
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                  l,
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.8)),
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
      appBar: AppBar(
        title: const Text('Scan Map'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<HistoryItem>>(
        stream: svc.streamScans(widget.uid, limit: 500),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          final items = (snap.data ?? const <HistoryItem>[])
              .where((e) => e.geo != null)
              .toList();

          // unique labels for legend
          final labels = <String>{};
          for (final it in items) {
            labels.add(it.label);
          }

          // prepare markers
          final points = <LatLng>[];
          final futures = <Future<void>>[];

          final localMarkers = <MarkerId, Marker>{};

          for (final it in items) {
            final p = LatLng(it.geo!.latitude, it.geo!.longitude);
            points.add(p);
            final color = _colorForLabel(it.label);
            final id = MarkerId(it.id);

            futures.add(_dot(color, diameter: 18).then((icon) {
              localMarkers[id] = Marker(
                markerId: id,
                position: p,
                icon: icon,
                anchor: const Offset(0.5, 0.5),
                onTap: () => _showInfo(it),
              );
            }));
          }

          return FutureBuilder(
            future: Future.wait(futures),
            builder: (context, _) {
              if (_.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              // update stateful markers
              _markers
                ..clear()
                ..addAll(localMarkers);

              final initialCam = _cameraFromPoints(points);

              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: initialCam,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    markers: Set.of(_markers.values),
                    onMapCreated: (c) {
                      _map = c;
                      // best-effort fit to all points
                      if (points.length >= 2) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _fitTo(points);
                        });
                      }
                    },
                  ),
                  // Legend
                  if (labels.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 8,
                            child: _legend(labels.take(8).toList()), // cap to 8 chips to avoid overflow
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

  void _showInfo(HistoryItem it) {
    final pct = it.confidence != null ? (it.confidence! * 100).round() : null;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(
                  color: _colorForLabel(it.label), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(it.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                if (pct != null) Text('$pct%'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Scanned at: ${it.createdAt}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open detail'),
                onPressed: () {
                  Navigator.pop(context);
                  // You already have _ImagePreviewPage in history_page.dart
                  // If you want to reuse it, navigate to your History detail route here.
                  // For now we just close the sheet.
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
