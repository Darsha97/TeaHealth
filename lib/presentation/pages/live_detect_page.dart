import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_provider.dart';
import 'rederpage.dart';
import 'detection_preview_page.dart';

// Background converter for YUV420 -> JPEG (no resizing), optional rotateDeg
Future<Uint8List> _yuv420ToJpeg(Map<String, dynamic> args) async {
  final Uint8List yBuffer = args['y'];
  final Uint8List uBuffer = args['u'];
  final Uint8List vBuffer = args['v'];
  final int width = args['width'];
  final int height = args['height'];
  final int yRowStride = args['yRowStride'];
  final int uvRowStride = args['uvRowStride'];
  final int uvPixelStride = args['uvPixelStride'];
  final int quality = args['quality'] ?? 80;
  final int rotateDeg = args['rotateDeg'] ?? 0; // 0/90/180/270

  final rgbImage = img.Image(width, height);

  for (int y = 0; y < height; y++) {
    final yIndex = y * yRowStride;
    final uvIndex = (y >> 1) * uvRowStride;
    for (int x = 0; x < width; x++) {
      final yValue = yBuffer[yIndex + x];
      final uvOffset = uvIndex + (x >> 1) * uvPixelStride;
      final uValue = uBuffer[uvOffset];
      final vValue = vBuffer[uvOffset];

      final c = yValue - 16;
      final d = uValue - 128;
      final e = vValue - 128;
      int r = (298 * c + 409 * e + 128) >> 8;
      int g = (298 * c - 100 * d - 208 * e + 128) >> 8;
      int b = (298 * c + 516 * d + 128) >> 8;
      if (r < 0) r = 0; else if (r > 255) r = 255;
      if (g < 0) g = 0; else if (g > 255) g = 255;
      if (b < 0) b = 0; else if (b > 255) b = 255;

      rgbImage.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  img.Image out = rgbImage;
  if (rotateDeg % 360 != 0) {
    out = img.copyRotate(rgbImage, rotateDeg);
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: quality));
}

/// Native channel for PyTorch tea leaf classifier
const MethodChannel pytorchChannel = MethodChannel('pytorch_channel');

/// Guidance type for user instructions
enum GuidanceType {
  neutral,
  info,
  warning,
  success,
}

class LiveDetectPage extends ConsumerStatefulWidget {
  const LiveDetectPage({
    super.key,
    required this.vision,
    this.title,
    // thresholds are used internally only (no UI sliders)
    this.conf = 0.01,
    this.iou = 0.45,
    this.cls = 0.03,
  });

  final FlutterVision vision;
  final String? title;
  final double conf;
  final double iou;
  final double cls;

  @override
  ConsumerState<LiveDetectPage> createState() => _LiveDetectPageState();
}

class _LiveDetectPageState extends ConsumerState<LiveDetectPage>
    with SingleTickerProviderStateMixin {
  late CameraController _controller;
  late CameraDescription _camera;

  bool _inited = false;
  bool _busy = false;
  bool _recording = false;
  bool _torch = false;

  // latest camera buffer size (used to map boxes)
  int _bufferW = 0, _bufferH = 0;

  // latest recognitions
  List<Map<String, dynamic>> _results = const [];

  // tea detection status
  String? _teaDetectionStatus; // null, "tea", "non-tea", "checking"
  double? _teaConfidence;

  // user guidance
  String? _userGuidance; // Instructions for user
  GuidanceType _guidanceType = GuidanceType.neutral;

  // image quality tracking
  List<CameraImage> _recentFrames = [];

  // fps meter
  int _frameCount = 0;
  double _fps = 0;
  Timer? _fpsTimer;

  // throttling
  int _lastTeaCheckMs = 0;
  int _lastYoloMs = 0;
  int _yoloMinIntervalMs = 120;     // adaptive minimum
  int _lastYoloDurationMs = 0;      // last measured yolo time
  int _lastResultsUpdateMs = 0;     // UI update throttle
  String? _lastResultsSig;          // to avoid redundant setState
  int _teaLockUntilMs = 0;          // during lock, skip tea checks and focus YOLO
  int _yoloBurstLeft = 0;           // run YOLO back-to-back for quick box appearance
  bool _showingResultDialog = false; // prevent multiple dialogs

  // temp file reuse for tea check
  String? _teaTempPath;

  // camera
  double _zoom = 1.0;
  late final double _conf;
  late final double _iou;
  late final double _cls;

  late final AnimationController _pulseCtrl;

  // Create a compact signature for result changes to avoid redundant UI updates
  String _signatureOfResults(List detections) {
    if (detections.isEmpty) return 'empty';
    try {
      final n = detections.length;
      final first = detections.first as Map;
      final label = (first['tag'] ?? first['label'] ?? first['class_name'])?.toString() ?? '';
      final box = first['box'];
      String boxSig = '';
      if (box is List && box.length >= 4) {
        boxSig = '${(box[0] as num).round()}_${(box[1] as num).round()}_${(box[2] as num).round()}_${(box[3] as num).round()}';
      }
      return '$n|$label|$boxSig';
    } catch (_) {
      return 'na';
    }
  }

  double _scoreOf(Map r) {
    final box = r['box'];
    if (box is List && box.length >= 5 && box[4] is num) {
      return (box[4] as num).toDouble();
    }
    final v = r['confidence'] ?? r['score'] ?? r['prob'];
    return (v is num) ? v.toDouble() : 0.0;
  }

  String _labelOf(Map r) => (r['tag'] ?? r['label'] ?? r['class_name'] ?? 'unknown').toString();

  // Convert various YOLO box formats to [x1,y1,x2,y2] in pixel space
  ({double x0, double y0, double x1, double y1}) _toLTRB(dynamic box, int imgW, int imgH) {
    double x0 = 0, y0 = 0, x1 = 0, y1 = 0;
    if (box is List && box.length >= 4) {
      final a = (box[0] as num).toDouble();
      final b = (box[1] as num).toDouble();
      final c = (box[2] as num).toDouble();
      final d = (box[3] as num).toDouble();
      if (c > a && d > b) {
        x0 = a; y0 = b; x1 = c; y1 = d;
      } else {
        x0 = a; y0 = b; x1 = a + c; y1 = b + d;
        if (x1 <= x0 || y1 <= y0) {
          x0 = a - c / 2.0; y0 = b - d / 2.0; x1 = a + c / 2.0; y1 = b + d / 2.0;
        }
      }
      if (x1 <= 2 && y1 <= 2) { // normalized
        x0 *= imgW; x1 *= imgW; y0 *= imgH; y1 *= imgH;
      }
      return (x0: x0, y0: y0, x1: x1, y1: y1);
    }
    if (box is Map) {
      double? left = (box['left'] ?? box['x'])?.toDouble();
      double? top = (box['top'] ?? box['y'])?.toDouble();
      double? right = (box['right'])?.toDouble();
      double? bottom = (box['bottom'])?.toDouble();
      double? w = (box['w'] ?? box['width'])?.toDouble();
      double? h = (box['h'] ?? box['height'])?.toDouble();
      double? cx = (box['cx'])?.toDouble();
      double? cy = (box['cy'])?.toDouble();
      if (left != null && top != null && right != null && bottom != null) {
        x0 = left; y0 = top; x1 = right; y1 = bottom;
      } else if (left != null && top != null && w != null && h != null) {
        x0 = left; y0 = top; x1 = left + w; y1 = top + h;
      } else if (cx != null && cy != null && w != null && h != null) {
        x0 = cx - w / 2; y0 = cy - h / 2; x1 = cx + w / 2; y1 = cy + h / 2;
      }
      if (x1 <= 2 && y1 <= 2) { x0 *= imgW; x1 *= imgW; y0 *= imgH; y1 *= imgH; }
      return (x0: x0, y0: y0, x1: x1, y1: y1);
    }
    return (x0: 0, y0: 0, x1: 0, y1: 0);
  }

  Future<File?> _cameraImageToTempJpeg(CameraImage cameraImage) async {
    try {
      final bytes = await compute(_yuv420ToJpeg, {
        'y': cameraImage.planes[0].bytes,
        'u': cameraImage.planes[1].bytes,
        'v': cameraImage.planes[2].bytes,
        'width': cameraImage.width,
        'height': cameraImage.height,
        'yRowStride': cameraImage.planes[0].bytesPerRow,
        'uvRowStride': cameraImage.planes[1].bytesPerRow,
        'uvPixelStride': cameraImage.planes[1].bytesPerPixel ?? 1,
        'quality': 85,
        'rotateDeg': _rotationForPreview(),
      });
      final tempDir = await getTemporaryDirectory();
      final f = File('${tempDir.path}/freeze_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await f.writeAsBytes(bytes, flush: true);
      return f;
    } catch (_) {
      return null;
    }
  }

  Future<void> _freezeAndShowResult(CameraImage frame, List<Map<String, dynamic>> results) async {
    if (_showingResultDialog) return;
    
    // Collect all unique diseases from results
    Set<String> diseases = {};
    for (final r in results) {
      final label = _labelOf(r);
      if (label.isNotEmpty && label.toLowerCase() != 'unknown') {
        diseases.add(label);
      }
    }
    final localizations = AppLocalizations.of(context);
    String diseasesText = diseases.isEmpty 
        ? (localizations?.noDiseaseDetected ?? 'No disease detected')
        : diseases.join(', ');

    _showingResultDialog = true;

    // Build quick annotated (fast) + refined annotated (background)
    File? annotatedQuick;
    File? fallbackRaw;
    Future<({File? image, String labels, List<Map<String, dynamic>> results})>? refinedFuture;
    try {
      fallbackRaw = await _cameraImageToTempJpeg(frame);
      if (fallbackRaw != null) {
        // Quick: normalize current results to frame size and draw immediately
        final norm = <Map<String, dynamic>>[];
        for (final r in results) {
          final bb = _toLTRB(r['box'], frame.width, frame.height);
          norm.add({...r, 'box': [bb.x0, bb.y0, bb.x1, bb.y1]});
        }
        annotatedQuick = await renderDetectionsOnImage(fallbackRaw, norm);

        // Refined: re-run YOLO on JPEG in background, then redraw for perfect alignment
        final File fileForRefine = fallbackRaw;
        refinedFuture = () async {
          try {
            final origBytes = await fileForRefine.readAsBytes();
            final decoded = img.decodeImage(origBytes);
            if (decoded == null) return (image: null, labels: diseasesText, results: <Map<String, dynamic>>[]);
            final baked = img.bakeOrientation(decoded);
            final bakedBytes = Uint8List.fromList(img.encodeJpg(baked, quality: 90));
            final aligned = await widget.vision.yoloOnImage(
              bytesList: bakedBytes,
              imageHeight: baked.height,
              imageWidth: baked.width,
              iouThreshold: _iou,
              confThreshold: _conf,
              classThreshold: _cls,
            );
            // Collect all unique diseases from refined results
            Set<String> refinedDiseases = {};
            for (final r in aligned) {
              final label = _labelOf(r as Map);
              if (label.isNotEmpty && label.toLowerCase() != 'unknown') {
                refinedDiseases.add(label);
              }
            }
            // Get localizations again in case context changed
            final refinedLocalizations = mounted ? AppLocalizations.of(context) : null;
            final refinedText = refinedDiseases.isEmpty 
                ? (refinedLocalizations?.noDiseaseDetected ?? 'No disease detected')
                : refinedDiseases.join(', ');
            
            final annotated = await renderDetectionsOnImage(fileForRefine, aligned);
            final resultsList = aligned.map((r) => r as Map<String, dynamic>).toList();
            return (image: annotated, labels: refinedText, results: resultsList);
          } catch (_) {
            return (image: null, labels: diseasesText, results: <Map<String, dynamic>>[]);
          }
        }();
      }
    } catch (_) {}

    await _stopStream();
    if (!mounted) return;
    final displayFile = annotatedQuick ?? fallbackRaw;
    if (displayFile == null) {
      _showingResultDialog = false;
      return;
    }
    // Prepare data for saving
    double? avgConfidence;
    if (results.isNotEmpty) {
      double sum = 0.0;
      int count = 0;
      for (final r in results) {
        final conf = _scoreOf(r);
        if (conf > 0) {
          sum += conf;
          count++;
        }
      }
      avgConfidence = count > 0 ? (sum / count) : null;
    }

    final routeResult = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => DetectionPreviewPage(
          image: displayFile,
          label: diseasesText,
          refinedImage: refinedFuture?.then((v) => v.image),
          refinedLabel: refinedFuture?.then((v) => v.labels),
          refinedResults: refinedFuture?.then((v) => v.results),
          initialResults: results,
          confidence: avgConfidence,
        ),
      ),
    );
    _showingResultDialog = false;
    if (routeResult == 'rescan') {
      if (mounted) _startStream();
    }
  }

  Future<void> _runYoloOnFrame(CameraImage img) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isBurst = _yoloBurstLeft > 0;
    final minGap = isBurst ? 0 : math.max(60, _yoloMinIntervalMs);
    if (!isBurst && nowMs - _lastYoloMs < minGap) return;
    _lastYoloMs = nowMs;
    try {
      final t0 = DateTime.now().millisecondsSinceEpoch;
      final results = await widget.vision.yoloOnFrame(
        bytesList: img.planes.map((p) => p.bytes).toList(),
        imageWidth: img.width,
        imageHeight: img.height,
        iouThreshold: _iou,
        confThreshold: _conf,
        classThreshold: _cls,
      );
      final t1 = DateTime.now().millisecondsSinceEpoch;
      _lastYoloDurationMs = (t1 - t0).clamp(0, 2000);
      _yoloMinIntervalMs = (_lastYoloDurationMs + 5).clamp(60, 220);
      if (_yoloBurstLeft > 0) _yoloBurstLeft--;

      if (!mounted) return;

      _analyzeImageQuality(img, results);

      final sig = _signatureOfResults(results);
      final shouldUpdate = sig != _lastResultsSig || (nowMs - _lastResultsUpdateMs) >= 60;
      if (shouldUpdate) {
        _lastResultsSig = sig;
        _lastResultsUpdateMs = nowMs;
        setState(() => _results = List<Map<String, dynamic>>.from(results));
      }

      // Stop scanning and show explicit result with frozen annotated image
      if (_teaDetectionStatus == 'tea' && results.isNotEmpty && !_showingResultDialog) {
        await _freezeAndShowResult(img, List<Map<String, dynamic>>.from(results));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Disease detection error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _conf = widget.conf;
    _iou = widget.iou;
    _cls = widget.cls;

    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);

    _init();
  }

  Future<void> _init() async {
    final cams = await availableCameras();
    _camera = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.first,
    );

    _controller = CameraController(
      _camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller.initialize();
    await _controller.setFocusMode(FocusMode.auto);
    await _controller.setExposureMode(ExposureMode.auto);
    await _controller.setZoomLevel(_zoom);

    // simple FPS ticker
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _fps = _frameCount.toDouble();
        _frameCount = 0;
      });
    });

    if (!mounted) return;
    setState(() => _inited = true);
  }

  Future<void> _switchCamera() async {
    final cams = await availableCameras();
    final idx = cams.indexOf(_camera);
    final next = cams[(idx + 1) % cams.length];
    _camera = next;

    if (_controller.value.isStreamingImages) {
      await _controller.stopImageStream();
    }
    await _controller.dispose();

    _controller = CameraController(
      _camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller.initialize();
    await _controller.setZoomLevel(_zoom);
    await _controller.setFlashMode(FlashMode.off);

    if (!mounted) return;
    setState(() {});
    if (_recording) _startStream();
  }

  Future<void> _toggleTorch() async {
    try {
      if (_torch) {
        await _controller.setFlashMode(FlashMode.off);
      } else {
        await _controller.setFlashMode(FlashMode.torch);
      }
      if (!mounted) return;
      setState(() => _torch = !_torch);
    } catch (_) {}
  }

  /// Convert CameraImage to File for PyTorch model (optimized)
  Future<File?> _cameraImageToFile(CameraImage cameraImage) async {
    try {
      // Prepare reusable temp path
      _teaTempPath ??= '${(await getTemporaryDirectory()).path}/tea_check.jpg';

      // Offload conversion+resize+encode to background isolate
      final jpegBytes = await compute(_yuv420ToJpeg, {
        'y': cameraImage.planes[0].bytes,
        'u': cameraImage.planes[1].bytes,
        'v': cameraImage.planes[2].bytes,
        'width': cameraImage.width,
        'height': cameraImage.height,
        'yRowStride': cameraImage.planes[0].bytesPerRow,
        'uvRowStride': cameraImage.planes[1].bytesPerRow,
        'uvPixelStride': cameraImage.planes[1].bytesPerPixel ?? 1,
        'quality': 80,
      });

      final file = File(_teaTempPath!);
      await file.writeAsBytes(jpegBytes, flush: false);
      return file;
    } catch (e) {
      if (kDebugMode) debugPrint('CameraImage to File conversion error: $e');
      return null;
    }
  }

  /// Analyze image quality and provide guidance
  void _analyzeImageQuality(CameraImage image, List<Map<String, dynamic>>? detectionResults) {
    // Track recent frames for motion detection
    _recentFrames.add(image);
    if (_recentFrames.length > 5) {
      _recentFrames.removeAt(0);
    }

    // Analyze based on detection confidence and image characteristics
    double? maxConfidence;
    if (detectionResults != null && detectionResults.isNotEmpty) {
      for (var r in detectionResults) {
        final conf = (r['confidence'] ?? r['score'] ?? r['prob'] ?? 0.0) as num;
        maxConfidence = math.max(maxConfidence ?? 0.0, conf.toDouble());
      }
    }

    // Determine guidance based on tea detection and disease detection
    final localizations = AppLocalizations.of(context);
    if (_teaDetectionStatus == 'non-tea') {
      _userGuidance = localizations?.notTeaLeafGuidance ?? 'This doesn\'t appear to be a tea leaf. Point camera at a tea leaf.';
      _guidanceType = GuidanceType.warning;
      return;
    }

    if (_teaDetectionStatus == 'checking') {
      _userGuidance = localizations?.scanningForTeaLeaf ?? 'Scanning for tea leaf...';
      _guidanceType = GuidanceType.info;
      return;
    }

    if (_teaDetectionStatus == 'tea') {
      // Check if we have good disease detection
      if (maxConfidence != null && maxConfidence > 0.5) {
        _userGuidance = localizations?.holdSteadyForResults ?? 'Great! Hold steady for best results.';
        _guidanceType = GuidanceType.success;
      } else if (maxConfidence != null && maxConfidence > 0.25) {
        _userGuidance = localizations?.comeCloserForDetection ?? 'Come closer for better detection.';
        _guidanceType = GuidanceType.warning;
      } else {
        _userGuidance = localizations?.moveCloserGuidance ?? 'Move closer • Ensure good lighting • Hold steady';
        _guidanceType = GuidanceType.warning;
      }
    } else {
      _userGuidance = localizations?.positionTeaLeafCenter ?? 'Position tea leaf in center • Fill the frame';
      _guidanceType = GuidanceType.info;
    }
  }

  /// Run tea detection on image file
  Future<Map<String, dynamic>?> _detectTeaLeaf(File imageFile) async {
    try {
      final teaResultJson = await pytorchChannel.invokeMethod('runModel', {'path': imageFile.path});
      final result = jsonDecode(teaResultJson) as Map<String, dynamic>;
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('Tea detection error: $e');
      return null;
    }
  }

  /// Run full pipeline: tea detection -> disease detection
  Future<void> _runFullPipeline(CameraImage cameraImage) async {
    try {
      // Step 1: Convert to file
      final imageFile = await _cameraImageToFile(cameraImage);
      if (imageFile == null) return;

      // Step 2: Check if it's a tea leaf
      setState(() => _teaDetectionStatus = 'checking');
      final teaResult = await _detectTeaLeaf(imageFile);
      
      if (teaResult != null) {
        final teaLabel = (teaResult['label'] ?? '').toString().toLowerCase();
        final teaConf = (teaResult['confidence'] as num?)?.toDouble() ?? 0.0;
        
        final wasTea = _teaDetectionStatus == 'tea';
        final nowTea = teaLabel == 'tea';
        setState(() {
          _teaDetectionStatus = nowTea ? 'tea' : 'non-tea';
          _teaConfidence = teaConf;
        });

        // Immediate YOLO run on first confirmation to avoid lag before boxes appear
        if (!wasTea && nowTea) {
          // enter burst mode for snappy boxes like QR scanners
          _teaLockUntilMs = DateTime.now().millisecondsSinceEpoch + 2000;
          _yoloBurstLeft = 3;
          await _runYoloOnFrame(cameraImage);
        }

        // Step 3: If it's tea, run disease detection
        if (_teaDetectionStatus == 'tea') {
          try {
            // Convert to YUV bytes for YOLO
            await _runYoloOnFrame(cameraImage);
          } catch (e) {
            if (kDebugMode) debugPrint('Disease detection error: $e');
            if (!mounted) return;
            setState(() => _results = []);
          }
        } else {
          _analyzeImageQuality(cameraImage, []);
          setState(() => _results = []);
        }
      }

      // Clean up temp file
      // Reuse a single temp file; do not delete each time
    } catch (e) {
      if (kDebugMode) debugPrint('Pipeline error: $e');
    }
  }

  Future<void> _startStream() async {
    if (_controller.value.isStreamingImages) return;
    final localizations = AppLocalizations.of(context);
    setState(() {
      _recording = true;
      _teaDetectionStatus = null;
      _userGuidance = localizations?.positionTeaLeafCenterShort ?? 'Position tea leaf in center';
      _guidanceType = GuidanceType.info;
      _results = [];
    });

    await _controller.startImageStream((CameraImage img) async {
      _frameCount++;
      if (_busy) return;
      _busy = true;

      _bufferW = img.width;
      _bufferH = img.height;

      try {
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        // Skip tea checks if within lock window to prioritize YOLO
        final teaInterval = (_teaDetectionStatus == 'tea') ? 1200 : 600;
        final skipTeaCheck = nowMs < _teaLockUntilMs;
        if (!skipTeaCheck && (_teaDetectionStatus == null || nowMs - _lastTeaCheckMs >= teaInterval)) {
          _lastTeaCheckMs = nowMs;
          await _runFullPipeline(img);
        } else if (_teaDetectionStatus == 'tea') {
          await _runYoloOnFrame(img);
        } else {
          // Non-tea detected, just update guidance
          _analyzeImageQuality(img, []);
        }

        if (kDebugMode && _results.isNotEmpty && _frameCount % 15 == 0) {
          debugPrint('det sample: ${_results.first}');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Stream processing error: $e');
      } finally {
        _busy = false;
      }
    });
  }

  Future<void> _stopStream() async {
    if (_controller.value.isStreamingImages) {
      await _controller.stopImageStream();
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _results = const [];
      _teaDetectionStatus = null;
      _teaConfidence = null;
      _userGuidance = null;
      _guidanceType = GuidanceType.neutral;
      _recentFrames.clear();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fpsTimer?.cancel();
    () async {
      try {
        if (_controller.value.isStreamingImages) {
          await _controller.stopImageStream();
        }
      } catch (_) {}
      await _controller.dispose();
    }();
    super.dispose();
  }

  // Compute rotation the preview is showing (0/90/180/270)
  int _rotationForPreview() {
    final sensor = _camera.sensorOrientation; // 0/90/180/270
    final o = _controller.value.deviceOrientation;

    switch (o) {
      case DeviceOrientation.portraitUp:
        return sensor % 360;
      case DeviceOrientation.landscapeLeft:
        return (sensor + 270) % 360;
      case DeviceOrientation.landscapeRight:
        return (sensor + 90) % 360;
      case DeviceOrientation.portraitDown:
        return (sensor + 180) % 360;
      default:
        return sensor % 360;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch locale to trigger rebuild on language change
    ref.watch(localeProvider);
    final localizations = AppLocalizations.of(context);
    
    if (!_inited) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // full-screen preview (cover)
    final screen = MediaQuery.of(context).size;
    final pv = _controller.value.previewSize!;
    final screenH = math.max(screen.height, screen.width);
    final screenW = math.min(screen.height, screen.width);
    final prevH = math.max(pv.height, pv.width);
    final prevW = math.min(pv.height, pv.width);
    final screenRatio = screenH / screenW;
    final previewRatio = prevH / prevW;

    // Fallback buffer size before first frame arrives
    final bufW = _bufferW == 0 ? prevW.toInt() : _bufferW;
    final bufH = _bufferH == 0 ? prevH.toInt() : _bufferH;

    final rotationDeg = _rotationForPreview(); // preview-aligned rotation

    final topThree = _results
        .map((r) => (r['tag'] ?? r['label'] ?? r['class_name'])?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              widget.title ?? (localizations?.liveDetection ?? 'Live Detection'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // CAMERA
          Center(
            child: OverflowBox(
              maxHeight:
                  screenRatio > previewRatio ? screenH : (screenW / prevW) * prevH,
              maxWidth:
                  screenRatio > previewRatio ? (screenH / prevH) * prevW : screenW,
              child: CameraPreview(_controller),
            ),
          ),

          // BOXES
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                willChange: true,
                painter: _BoxesPainter(
                  results: _results,
                  bufferW: bufW,
                  bufferH: bufH,
                  rotationDeg: rotationDeg,
                  // NEW: pass preview size so we can scale buffer->preview first
                  previewW: prevW.toInt(),
                  previewH: prevH.toInt(),
                  isFront: _camera.lensDirection == CameraLensDirection.front,
                ),
              ),
            ),
          ),

          // LABEL CHIPS (top-left) — enhanced design
          if (_recording && topThree.isNotEmpty)
            Positioned(
              top: kToolbarHeight + 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: topThree
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.redAccent.withOpacity(0.8),
                                  Colors.redAccent.withOpacity(0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, 
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  t,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),

          // Enhanced controls (top-right)
          Positioned(
            top: kToolbarHeight + 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.speed, color: Colors.greenAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${_fps.toStringAsFixed(0)} fps',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _EnhancedControlButton(
                  icon: _torch ? Icons.flash_on : Icons.flash_off,
                  label: _torch ? (localizations?.flashOn ?? 'Flash ON') : (localizations?.flashOff ?? 'Flash OFF'),
                  isActive: _torch,
                  onTap: _toggleTorch,
                ),
                const SizedBox(height: 12),
                _EnhancedControlButton(
                  icon: Icons.cameraswitch,
                  label: localizations?.switchCamera ?? 'Switch',
                  onTap: _switchCamera,
                ),
              ],
            ),
          ),

          // Enhanced TEA DETECTION STATUS (top-center)
          if (_recording && _teaDetectionStatus != null)
            Positioned(
              top: kToolbarHeight + 70,
              left: 0,
              right: 0,
              child: Center(
                child: _TeaStatusChip(
                  status: _teaDetectionStatus!,
                  confidence: _teaConfidence,
                ),
              ),
            ),

          // Enhanced USER GUIDANCE (bottom, above zoom)
          if (_recording && _userGuidance != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 220,
              child: _UserGuidanceCard(
                message: _userGuidance!,
                type: _guidanceType,
              ),
            ),

          // Enhanced IDLE HINT
          if (!_recording)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.greenAccent,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          localizations?.readyToScanLive ?? 'Ready to Scan',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          localizations?.fillFrameWithTeaLeaf ?? 'Fill the frame with tea leaf\nHold steady • Ensure good lighting',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Enhanced ZOOM CONTROL (bottom center)
          Positioned(
            left: 20,
            right: 20,
            bottom: 140,
            child: _ZoomControl(
              zoom: _zoom,
              onZoomChanged: (v) async {
                setState(() => _zoom = v);
                try {
                  await _controller.setZoomLevel(v);
                } catch (_) {}
              },
            ),
          ),
        ],
      ),

      // Enhanced RECORD / STOP button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Stack(
        alignment: Alignment.center,
        children: [
          if (!_recording)
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                final t = _pulseCtrl.value;
                final scale = 1.0 + 0.3 * t;
                final op = (1.0 - t) * 0.5;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.redAccent.withOpacity(op),
                          Colors.red.withOpacity(op * 0.5),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(op * 0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _recording
                    ? [Colors.orange.shade600, Colors.red.shade700]
                    : [Colors.redAccent, Colors.red.shade700],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_recording ? Colors.orange : Colors.redAccent)
                      .withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: _recording ? _stopStream : _startStream,
                child: Center(
                  child: Icon(
                    _recording ? Icons.stop_rounded : Icons.fiber_manual_record,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      );
}

/// Enhanced Tea detection status chip
class _TeaStatusChip extends StatelessWidget {
  const _TeaStatusChip({required this.status, this.confidence});

  final String status;
  final double? confidence;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    Color bgColor;
    Color borderColor;
    String text;
    IconData icon;
    List<Color> gradientColors;

    switch (status) {
      case 'tea':
        bgColor = Colors.green;
        borderColor = Colors.greenAccent;
        text = localizations?.teaLeafDetected ?? 'Tea Leaf Detected';
        icon = Icons.check_circle_rounded;
        gradientColors = [Colors.green.shade600, Colors.green.shade800];
        break;
      case 'non-tea':
        bgColor = Colors.orange;
        borderColor = Colors.orangeAccent;
        text = localizations?.notATeaLeaf ?? 'Not a Tea Leaf';
        icon = Icons.cancel_rounded;
        gradientColors = [Colors.orange.shade600, Colors.orange.shade800];
        break;
      case 'checking':
        bgColor = Colors.blue;
        borderColor = Colors.blueAccent;
        text = localizations?.scanning ?? 'Scanning...';
        icon = Icons.search_rounded;
        gradientColors = [Colors.blue.shade600, Colors.blue.shade800];
        break;
      default:
        bgColor = Colors.grey;
        borderColor = Colors.grey;
        text = localizations?.waiting ?? 'Waiting...';
        icon = Icons.camera_alt_rounded;
        gradientColors = [Colors.grey.shade600, Colors.grey.shade800];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
          if (confidence != null && status == 'tea') ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${(confidence! * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Enhanced control button
class _EnhancedControlButton extends StatelessWidget {
  const _EnhancedControlButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isActive
                  ? [Colors.amber.shade600, Colors.orange.shade700]
                  : [
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.4),
                    ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? Colors.amberAccent
                  : Colors.white.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? Colors.amber.withOpacity(0.4)
                    : Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onTap,
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Enhanced User guidance card with colored styling based on guidance type
class _UserGuidanceCard extends StatelessWidget {
  const _UserGuidanceCard({required this.message, required this.type});

  final String message;
  final GuidanceType type;

  @override
  Widget build(BuildContext context) {
    List<Color> gradientColors;
    Color borderColor;
    IconData icon;
    Color iconColor;

    switch (type) {
      case GuidanceType.success:
        gradientColors = [Colors.green.shade600, Colors.green.shade800];
        borderColor = Colors.greenAccent;
        icon = Icons.check_circle_rounded;
        iconColor = Colors.greenAccent;
        break;
      case GuidanceType.warning:
        gradientColors = [Colors.orange.shade600, Colors.orange.shade800];
        borderColor = Colors.orangeAccent;
        icon = Icons.warning_rounded;
        iconColor = Colors.orangeAccent;
        break;
      case GuidanceType.info:
        gradientColors = [Colors.blue.shade600, Colors.blue.shade800];
        borderColor = Colors.blueAccent;
        icon = Icons.info_rounded;
        iconColor = Colors.blueAccent;
        break;
      case GuidanceType.neutral:
        gradientColors = [Colors.grey.shade600, Colors.grey.shade800];
        borderColor = Colors.grey;
        icon = Icons.help_outline_rounded;
        iconColor = Colors.grey.shade300;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.4),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.3,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomControl extends StatelessWidget {
  const _ZoomControl({required this.zoom, required this.onZoomChanged});

  final double zoom;
  final ValueChanged<double> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.zoom_in_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.greenAccent,
                inactiveTrackColor: Colors.white.withOpacity(0.2),
                thumbColor: Colors.greenAccent,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                trackHeight: 4,
              ),
              child: Slider(
                value: zoom.clamp(1.0, 6.0),
                min: 1.0,
                max: 6.0,
                divisions: 50,
                onChanged: onZoomChanged,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.greenAccent.withOpacity(0.2),
                  Colors.greenAccent.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.greenAccent.withOpacity(0.3),
              ),
            ),
            child: Text(
              '${zoom.toStringAsFixed(1)}x',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter: buffer -> (rotate) -> preview -> (mirror) -> cover-to-canvas.
/// This keeps boxes locked to what the user actually sees.
class _BoxesPainter extends CustomPainter {
  _BoxesPainter({
    required this.results,
    required this.bufferW,
    required this.bufferH,
    required this.rotationDeg,
    required this.previewW,
    required this.previewH,
    this.isFront = false,
  });

  final List<Map<String, dynamic>> results;
  final int bufferW;      // CameraImage size (landscape native)
  final int bufferH;
  final int rotationDeg;  // preview-aligned rotation 0/90/180/270
  final int previewW;     // controller.value.previewSize rotated to portrait
  final int previewH;
  final bool isFront;

  // ---- helpers ----
  static ({double x0, double y0, double x1, double y1}) _parseBox(
      dynamic box, int spaceW, int spaceH) {
    double x0 = 0, y0 = 0, x1 = 0, y1 = 0;

    if (box is List && box.length >= 4) {
      final a = (box[0] as num).toDouble();
      final b = (box[1] as num).toDouble();
      final c = (box[2] as num).toDouble();
      final d = (box[3] as num).toDouble();

      if (c > a && d > b) {
        // [x1,y1,x2,y2]
        x0 = a; y0 = b; x1 = c; y1 = d;
      } else {
        // [x,y,w,h] or [cx,cy,w,h]
        x0 = a; y0 = b; x1 = a + c; y1 = b + d;
        if (x1 <= x0 || y1 <= y0) {
          // [cx,cy,w,h]
          x0 = a - c / 2.0; y0 = b - d / 2.0;
          x1 = a + c / 2.0; y1 = b + d / 2.0;
        }
      }

      // normalized?
      if (x1 <= 2 && y1 <= 2) {
        x0 *= spaceW; x1 *= spaceW; y0 *= spaceH; y1 *= spaceH;
      }
      return (x0: x0, y0: y0, x1: x1, y1: y1);
    }

    if (box is Map) {
      double? left = (box['left'] ?? box['x'])?.toDouble();
      double? top = (box['top'] ?? box['y'])?.toDouble();
      double? right = (box['right'])?.toDouble();
      double? bottom = (box['bottom'])?.toDouble();
      double? w = (box['w'] ?? box['width'])?.toDouble();
      double? h = (box['h'] ?? box['height'])?.toDouble();
      double? cx = (box['cx'])?.toDouble();
      double? cy = (box['cy'])?.toDouble();

      if (left != null && top != null && right != null && bottom != null) {
        x0 = left; y0 = top; x1 = right; y1 = bottom;
      } else if (left != null && top != null && w != null && h != null) {
        x0 = left; y0 = top; x1 = left + w; y1 = top + h;
      } else if (cx != null && cy != null && w != null && h != null) {
        x0 = cx - w / 2; y0 = cy - h / 2; x1 = cx + w / 2; y1 = cy + h / 2;
      }

      if (x1 <= 2 && y1 <= 2) {
        x0 *= spaceW; x1 *= spaceW; y0 *= spaceH; y1 *= spaceH;
      }
      return (x0: x0, y0: y0, x1: x1, y1: y1);
    }

    return (x0: 0, y0: 0, x1: 0, y1: 0);
  }

  // Rotate from raw buffer orientation to preview-upright orientation.
  ({double x, double y}) _rotate(double x, double y) {
    switch (rotationDeg % 360) {
      case 0:
        return (x: x, y: y);
      case 90:
        return (x: bufferH - y, y: x);
      case 180:
        return (x: bufferW - x, y: bufferH - y);
      case 270:
        return (x: y, y: bufferW - x);
      default:
        return (x: x, y: y);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (bufferW == 0 || bufferH == 0 || previewW == 0 || previewH == 0) return;

    // Effective (rotated) buffer dims shown inside the preview texture:
    final rotated = (rotationDeg ~/ 90) % 2 == 1;
    final bufEffW = rotated ? bufferH : bufferW;
    final bufEffH = rotated ? bufferW : bufferH;

    // STEP A: buffer -> preview scaling (handles different resolutions)
    final sBuf2PrevX = previewW / bufEffW;
    final sBuf2PrevY = previewH / bufEffH;

    // STEP B: preview -> canvas (BoxFit.cover) – must match the widget that draws preview
    final scaleCover = math.max(size.width / previewW, size.height / previewH);
    final drawW = previewW * scaleCover;
    final drawH = previewH * scaleCover;
    final dx = (size.width - drawW) / 2;
    final dy = (size.height - drawH) / 2;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF25D5FD);
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Colors.black38;

    for (final r in results) {
      final rawBox = r['box'];
      if (rawBox == null) continue;

      // Parse in raw buffer space
      final pb = _parseBox(rawBox, bufferW, bufferH);

      // Rotate into preview-upright buffer space
      final q0 = _rotate(pb.x0, pb.y0);
      final q1 = _rotate(pb.x1, pb.y1);
      double rx0 = math.min(q0.x, q1.x);
      double ry0 = math.min(q0.y, q1.y);
      double rx1 = math.max(q0.x, q1.x);
      double ry1 = math.max(q0.y, q1.y);

      // Scale buffer -> preview texture space
      rx0 *= sBuf2PrevX; rx1 *= sBuf2PrevX;
      ry0 *= sBuf2PrevY; ry1 *= sBuf2PrevY;

      // Optional mirror in preview space (front camera)
      if (isFront) {
        final nx0 = previewW - rx1;
        final nx1 = previewW - rx0;
        rx0 = nx0; rx1 = nx1;
      }

      // Clamp to preview
      rx0 = rx0.clamp(0.0, previewW.toDouble());
      ry0 = ry0.clamp(0.0, previewH.toDouble());
      rx1 = rx1.clamp(0.0, previewW.toDouble());
      ry1 = ry1.clamp(0.0, previewH.toDouble());

      if ((rx1 - rx0) <= 1 || (ry1 - ry0) <= 1) continue;

      // Finally: preview -> canvas (cover)
      final left   = rx0 * scaleCover + dx;
      final top    = ry0 * scaleCover + dy;
      final right  = rx1 * scaleCover + dx;
      final bottom = ry1 * scaleCover + dy;

      if (right <= 0 || bottom <= 0 || left >= size.width || top >= size.height) {
        continue;
      }

      final rect = Rect.fromLTRB(left, top, right, bottom);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(rr.inflate(1.5), shadow);
      canvas.drawRRect(rr, stroke);

      // label (name only)
      final label = (r['tag'] ?? r['label'] ?? r['class_name'])?.toString() ?? 'obj';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 16);

      const padX = 8.0, padY = 5.0;
      final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + 8,
          rect.top + 8,
          tp.width + padX * 2,
          tp.height + padY * 2,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(pill, Paint()..color = Colors.black.withOpacity(0.65));
      tp.paint(canvas, Offset(pill.left + padX, pill.top + padY));
    }
  }

  @override
  bool shouldRepaint(covariant _BoxesPainter old) =>
      old.results != results ||
      old.bufferW != bufferW ||
      old.bufferH != bufferH ||
      old.rotationDeg != rotationDeg ||
      old.previewW != previewW ||
      old.previewH != previewH ||
      old.isFront != isFront;
}