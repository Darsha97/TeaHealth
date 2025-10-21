 


// // lib/live_detect_page.dart
// import 'dart:async';
// import 'dart:math' as math;
// import 'package:camera/camera.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_vision/flutter_vision.dart';

// class LiveDetectPage extends StatefulWidget {
//   const LiveDetectPage({
//     super.key,
//     required this.vision,
//     this.title = 'Live Detection',
//     this.conf = 0.35,
//     this.iou = 0.45,
//     this.cls = 0.35,
//   });

//   final FlutterVision vision;
//   final String title;
//   final double conf;
//   final double iou;
//   final double cls;

//   @override
//   State<LiveDetectPage> createState() => _LiveDetectPageState();
// }

// class _LiveDetectPageState extends State<LiveDetectPage> {
//   late CameraController _controller;
//   late CameraDescription _camera;
//   bool _inited = false;
//   bool _busy = false;

//   List<Map<String, dynamic>> _results = const [];
//   int _imgH = 0, _imgW = 0;

//   @override
//   void initState() {
//     super.initState();
//     _initializeCamera();
//   }

//   Future<void> _initializeCamera() async {
//     final cameras = await availableCameras();
//     _camera = cameras.firstWhere(
//       (c) => c.lensDirection == CameraLensDirection.back,
//       orElse: () => cameras.first,
//     );

//     _controller = CameraController(
//       _camera,
//       ResolutionPreset.max,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );

//     await _controller.initialize();

//     await _controller.setFocusMode(FocusMode.auto);
//     await _controller.setExposureMode(ExposureMode.auto);
//     await _controller.setZoomLevel(1.0);

//     if (!mounted) return;
//     setState(() => _inited = true);

//     _startImageStream();
//   }

//   Future<void> _startImageStream() async {
//     await _controller.startImageStream((CameraImage img) async {
//       if (_busy) return;
//       _busy = true;

//       _imgH = img.height;
//       _imgW = img.width;

//       try {
//         final results = await widget.vision.yoloOnFrame(
//           bytesList: img.planes.map((p) => p.bytes).toList(),
//           imageWidth: img.width,
//           imageHeight: img.height,
//           iouThreshold: widget.iou,
//           confThreshold: widget.conf,
//           classThreshold: widget.cls,
//         );

//         if (!mounted) return;
//         setState(() => _results = List<Map<String, dynamic>>.from(results));

//         if (kDebugMode) {
//           debugPrint(
//               'YOLO: ${results.length} | frame: ${img.width}x${img.height}');
//         }
//       } catch (e) {
//         if (kDebugMode) debugPrint('Error in YOLO frame: $e');
//       } finally {
//         _busy = false;
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _disposeCamera();
//     super.dispose();
//   }

//   Future<void> _disposeCamera() async {
//     try {
//       if (_controller.value.isStreamingImages) {
//         await _controller.stopImageStream();
//       }
//       await _controller.dispose();
//     } catch (e) {
//       debugPrint('Camera dispose error: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (!_inited) {
//       return const Scaffold(
//         backgroundColor: Colors.black,
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     final screen = MediaQuery.of(context).size;
//     final preview = _controller.value.previewSize!;
//     final screenH = math.max(screen.height, screen.width);
//     final screenW = math.min(screen.height, screen.width);
//     final previewH = math.max(preview.height, preview.width);
//     final previewW = math.min(preview.height, preview.width);
//     final screenRatio = screenH / screenW;
//     final previewRatio = previewH / previewW;

//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Text(widget.title),
//         backgroundColor: Colors.black,
//       ),
//       body: Stack(
//         children: [
//           // Full-screen camera preview
//           Center(
//             child: OverflowBox(
//               maxHeight: screenRatio > previewRatio
//                   ? screenH
//                   : screenW / previewW * previewH,
//               maxWidth: screenRatio > previewRatio
//                   ? screenH / previewH * previewW
//                   : screenW,
//               child: CameraPreview(_controller),
//             ),
//           ),

//           // Bounding box overlay
//           Positioned.fill(
//             child: _BndBoxVision(
//               results: _results,
//               previewH: _imgH == 0 ? previewH.toInt() : _imgH,
//               previewW: _imgW == 0 ? previewW.toInt() : _imgW,
//               screenH: screenH,
//               screenW: screenW,
//             ),
//           ),

