 

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model failed to load. Please retry.')),
      );
      return;
    }

    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          future: _runFullPipelineOnImage(File(pickedFile.path)),
        ),
      ),
    );
  }

  Future<DetectionResult> _runFullPipelineOnImage(File imageFile) async {
    try {
      final teaResultJson =
          await pytorchChannel.invokeMethod('runModel', {'path': imageFile.path});
      final teaLabel =
          (jsonDecode(teaResultJson)['label'] ?? '').toString().toLowerCase();

      if (teaLabel != 'tea') {
        return DetectionResult('Not tea', imageFile.path);
      }

      return await _detectDisease(imageFile, source: 'image');
    } catch (e) {
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
    final top = results.first as Map;
    final label = (top['tag'] ?? top['label'] ?? 'unknown').toString();
    final sc = scoreOf(top);

    // Draw boxes
    final annotated = await renderDetectionsOnImage(imageFile, results);

    // ✅ Save to history (if signed in)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final (geo, locName) = await getScanLocation();
    final conf = (sc.isFinite && !sc.isNaN) ? sc : null;
        await HistoryService().saveScan(
          uid: user.uid,
          imageFile: annotated,
          label: label,
          confidence: sc.isNaN ? null : sc,
          source: source,
          geo: geo,               // <- pass location
      locName: locName,       // <- pass name
        );
      } catch (e) {
        debugPrint('History save failed: $e');
      }
    }

    return DetectionResult('$label - ${sc.toStringAsFixed(2)}', annotated.path);
  }

  // -------------------- UI / Menu / Navigation --------------------
  Future<void> _showCameraOptions() async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Take Photo'),
            onTap: () {
              Navigator.pop(ctx);
              _pickImageAndPredict(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Choose Photo'),
            onTap: () {
              Navigator.pop(ctx);
              _pickImageAndPredict(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam),
            title: const Text('Record Video'),
            onTap: () {
              Navigator.pop(ctx);
              _recordVideo();
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Choose Video'),
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
  title: const Text('Live Camera (Real-Time)'),
  onTap: () {
    Navigator.pop(ctx);
    _yoloInit.then((ok) {
      if (!mounted) return;
      if (ok) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveDetectPage(vision: vision, title: 'Live Detection'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model failed to load. Please retry.')),
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
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<String>(
              icon: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white),
              ),
              color: Colors.white,
              onSelected: _handleMenuSelection,
              itemBuilder: (_) => const [
                PopupMenuItem<String>(value: 'Create Account', child: Text('Create Account')),
                PopupMenuItem<String>(value: 'Logout', child: Text('Logout')),
              ],
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
                          Text('Ready to scan?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the button below to capture or upload a tea leaf.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
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
                                return Column(
                                  children: [
                                    const Text('Model failed to load', style: TextStyle(color: Colors.red)),
                                    const SizedBox(height: 8),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _yoloInit = _loadYoloModel();
                                        });
                                      },
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                );
                              }
                              return _PulsingScanButton(onTap: _showCameraOptions);
                            },
                          ),

                          const SizedBox(height: 12),
                          const Text('Scan Leaf', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            elevation: 12,
            selectedItemColor: Colors.green,
            unselectedItemColor: Colors.black54,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
            currentIndex: 0,
            onTap: (index) {
              if (index == 1) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage()));
              } else if (index == 2) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
              }
            },
          ),
        ),
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
