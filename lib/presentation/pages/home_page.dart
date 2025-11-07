 

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'location_service.dart';
import 'auth/login_page.dart';
import 'auth/create_account_page.dart';
import 'profile_page.dart';
import 'results_page.dart';   // DetectionResult + ResultPage
import 'rederpage.dart';     // renderDetectionsOnImage(...)
import 'history_page.dart';
import 'history_service.dart';
import 'live_detect_page.dart';
import 'map_history_page.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_provider.dart';


/// Native channel for your PyTorch "is tea?" classifier
const MethodChannel pytorchChannel = MethodChannel('pytorch_channel');

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final FlutterVision vision = FlutterVision();

  late Future<bool> _yoloInit;
  bool _yoloReady = false;

  @override
  void initState() {
    super.initState();
    _yoloInit = _loadYoloModel();
  }

  Future<bool> _loadYoloModel() async {
    try {
      // Fail fast if asset paths are wrong
      await rootBundle.load('model/best_float32.tflite');
      await rootBundle.loadString('model/label.txt');

      try { await vision.closeYoloModel(); } catch (_) {}

      await vision.loadYoloModel(
        labels: 'model/label.txt',
        modelPath: 'model/best_float32.tflite',
        modelVersion: 'yolov8',
        quantization: false,
        numThreads: 2,
        useGpu: false,
      );
      _yoloReady = true;
      return true;
    } catch (e) {
      debugPrint('YOLO load failed: $e');
      _yoloReady = false;
      return false;
    }
  }

  @override
  void dispose() {
    try { vision.closeYoloModel(); } catch (_) {}
    super.dispose();
  }

  // ------------------- IMAGE FLOW (spinner first) -------------------
  Future<void> _pickImageAndPredict(ImageSource source) async {
    final ok = await _yoloInit;
    if (!ok) {
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations?.modelFailedToLoad ?? 'Model failed to load. Please retry.')),
      );
      return;
    }

    // For camera, use higher quality and ensure proper format
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: source == ImageSource.camera ? 100 : 90,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    
    // For camera photos, ensure file is fully written before processing
    if (source == ImageSource.camera) {
      // Wait for file to be fully written (camera photos take time to save)
      int retries = 5;
      bool fileReady = false;
      while (retries > 0 && !fileReady) {
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (await imageFile.exists()) {
          try {
            final fileSize = await imageFile.length();
            // Camera photos should be at least 50KB
            if (fileSize > 50000) {
              // Verify we can read the entire file header (JPEG magic bytes)
              final testBytes = await imageFile.openRead(0, 1024).first;
              if (testBytes.length >= 4) {
                // Check JPEG magic bytes: FF D8 FF
                if (testBytes[0] == 0xFF && testBytes[1] == 0xD8 && testBytes[2] == 0xFF) {
                  fileReady = true;
                  debugPrint('Camera file ready: ${imageFile.path}, size: $fileSize bytes');
                  break;
                }
              }
            }
          } catch (e) {
            debugPrint('File not ready yet, retrying... ($retries left): $e');
          }
        }
        retries--;
      }
      
      if (!fileReady) {
        if (!mounted) return;
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations?.modelFailedToLoad ?? 'Image file not ready. Please try again.')),
        );
        return;
      }
      
      // Additional wait and sync to ensure file system has fully committed
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Try to read a chunk from the file to force disk sync and verify readability
      try {
        final bytes = await imageFile.readAsBytes();
        if (bytes.isEmpty) {
          debugPrint('Warning: File appears empty after verification');
        } else {
          debugPrint('File verified: ${bytes.length} bytes readable');
        }
      } catch (e) {
        debugPrint('File sync check warning: $e');
      }
    } else {
      // For gallery, just verify file exists
      if (!await imageFile.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image file not found. Please try again.')),
        );
        return;
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          future: _runFullPipelineOnImage(imageFile),
        ),
      ),
    );
  }

  Future<DetectionResult> _runFullPipelineOnImage(File imageFile) async {
    try {
      // Verify file exists and is readable
      if (!await imageFile.exists()) {
        return DetectionResult('Failed: Image file not found', imageFile.path);
      }
      
      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        return DetectionResult('Failed: Image file is empty', imageFile.path);
      }
      
      debugPrint('Processing image: ${imageFile.path}, size: $fileSize bytes');
      
      // Run multiple inference attempts and take majority vote for consistency
      // This helps with inconsistent results from camera photos
      const int numAttempts = 3;
      final List<String> predictions = [];
      String finalLabel;
      
      for (int attempt = 1; attempt <= numAttempts; attempt++) {
        try {
          // Verify file is still accessible
          if (!await imageFile.exists()) {
            throw Exception('Image file disappeared before model call');
          }
          
          final currentSize = await imageFile.length();
          if (currentSize == 0) {
            throw Exception('Image file is empty');
          }
          
          debugPrint('Calling model (attempt $attempt/$numAttempts): ${imageFile.path}, size: $currentSize bytes');
          
          // Small delay between attempts to ensure consistency
          if (attempt > 1) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
          
          final teaResultJson =
              await pytorchChannel.invokeMethod('runModel', {'path': imageFile.path});
          final teaResult = jsonDecode(teaResultJson) as Map<String, dynamic>;
          final teaLabel = (teaResult['label'] ?? '').toString().toLowerCase().trim();
          
          if (teaLabel.isNotEmpty) {
            predictions.add(teaLabel);
            debugPrint('Attempt $attempt: $teaLabel');
          } else {
            debugPrint('Attempt $attempt: Empty label');
          }
        } catch (e) {
          debugPrint('Attempt $attempt failed: $e');
        }
      }
      
      // Count votes
      if (predictions.isEmpty) {
        return DetectionResult('Failed: All model calls failed', imageFile.path);
      }
      
      // Count occurrences of each label
      final Map<String, int> voteCount = {};
      for (final label in predictions) {
        voteCount[label] = (voteCount[label] ?? 0) + 1;
      }
      
      // Find the label with the most votes
      String majorityLabel = predictions.first;
      int maxVotes = 0;
      for (final entry in voteCount.entries) {
        if (entry.value > maxVotes) {
          maxVotes = entry.value;
          majorityLabel = entry.key;
        }
      }
      
      finalLabel = majorityLabel;
      
      debugPrint('Votes: $voteCount');
      debugPrint('Majority: $finalLabel (${maxVotes}/$numAttempts votes)');
      debugPrint('Image path: ${imageFile.path}');

      // Check if it's tea based on majority vote
      // The model returns "Tea" or "Non-Tea", which becomes "tea" or "non-tea" when lowercased
      // Also handle case where label might be "non-tea" or "non tea"
      final isTea = finalLabel == 'tea' || 
                    (finalLabel.isNotEmpty && 
                     !finalLabel.contains('non') && 
                     finalLabel.contains('tea'));
      
      if (!isTea) {
        debugPrint('Not tea detected: "$finalLabel" (${maxVotes}/$numAttempts votes)');
        return DetectionResult('Not tea', imageFile.path);
      }
      
      debugPrint('✅ Tea detected successfully: "$finalLabel" (${maxVotes}/$numAttempts votes)');

      return await _detectDisease(imageFile, source: 'image');
    } catch (e) {
      debugPrint('Error in _runFullPipelineOnImage: $e');
      return DetectionResult('Failed: $e', imageFile.path);
    }
  }

  // ------------------- VIDEO FLOW (extract frames) -------------------
  Future<File> _extractFrameFromVideo(File video, {int timeMs = 500}) async {
    final bytes = await VideoThumbnail.thumbnailData(
      video: video.path,
      imageFormat: ImageFormat.JPEG,
      timeMs: timeMs,
      quality: 90,
    );
    if (bytes == null) {
      throw Exception('Could not extract frame from video');
    }
    final f = File('${Directory.systemTemp.path}/vid_frame_$timeMs.jpg');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  Future<Map<String, dynamic>> _runTeaClassifierOnImage(File imageFile) async {
    final raw = await pytorchChannel.invokeMethod('runModel', {'path': imageFile.path});
    return jsonDecode(raw as String) as Map<String, dynamic>;
  }

  Future<DetectionResult> _runFullPipelineOnVideo(File videoFile) async {
    try {
      final times = <int>[400, 1200, 2200];

      File? bestFrame;
      double bestConf = -1.0;

      for (final t in times) {
        final frame = await _extractFrameFromVideo(videoFile, timeMs: t);
        final m = await _runTeaClassifierOnImage(frame);

        final label = (m['label'] ?? '').toString().toLowerCase();
        final conf  = (m['confidence'] is num) ? (m['confidence'] as num).toDouble() : 0.0;

        if (label == 'tea' && conf > bestConf) {
          bestConf = conf;
          bestFrame = frame;
        }
      }

      if (bestFrame == null) {
        return DetectionResult('Not tea', videoFile.path);
      }

      return await _detectDisease(bestFrame, source: 'video');
    } catch (e) {
      return DetectionResult('Failed: $e', videoFile.path);
    }
  }

  Future<void> _recordVideo() async {
    final ok = await _yoloInit;
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model failed to load. Please retry.')),
      );
      return;
    }

    try {
      final pickedFile = await _picker.pickVideo(source: ImageSource.camera);
      if (pickedFile == null) return;

      final video = File(pickedFile.path);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(
            future: _runFullPipelineOnVideo(video),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(
            future: Future.value(DetectionResult('Failed: $e', '')),
          ),
        ),
      );
    }
  }

  // -------------------- Common disease detection --------------------
  Future<DetectionResult> _detectDisease(File imageFile, {String source = 'image'}) async {
    if (!_yoloReady) {
      return DetectionResult('Failed: model not loaded', imageFile.path);
    }

    final origBytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(origBytes);
    if (decoded == null) {
      return DetectionResult('Decode failed', imageFile.path);
    }
    final baked = img.bakeOrientation(decoded);
    final Uint8List bakedBytes = Uint8List.fromList(img.encodeJpg(baked, quality: 90));

    final results = await vision.yoloOnImage(
      bytesList: bakedBytes,
      imageHeight: baked.height,
      imageWidth: baked.width,
      iouThreshold: 0.45,
      confThreshold: 0.25,
      classThreshold: 0.25,
    );

    debugPrint('YOLO results count: ${results.length}');
    if (results.isNotEmpty) {
      debugPrint('First result keys: ${(results.first as Map).keys}');
      debugPrint('First result: ${results.first}');
    }

    if (results.isEmpty) {
      return DetectionResult('Healthy / No visible disease', imageFile.path);
    }

    double scoreOf(Map d) {
      final b = d['box'];
      if (b is List && b.length >= 5 && b[4] is num) return (b[4] as num).toDouble();
      final v = d['confidence'] ?? d['score'] ?? d['prob'];
      return (v is num) ? v.toDouble() : 0.0;
    }

    results.sort((a, b) => scoreOf(b as Map).compareTo(scoreOf(a as Map)));
    
    // Collect all unique disease labels with their highest confidence scores
    final Map<String, double> diseaseMap = {};
    double highestConf = 0.0;
    String primaryLabel = 'unknown';
    
    for (final r in results) {
      final candidateLabel = (r['tag'] ?? r['label'] ?? '').toString().trim();
      if (candidateLabel.isNotEmpty && candidateLabel.toLowerCase() != 'unknown') {
        final conf = scoreOf(r as Map);
        // Keep the highest confidence for each disease
        if (!diseaseMap.containsKey(candidateLabel) || diseaseMap[candidateLabel]! < conf) {
          diseaseMap[candidateLabel] = conf;
        }
        // Track the highest overall confidence for primary label
        if (conf > highestConf) {
          highestConf = conf;
          primaryLabel = candidateLabel;
        }
      }
    }
    
    // If no valid labels found, use the first result
    if (diseaseMap.isEmpty) {
      final top = results.first as Map;
      final firstLabel = (top['tag'] ?? top['label'] ?? 'unknown').toString().trim();
      if (firstLabel.isNotEmpty) {
        primaryLabel = firstLabel;
        diseaseMap[firstLabel] = scoreOf(top);
        highestConf = diseaseMap[firstLabel]!;
      }
    }
    
    // Format all diseases: "Disease1, Disease2, Disease3 - highest_conf"
    // Capitalize first letter of each disease name
    String capitalize(String s) {
      if (s.isEmpty) return s;
      return s[0].toUpperCase() + s.substring(1).toLowerCase();
    }
    
    final allDiseases = diseaseMap.keys.map((d) => capitalize(d)).toList();
    final label = allDiseases.length > 1 
        ? '${allDiseases.join(', ')} - ${highestConf.toStringAsFixed(2)}'
        : '${capitalize(primaryLabel)} - ${highestConf.toStringAsFixed(2)}';
    
    debugPrint('Detected diseases: $allDiseases');
    debugPrint('Primary label: $primaryLabel, confidence: $highestConf');

    // Draw boxes
    final annotated = await renderDetectionsOnImage(imageFile, results);

    // ✅ Save to history (if signed in)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final (geo, locName) = await getScanLocation();
        final conf = (highestConf.isFinite && !highestConf.isNaN) ? highestConf : null;
        await HistoryService().saveScan(
          uid: user.uid,
          imageFile: annotated,
          label: primaryLabel, // Save primary label for history
          confidence: conf,
          source: source,
          geo: geo,               // <- pass location
          locName: locName,       // <- pass name
        );
      } catch (e) {
        debugPrint('History save failed: $e');
      }
    }

    return DetectionResult(label, annotated.path);
  }

  // -------------------- UI / Menu / Navigation --------------------
  Future<void> _showCameraOptions() async {
    if (!mounted) return;

    final localizations = AppLocalizations.of(context);
    if (localizations == null) return;
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: Text(localizations.takePhoto),
            onTap: () {
              Navigator.pop(ctx);
              _pickImageAndPredict(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: Text(localizations.choosePhoto),
            onTap: () {
              Navigator.pop(ctx);
              _pickImageAndPredict(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam),
            title: Text(localizations.recordVideo),
            onTap: () {
              Navigator.pop(ctx);
              _recordVideo();
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: Text(localizations.chooseVideo),
            onTap: () async {
              Navigator.pop(ctx);
              final pf = await _picker.pickVideo(source: ImageSource.gallery);
              if (pf == null) return;
              final video = File(pf.path);
              if (!mounted) return;
              Navigator.push(
context,
                MaterialPageRoute(
                  builder: (_) => ResultPage(future: _runFullPipelineOnVideo(video)),
                ),
              );
            },
          ),
          ListTile(
  leading: const Icon(Icons.camera),
  title: Text(localizations.liveCamera),
  onTap: () {
    Navigator.pop(ctx);
    _yoloInit.then((ok) {
      if (!mounted) return;
      if (ok) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveDetectPage(vision: vision, title: localizations.liveDetection),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.modelFailedToLoad)),
        );
      }
    });
  },
),


        ],
      ),
    );
  }

  void _handleMenuSelection(String choice) {
    if (!mounted) return;
    if (choice == 'Logout') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } else if (choice == 'Create Account') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateAccountPage()),
      );
    }
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(localizations.selectLanguage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(localizations.english),
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale(const Locale('en'));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(localizations.tamil),
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale(const Locale('ta'));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(localizations.sinhala),
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale(const Locale('si'));
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: const [
            Icon(Icons.eco, color: Colors.white),
            SizedBox(width: 8),
            Text('TeaHealth', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          // Language selector button
          Consumer(
            builder: (context, ref, child) {
              final localizations = AppLocalizations.of(context);
              
              return IconButton(
                icon: const Icon(Icons.language, color: Colors.white),
                tooltip: localizations?.selectLanguage ?? 'Select Language',
                onPressed: () => _showLanguageDialog(context, ref),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<String>(
              icon: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white),
              ),
              color: Colors.white,
              onSelected: _handleMenuSelection,
              itemBuilder: (_) {
                final localizations = AppLocalizations.of(context);
                return [
                  PopupMenuItem<String>(value: 'Create Account', child: Text(localizations?.createAccount ?? 'Create Account')),
                  PopupMenuItem<String>(value: 'Logout', child: Text(localizations?.logout ?? 'Logout')),
                ];
              },
            ),
          ),
        ],
      ),

      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          const Positioned(top: -60, right: -40, child: _DecorativeCircle(size: 180, opacity: 0.18)),
          const Positioned(bottom: -50, left: -30, child: _DecorativeCircle(size: 240, opacity: 0.14)),

          // Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: theme.colorScheme.primary.withOpacity(.12),
                            child: const Icon(Icons.camera_alt_outlined, color: Colors.green, size: 30),
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final localizations = AppLocalizations.of(context);
                              return Text(localizations?.readyToScan ?? 'Ready to scan?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800));
                            },
                          ),
                          const SizedBox(height: 4),
                          Builder(
                            builder: (context) {
                              final localizations = AppLocalizations.of(context);
                              return Text(
                                localizations?.fillFrameTip ?? 'Tap the button below to capture or upload a tea leaf.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                              );
                            },
                          ),
                          const SizedBox(height: 22),

                          // Show spinner until the model is ready, then show button
                          FutureBuilder<bool>(
                            future: _yoloInit,
                            builder: (context, snap) {
                              if (snap.connectionState != ConnectionState.done) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snap.data != true) {
                                final localizations = AppLocalizations.of(context);
                                return Column(
                                  children: [
                                    Text(localizations?.modelFailedToLoad ?? 'Model failed to load', style: const TextStyle(color: Colors.red)),
                                    const SizedBox(height: 8),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _yoloInit = _loadYoloModel();
                                        });
                                      },
                                      child: Text(localizations?.retry ?? 'Retry'),
                                    ),
                                  ],
                                );
                              }
                              return _PulsingScanButton(onTap: _showCameraOptions);
                            },
                          ),

                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final localizations = AppLocalizations.of(context);
                              return Text(localizations?.scanLeaf ?? 'Scan Leaf', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
                items: [
                  BottomNavigationBarItem(icon: const Icon(Icons.home), label: localizations?.home ?? 'Home'),
                  BottomNavigationBarItem(icon: const Icon(Icons.history), label: localizations?.history ?? 'History'),
                  BottomNavigationBarItem(icon: const Icon(Icons.map), label: localizations?.map ?? 'Map'),
                  BottomNavigationBarItem(icon: const Icon(Icons.person), label: localizations?.profile ?? 'Profile'),
                ],
            currentIndex: 0,
            onTap: (index) {
              if (index == 1) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage()));
              } else if (index == 2) {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MapHistoryPage(uid: user.uid)),
                  );
                } else {
                  final localizations = AppLocalizations.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(localizations?.pleaseLoginToViewMap ?? 'Please log in to view map')),
                  );
                }
              } else if (index == 3) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
              }
            },
              ),
            ),
          );
        },
      ),
    );
  }
}

// Decorative soft circle
class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.white, Colors.white70],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

// Pulsing scan button
class _PulsingScanButton extends StatefulWidget {
  const _PulsingScanButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PulsingScanButton> createState() => _PulsingScanButtonState();
}

class _PulsingScanButtonState extends State<_PulsingScanButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = _c.value;
              final scale = 1.0 + (0.35 * t);
              final opacity = (1.0 - t).clamp(0.0, 1.0);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withOpacity(0.55 * opacity),
                  ),
                ),
              );
            },
          ),
          InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF34C759), Color(0xFF2AAA4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.35),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 44),
            ),
          ),
        ],
      ),
    );
  }
}