//           // Detection HUD
//           Positioned(
//             top: 16,
//             left: 16,
//             child: DecoratedBox(
//               decoration: BoxDecoration(
//                 color: Colors.black54,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Padding(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 child: Text(
//                   _results.isEmpty
//                       ? 'Detecting…'
//                       : _results
//                           .map((r) => _labelText(r))
//                           .where((s) => s.isNotEmpty)
//                           .take(3)
//                           .join(' • '),
//                   style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w700),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _labelText(Map r) {
//     final label = r['tag'] ?? r['label'] ?? r['class_name'];
//     final conf =
//         (r['confidence'] ?? r['score'] ?? (r['box'] is List ? r['box'][4] : 0))
//             as num?;
//     if (label == null) return '';
//     if (conf == null) return '$label';
//     final pct = (conf * 100).clamp(0, 100).toStringAsFixed(0);
//     return '$label $pct%';
//   }
// }

// class _BndBoxVision extends StatelessWidget {
//   const _BndBoxVision({
//     required this.results,
//     required this.previewH,
//     required this.previewW,
//     required this.screenH,
//     required this.screenW,
//   });

//   final List<Map<String, dynamic>> results;
//   final int previewH, previewW;
//   final double screenH, screenW;

//   @override
//   Widget build(BuildContext context) {
//     if (results.isEmpty) return const SizedBox.shrink();

//     final children = results.map((r) {
//       final b = (r['box'] as List).map((e) => (e as num).toDouble()).toList();
//       double x = b[0], y = b[1], w, h;
//       if (b[2] > x && b[3] > y) {
//         w = b[2] - x;
//         h = b[3] - y;
//       } else {
//         w = b[2];
//         h = b[3];
//       }

//       if (b[2] <= 1.5 && b[3] <= 1.5) {
//         x *= previewW;
//         y *= previewH;
//         w *= previewW;
//         h *= previewH;
//       }

//       late double scaleW, scaleH, px, py, pw, ph;

//       if (screenH / screenW > previewH / previewW) {
//         scaleW = screenH / previewH * previewW;
//         scaleH = screenH;
//         final difW = (scaleW - screenW) / scaleW;
//         px = (x / previewW - difW / 2) * scaleW;
//         pw = (w / previewW) * scaleW;
//         if (x / previewW < difW / 2) pw -= (difW / 2 - x / previewW) * scaleW;
//         py = (y / previewH) * scaleH;
//         ph = (h / previewH) * scaleH;
//       } else {
//         scaleH = screenW / previewW * previewH;
//         scaleW = screenW;
//         final difH = (scaleH - screenH) / scaleH;
//         px = (x / previewW) * scaleW;
//         pw = (w / previewW) * scaleW;
//         py = (y / previewH - difH / 2) * scaleH;
//         ph = (h / previewH) * scaleH;
//         if (y / previewH < difH / 2) ph -= (difH / 2 - y / previewH) * scaleH;
//       }

//       final label = (r['tag'] ?? r['label'] ?? r['class_name'])?.toString() ?? 'obj';
//       final conf =
//           (r['confidence'] ?? r['score'] ?? (b.length > 4 ? b[4] : 0)) as num?;
//       final pct =
//           conf == null ? '' : ' ${(conf * 100).clamp(0, 100).toStringAsFixed(0)}%';

//       return Positioned(
//         left: math.max(0, px),
//         top: math.max(0, py),
//         width: pw,
//         height: ph,
//         child: Container(
//           padding: const EdgeInsets.only(top: 5, left: 5),
//           decoration: BoxDecoration(
//             border: Border.all(color: const Color(0xFF25D5FD), width: 3),
//             borderRadius: BorderRadius.circular(4),
//           ),
//           child: Text(
//             '$label$pct',
//             style: const TextStyle(
//               color: Color(0xFF25D5FD),
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//       );
//     }).toList();

//     return IgnorePointer(child: Stack(children: children));
//   }
// }



// // lib/live_detect_page.dart
// import 'dart:async';
// import 'dart:math' as math;

// import 'package:camera/camera.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_vision/flutter_vision.dart';

// class LiveDetectPage extends StatefulWidget {
//   const LiveDetectPage({
//     super.key,
//     required this.vision,
//     this.title = 'Live Detection',
//     this.conf = 0.35,
//     this.iou = 0.45,
//     this.cls = 0.35,
//   });

//   final FlutterVision vision;
//   final String title;
//   final double conf;
//   final double iou;
//   final double cls;

//   @override
//   State<LiveDetectPage> createState() => _LiveDetectPageState();
// }

// class _LiveDetectPageState extends State<LiveDetectPage> {
//   late CameraController _controller;
//   late CameraDescription _camera;
//   bool _inited = false;
//   bool _busy = false;

//   // Latest YOLO results
//   List<Map<String, dynamic>> _results = const [];

//   // Current image buffer size
//   int _imgH = 0, _imgW = 0;

//   // --- Live, user-friendly hint system ---
//   String _hint = 'Point the camera at a single leaf';
//   DateTime _lastAnyDetection = DateTime.now();
//   double _avgLuma = 0;   // brightness 0..255
//   double _sharpness = 0; // cheap edge metric
//   int _frameCount = 0;

//   @override
//   void initState() {
//     super.initState();
//     _init();
//   }

//   Future<void> _init() async {
//     final cams = await availableCameras();
//     _camera = cams.firstWhere(
//       (c) => c.lensDirection == CameraLensDirection.back,
//       orElse: () => cams.first,
//     );

//     _controller = CameraController(
//       _camera,
//       ResolutionPreset.max, // high-res preview, still streams YUV for analysis
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );

//     await _controller.initialize();
//     await _controller.setFocusMode(FocusMode.auto);
//     await _controller.setExposureMode(ExposureMode.auto);
//     await _controller.setZoomLevel(1.0);

//     if (!mounted) return;
//     setState(() => _inited = true);

//     // Start image stream → YOLO
//     await _controller.startImageStream((CameraImage img) async {
//       if (_busy) return;
//       _busy = true;

//       _imgH = img.height;
//       _imgW = img.width;

//       try {
//         final results = await widget.vision.yoloOnFrame(
//           bytesList: img.planes.map((p) => p.bytes).toList(),
//           imageWidth: img.width,
//           imageHeight: img.height,
//           iouThreshold: widget.iou,
//           confThreshold: widget.conf,
//           classThreshold: widget.cls,
//         );

//         if (!mounted) return;
//         setState(() {
//           _results = List<Map<String, dynamic>>.from(results);
//         });

//         // Update context-aware hint
//         _updateHint(img, _results);

//         if (kDebugMode && _frameCount % 10 == 0) {
//           debugPrint('YOLO: ${results.length} | ${img.width}x${img.height}');
//         }
//       } catch (e) {
//         if (kDebugMode) debugPrint('yoloOnFrame error: $e');
//       } finally {
//         _busy = false;
//       }
//     });

//     // Show “How to scan” once at start (optional)
//     Future.delayed(const Duration(milliseconds: 350), () {
//       if (mounted) _showHowToSheet(context);
//     });
//   }

//   @override
//   void dispose() {
//     () async {
//       try {
//         if (_controller.value.isStreamingImages) {
//           await _controller.stopImageStream();
//         }
//       } catch (_) {}
//       await _controller.dispose();
//     }();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (!_inited) {
//       return const Scaffold(
//         backgroundColor: Colors.black,
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     // Same “full-screen camera” trick used in classic tflite samples
//     final screen = MediaQuery.of(context).size;
//     final previewSize = _controller.value.previewSize!;
//     final screenH = math.max(screen.height, screen.width);
//     final screenW = math.min(screen.height, screen.width);
//     final prevH = math.max(previewSize.height, previewSize.width);
//     final prevW = math.min(previewSize.height, previewSize.width);
//     final screenRatio = screenH / screenW;
//     final previewRatio = prevH / prevW;

//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Text(widget.title),
//         backgroundColor: Colors.black,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.help_outline),
//             tooltip: 'How to scan',
//             onPressed: () => _showHowToSheet(context),
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           // FULL-SCREEN PREVIEW (OverflowBox scales to fill)
//           Center(
//             child: OverflowBox(
//               maxHeight: screenRatio > previewRatio
//                   ? screenH
//                   : (screenW / prevW) * prevH,
//               maxWidth: screenRatio > previewRatio
//                   ? (screenH / prevH) * prevW
//                   : screenW,
//               child: CameraPreview(_controller),
//             ),
//           ),

//           // BOUNDING BOX OVERLAY
//           Positioned.fill(
//             child: _BndBoxVision(
//               results: _results,
//               previewH: _imgH == 0 ? prevH.toInt() : _imgH,
//               previewW: _imgW == 0 ? prevW.toInt() : _imgW,
//               screenH: screenH,
//               screenW: screenW,
//             ),
//           ),

//           // Top-left: quick labels (top 3)
//           Positioned(
//             top: 16,
//             left: 16,
//             child: DecoratedBox(
//               decoration: BoxDecoration(
//                 color: Colors.black54,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Padding(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 child: Text(
//                   _results.isEmpty
//                       ? 'Detecting…'
//                       : _results
//                           .map(_prettyLabel)
//                           .where((s) => s.isNotEmpty)
//                           .take(3)
//                           .join(' • '),
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 14,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               ),
//             ),
//           ),

//           // Bottom live hint banner
//           Positioned(
//             left: 12,
//             right: 12,
//             bottom: 20,
//             child: AnimatedSwitcher(
//               duration: const Duration(milliseconds: 250),
//               child: _HintPill(key: ValueKey(_hint), text: _hint),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ---------- Helpers ----------

//   String _prettyLabel(Map r) {
//     final tag = r['tag'] ?? r['label'] ?? r['class_name'];
//     final conf =
//         (r['confidence'] ?? r['score'] ?? (r['box'] is List ? r['box'][4] : 0))
//             as num?;
//     if (tag == null) return '';
//     if (conf == null) return '$tag';
//     final pct = (conf * 100).clamp(0, 100).toStringAsFixed(0);
//     return '$tag $pct%';
//   }

//   double _estimateLuma(CameraImage img) {
//     final y = img.planes.first.bytes;
//     if (y.isEmpty) return 0;
//     int sum = 0, n = 0;
//     for (int i = 0; i < y.length; i += 8) {
//       sum += y[i];
//       n++;
//     }
//     return n == 0 ? 0 : sum / n;
//   }

//   double _estimateSharpness(CameraImage img) {
//     final y = img.planes.first.bytes;
//     if (y.isEmpty) return 0;
//     final w = img.width, h = img.height;
//     final stepX = (w / 32).clamp(1, w).toInt();
//     final stepY = (h / 32).clamp(1, h).toInt();
//     int acc = 0, n = 0;

//     for (int yy = stepY; yy < h; yy += stepY) {
//       final row = yy * w;
//       for (int xx = stepX; xx < w; xx += stepX) {
//         final i = row + xx;
//         final left = row + (xx - stepX);
//         final up = (yy - stepY) * w + xx;
//         if (i < y.length && left < y.length) {
//           acc += (y[i] - y[left]).abs();
//           n++;
//         }
//         if (i < y.length && up < y.length) {
//           acc += (y[i] - y[up]).abs();
//           n++;
//         }
//       }
//     }
//     return n == 0 ? 0 : acc / n.toDouble();
//   }

//   void _updateHint(CameraImage img, List<Map<String, dynamic>> results) {
//     // Any good detection?
//     final anyGood = results.any((r) {
//       final c = (r['confidence'] ??
//               r['score'] ??
//               (r['box'] is List ? r['box'][4] : 0)) as num? ??
//           0;
//       return c >= 0.35;
//     });
//     if (anyGood) _lastAnyDetection = DateTime.now();

//     // Update scene stats every 3rd frame
//     _frameCount++;
//     if (_frameCount % 3 == 0) {
//       _avgLuma = _estimateLuma(img);
//       _sharpness = _estimateSharpness(img);
//     }

//     // Build hint
//     String newHint = _hint;
//     final msSince = DateTime.now().difference(_lastAnyDetection).inMilliseconds;

//     if (_avgLuma < 50) {
//       newHint = 'Increase light • avoid backlight';
//     } else if (_sharpness < 5) {
//       newHint = 'Hold steady • avoid motion blur';
//     } else if (results.isEmpty && msSince > 2000) {
//       newHint = 'Fill the frame with one leaf (60–80%)';
//     } else if (results.length > 3 && msSince > 1500) {
//       newHint = 'One leaf at a time • reduce background clutter';
//     } else {
//       newHint = 'Center the leaf • good lighting';
//     }

//     if (newHint != _hint && mounted) {
//       setState(() => _hint = newHint);
//     }
//   }

//   void _showHowToSheet(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       showDragHandle: true,
//       backgroundColor: const Color(0xFF141414),
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (_) => const Padding(
//         padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Best scan results',
//                 style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w700,
//                     color: Colors.white)),
//             SizedBox(height: 12),
//             _TipRow(
//                 icon: Icons.highlight,
//                 text: 'Use bright, even light (avoid backlight & glare).'),
//             _TipRow(
//                 icon: Icons.center_focus_strong,
//                 text: 'Fill 60–80% of the screen with a single leaf.'),
//             _TipRow(
//                 icon: Icons.pan_tool_alt,
//                 text: 'Hold the phone steady for a moment.'),
//             _TipRow(
//                 icon: Icons.cleaning_services,
//                 text: 'Keep background clean; avoid multiple leaves.'),
//             _TipRow(
//                 icon: Icons.flip_camera_android,
//                 text: 'Try a closer crop or different angle if needed.'),
//             SizedBox(height: 8),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// Bounding boxes overlay (scaled like the classic tflite sample)
// class _BndBoxVision extends StatelessWidget {
//   const _BndBoxVision({
//     required this.results,
//     required this.previewH,
//     required this.previewW,
//     required this.screenH,
//     required this.screenW,
//   });

//   final List<Map<String, dynamic>> results;
//   final int previewH;
//   final int previewW;
//   final double screenH;
//   final double screenW;

//   @override
//   Widget build(BuildContext context) {
//     final children = results.map((r) {
//       final b = (r['box'] as List).map((e) => (e as num).toDouble()).toList();

//       // Accept [x1,y1,x2,y2,(score)] and [x,y,w,h,(score)]
//       double x = b[0], y = b[1], w, h;
//       if (b[2] > x && b[3] > y) {
//         w = b[2] - x;
//         h = b[3] - y;
//       } else {
//         w = b[2];
//         h = b[3];
//       }

//       // If normalized, scale to pixels
//       if (b[2] <= 1.5 && b[3] <= 1.5) {
//         x *= previewW.toDouble();
//         y *= previewH.toDouble();
//         w *= previewW.toDouble();
//         h *= previewH.toDouble();
//       }

//       // Same scaling math as the reference BndBox
//       late double scaleW, scaleH, px, py, pw, ph;

//       if (screenH / screenW > previewH / previewW) {
//         scaleW = screenH / previewH * previewW;
//         scaleH = screenH;
//         final difW = (scaleW - screenW) / scaleW;
//         px = (x / previewW - difW / 2) * scaleW;
//         pw = (w / previewW) * scaleW;
//         if (x / previewW < difW / 2) {
//           pw -= (difW / 2 - x / previewW) * scaleW;
//         }
//         py = (y / previewH) * scaleH;
//         ph = (h / previewH) * scaleH;
//       } else {
//         scaleH = screenW / previewW * previewH;
//         scaleW = screenW;
//         final difH = (scaleH - screenH) / scaleH;
//         px = (x / previewW) * scaleW;
//         pw = (w / previewW) * scaleW;
//         py = (y / previewH - difH / 2) * scaleH;
//         ph = (h / previewH) * scaleH;
//         if (y / previewH < difH / 2) {
//           ph -= (difH / 2 - y / previewH) * scaleH;
//         }
//       }

//       final label =
//           (r['tag'] ?? r['label'] ?? r['class_name'])?.toString() ?? 'obj';
//       final conf =
//           (r['confidence'] ?? r['score'] ?? (b.length > 4 ? b[4] : 0)) as num?;
//       final pct = conf == null
//           ? ''
//           : ' ${(conf * 100).clamp(0, 100).toStringAsFixed(0)}%';

//       return Positioned(
//         left: math.max(0, px),
//         top: math.max(0, py),
//         width: pw,
//         height: ph,
//         child: _BoxBadge(label: '$label$pct'),
//       );
//     }).toList();

//     return IgnorePointer(child: Stack(children: children));
//   }
// }

// class _BoxBadge extends StatelessWidget {
//   const _BoxBadge({required this.label});

//   final String label;

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         // pretty cyan rounded rectangle
//         Positioned.fill(
//           child: Container(
//             decoration: BoxDecoration(
//               border: Border.all(color: const Color(0xFF25D5FD), width: 3),
//               borderRadius: BorderRadius.circular(8),
//             ),
//           ),
//         ),
//         // label pill
//         Positioned(
//           left: 6,
//           top: 6,
//           child: DecoratedBox(
//             decoration: BoxDecoration(
//               color: Colors.black.withOpacity(0.65),
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
//               child: Text(
//                 label,
//                 style: const TextStyle(
//                   color: Color(0xFF25D5FD),
//                   fontSize: 12,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _HintPill extends StatelessWidget {
//   const _HintPill({super.key, required this.text});
//   final String text;

//   @override
//   Widget build(BuildContext context) {
//     return DecoratedBox(
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.60),
//         borderRadius: BorderRadius.circular(999),
//         border: Border.all(color: Colors.white24),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//         child: Text(
//           text,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//               color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
//         ),
//       ),
//     );
//   }
// }

// class _TipRow extends StatelessWidget {
//   const _TipRow({required this.icon, required this.text});
//   final IconData icon;
//   final String text;

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         children: [
//           Icon(icon, size: 18, color: Colors.white70),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Text(
//               text,
//               style: const TextStyle(color: Colors.white70, height: 1.2),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }




// lib/live_detect_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';

class LiveDetectPage extends StatefulWidget {
  const LiveDetectPage({
    super.key,
    required this.vision,
    this.title = 'Live Detection',
    this.conf = 0.25,
    this.iou = 0.45,
    this.cls = 0.25,
  });

  final FlutterVision vision;
  final String title;
  final double conf;
  final double iou;
  final double cls;

  @override
  State<LiveDetectPage> createState() => _LiveDetectPageState();
}

class _LiveDetectPageState extends State<LiveDetectPage>
    with SingleTickerProviderStateMixin {
  late CameraController _controller;
  late CameraDescription _camera;

  bool _inited = false;
  bool _busy = false;
  bool _recording = false;
  bool _torch = false;

  // buffer size used for scaling boxes
  int _bufferW = 0, _bufferH = 0;

  // recognitions
  List<Map<String, dynamic>> _results = const [];

  // fps meter
  int _frameCount = 0;
  double _fps = 0;
  Timer? _fpsTimer;

  // UI / controls
  double _zoom = 1.0;
  double _conf = 0; // set in init to widget.conf
  double _iou = 0;
  double _cls = 0;

  late final AnimationController _pulseCtrl;

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
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller.initialize();
    await _controller.setFocusMode(FocusMode.auto);
    await _controller.setExposureMode(ExposureMode.auto);
    await _controller.setZoomLevel(_zoom);

    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
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

    // stop if streaming
    if (_controller.value.isStreamingImages) {
      await _controller.stopImageStream();
    }
    await _controller.dispose();

    _controller = CameraController(
      _camera,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller.initialize();
    await _controller.setZoomLevel(_zoom);
    await _controller.setFlashMode(FlashMode.off);
    setState(() {});
    if (_recording) _startStream();
  }

  Future<void> _toggleTorch() async {
    // not all cameras support it—best effort
    try {
      if (_torch) {
        await _controller.setFlashMode(FlashMode.off);
      } else {
        await _controller.setFlashMode(FlashMode.torch);
      }
      setState(() => _torch = !_torch);
    } catch (_) {}
  }

  Future<void> _startStream() async {
    if (_controller.value.isStreamingImages) return;
    setState(() => _recording = true);

    await _controller.startImageStream((CameraImage img) async {
      _frameCount++;
      if (_busy) return;
      _busy = true;

      _bufferW = img.width;
      _bufferH = img.height;

      try {
        final results = await widget.vision.yoloOnFrame(
          bytesList: img.planes.map((p) => p.bytes).toList(),
          imageWidth: img.width,
          imageHeight: img.height,
          iouThreshold: _iou,
          confThreshold: _conf,
          classThreshold: _cls,
        );

        if (!mounted) return;
        setState(() => _results = List<Map<String, dynamic>>.from(results));

        if (kDebugMode && _results.isNotEmpty && _frameCount % 15 == 0) {
          debugPrint('det sample: ${_results.first}');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('yoloOnFrame error: $e');
      } finally {
        _busy = false;
      }
    });
  }

  Future<void> _stopStream() async {
    if (_controller.value.isStreamingImages) {
      await _controller.stopImageStream();
    }
    setState(() {
      _recording = false;
      _results = const [];
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

  @override
  Widget build(BuildContext context) {
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

    final bufferW = _bufferW == 0 ? prevW.toInt() : _bufferW;
    final bufferH = _bufferH == 0 ? prevH.toInt() : _bufferH;
    final rotationDeg = _camera.sensorOrientation;

    final topThree = _results
        .map((r) => _prettyLabel(r))
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
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

          // TOP GRADIENT HUD
          IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
          ),

          // BOXES
          Positioned.fill(
            child: CustomPaint(
              painter: _BoxesPainter(
                results: _results,
                bufferW: bufferW,
                bufferH: bufferH,
                rotationDeg: rotationDeg,
              ),
            ),
          ),

          // LABEL CHIPS (top-left)
          Positioned(
            top: kToolbarHeight + 10,
            left: 12,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topThree
                  .map((t) => _pill(t, Colors.white.withOpacity(.1)))
                  .toList(),
            ),
          ),

          // FPS + TORCH + SWITCH (top-right column)
          Positioned(
            top: kToolbarHeight + 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _pill('${_fps.toStringAsFixed(1)} fps', Colors.white10),
                const SizedBox(height: 8),
                _roundIcon(
                  icon: _torch ? Icons.flash_on : Icons.flash_off,
                  onTap: _toggleTorch,
                ),
                const SizedBox(height: 8),
                _roundIcon(icon: Icons.cameraswitch, onTap: _switchCamera),
              ],
            ),
          ),

          // IDLE HINT
          if (!_recording)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Tip: Fill the frame with a single leaf • Hold steady • Good light',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),

          // BOTTOM CONTROL SHEET
          Positioned(
            left: 12,
            right: 12,
            bottom: 110,
            child: _QuickControls(
              zoom: _zoom,
              onZoomChanged: (v) async {
                setState(() => _zoom = v);
                try {
                  await _controller.setZoomLevel(v);
                } catch (_) {}
              },
              conf: _conf,
              iou: _iou,
              cls: _cls,
              onConfChanged: (v) => setState(() => _conf = v),
              onIouChanged: (v) => setState(() => _iou = v),
              onClsChanged: (v) => setState(() => _cls = v),
            ),
          ),
        ],
      ),

      // PULSING RECORD / STOP
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Stack(
        alignment: Alignment.center,
        children: [
          if (!_recording)
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                final t = _pulseCtrl.value;
                final scale = 1.0 + 0.25 * t;
                final op = (1.0 - t) * .6;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withOpacity(op),
                    ),
                  ),
                );
              },
            ),
          FloatingActionButton.large(
            backgroundColor: Colors.redAccent,
            onPressed: _recording ? _stopStream : _startStream,
            child: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
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
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      );

  Widget _roundIcon({required IconData icon, required VoidCallback onTap}) =>
      InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      );

  String _prettyLabel(Map r) {
    final tag = r['tag'] ?? r['label'] ?? r['class_name'];
    final conf =
        (r['confidence'] ?? r['score'] ?? (r['box'] is List ? r['box'][4] : 0))
            as num?;
    if (tag == null) return '';
    if (conf == null) return '$tag';
    final pct = (conf * 100).clamp(0, 100).toStringAsFixed(0);
    return '$tag $pct%';
  }
}

/// Small bottom card with zoom + thresholds
class _QuickControls extends StatelessWidget {
  const _QuickControls({
    required this.zoom,
    required this.onZoomChanged,
    required this.conf,
    required this.iou,
    required this.cls,
    required this.onConfChanged,
    required this.onIouChanged,
    required this.onClsChanged,
  });

  final double zoom;
  final ValueChanged<double> onZoomChanged;

  final double conf;
  final double iou;
  final double cls;
  final ValueChanged<double> onConfChanged;
  final ValueChanged<double> onIouChanged;
  final ValueChanged<double> onClsChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black54,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sliderRow('Zoom', zoom, 1.0, 6.0, onZoomChanged),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _miniSlider('Conf', conf, 0.05, 0.9, onConfChanged),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniSlider('IOU', iou, 0.2, 0.8, onIouChanged),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniSlider('Cls', cls, 0.05, 0.9, onClsChanged),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 48, child: Text(label, style: _lbl)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) * 10).round(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(value.toStringAsFixed(1), textAlign: TextAlign.right, style: _lbl),
        ),
      ],
    );
  }

  Widget _miniSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(
      children: [
        Text(label, style: _lbl),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) * 20).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  TextStyle get _lbl =>
      const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600);
}

/// Painter: robust parsing + rotation + cover-scaling + pretty pills/bar.
class _BoxesPainter extends CustomPainter {
  _BoxesPainter({
    required this.results,
    required this.bufferW,
    required this.bufferH,
    required this.rotationDeg,
  });

  final List<Map<String, dynamic>> results;
  final int bufferW;
  final int bufferH;
  final int rotationDeg;

  @override
  void paint(Canvas canvas, Size size) {
    // Fit = cover transform
    final scale = math.max(size.width / bufferW, size.height / bufferH);
    final drawW = bufferW * scale;
    final drawH = bufferH * scale;
    final dx = (size.width - drawW) / 2;
    final dy = (size.height - drawH) / 2;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF25D5FD);

    for (final r in results) {
      if (r['box'] is! List) continue;
      final b = (r['box'] as List).map((e) => (e as num).toDouble()).toList();
      if (b.length < 4) continue;

      // -> corner pixels
      double x0, y0, x1, y1;
      double a = b[0], bb = b[1], c = b[2], d = b[3];
      if (c > a && d > bb) {
        x0 = a; y0 = bb; x1 = c; y1 = d; // [x1,y1,x2,y2]
      } else {
        x0 = a; y0 = bb; x1 = a + c; y1 = bb + d; // [x,y,w,h]
        if (x1 <= x0 || y1 <= y0) {
          x0 = a - c / 2.0; y0 = bb - d / 2.0; x1 = a + c / 2.0; y1 = bb + d / 2.0; // [cx,cy,w,h]
        }
      }
      if (x1 <= 2 && y1 <= 2) { // normalized
        x0 *= bufferW; x1 *= bufferW; y0 *= bufferH; y1 *= bufferH;
      }

      // rotation
      double rx0, ry0, rx1, ry1;
      switch (rotationDeg % 360) {
        case 0:
          rx0 = x0; ry0 = y0; rx1 = x1; ry1 = y1; break;
        case 90:
          rx0 = bufferH - y1; ry0 = x0; rx1 = bufferH - y0; ry1 = x1; break;
        case 180:
          rx0 = bufferW - x1; ry0 = bufferH - y1; rx1 = bufferW - x0; ry1 = bufferH - y0; break;
        case 270:
          rx0 = y0; ry0 = bufferW - x1; rx1 = y1; ry1 = bufferW - x0; break;
        default:
          rx0 = x0; ry0 = y0; rx1 = x1; ry1 = y1;
      }

      // clamp
      rx0 = rx0.clamp(0.0, bufferW.toDouble());
      ry0 = ry0.clamp(0.0, bufferH.toDouble());
      rx1 = rx1.clamp(0.0, bufferW.toDouble());
      ry1 = ry1.clamp(0.0, bufferH.toDouble());

      // -> canvas
      final left   = rx0 * scale + dx;
      final top    = ry0 * scale + dy;
      final right  = rx1 * scale + dx;
      final bottom = ry1 * scale + dy;

      if (right <= 0 || bottom <= 0 || left >= size.width || top >= size.height) {
        continue;
      }
      final rect = Rect.fromLTRB(left, top, right, bottom);

      // shadowed rounded stroke
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(1.5), const Radius.circular(10)),
        Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        stroke,
      );

      // label pill + confidence bar
      final label = (r['tag'] ?? r['label'] ?? r['class_name'])?.toString() ?? 'obj';
      final conf  = (r['confidence'] ?? r['score'] ?? (b.length > 4 ? b[4] : 0)) as num?;
      final pct   = conf == null ? '' : ' ${(conf * 100).clamp(0, 100).toStringAsFixed(0)}%';
      final text  = '$label$pct';

      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 16);

      const padX = 8.0, padY = 5.0;
      final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 8, rect.top + 8, tp.width + padX * 2, tp.height + padY * 2),
        const Radius.circular(8),
      );
      canvas.drawRRect(pill, Paint()..color = Colors.black.withOpacity(0.65));
      tp.paint(canvas, Offset(pill.left + padX, pill.top + padY));

      if (conf != null) {
        final w = (tp.width + padX * 2) * conf.clamp(0, 1).toDouble();
        final bar = Rect.fromLTWH(pill.left, pill.bottom + 4, w, 3.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(bar, const Radius.circular(2)),
          Paint()..color = const Color(0xFF25D5FD),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoxesPainter old) =>
      old.results != results ||
      old.bufferW != bufferW ||
      old.bufferH != bufferH ||
      old.rotationDeg != rotationDeg;
}
