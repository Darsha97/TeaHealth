

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
//     this.conf = 0.25,
//     this.iou = 0.45,
//     this.cls = 0.25,
//   });

//   final FlutterVision vision;
//   final String title;
//   final double conf;
//   final double iou;
//   final double cls;

//   @override
//   State<LiveDetectPage> createState() => _LiveDetectPageState();
// }

// class _LiveDetectPageState extends State<LiveDetectPage>
//     with SingleTickerProviderStateMixin {
//   late CameraController _controller;
//   late CameraDescription _camera;

//   bool _inited = false;
//   bool _busy = false;
//   bool _recording = false;
//   bool _torch = false;

//   // buffer size used for scaling boxes
//   int _bufferW = 0, _bufferH = 0;

//   // recognitions
//   List<Map<String, dynamic>> _results = const [];

//   // fps meter
//   int _frameCount = 0;
//   double _fps = 0;
//   Timer? _fpsTimer;

//   // UI / controls
//   double _zoom = 1.0;
//   double _conf = 0; // set in init to widget.conf
//   double _iou = 0;
//   double _cls = 0;

//   late final AnimationController _pulseCtrl;

//   @override
//   void initState() {
//     super.initState();
//     _conf = widget.conf;
//     _iou = widget.iou;
//     _cls = widget.cls;
//     _pulseCtrl =
//         AnimationController(vsync: this, duration: const Duration(seconds: 1))
//           ..repeat(reverse: true);
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
//       ResolutionPreset.max,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );

//     await _controller.initialize();
//     await _controller.setFocusMode(FocusMode.auto);
//     await _controller.setExposureMode(ExposureMode.auto);
//     await _controller.setZoomLevel(_zoom);

//     _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//       setState(() {
//         _fps = _frameCount.toDouble();
//         _frameCount = 0;
//       });
//     });

//     if (!mounted) return;
//     setState(() => _inited = true);
//   }

//   Future<void> _switchCamera() async {
//     final cams = await availableCameras();
//     final idx = cams.indexOf(_camera);
//     final next = cams[(idx + 1) % cams.length];
//     _camera = next;

//     // stop if streaming
//     if (_controller.value.isStreamingImages) {
//       await _controller.stopImageStream();
//     }
//     await _controller.dispose();

//     _controller = CameraController(
//       _camera,
//       ResolutionPreset.max,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );
//     await _controller.initialize();
//     await _controller.setZoomLevel(_zoom);
//     await _controller.setFlashMode(FlashMode.off);
//     setState(() {});
//     if (_recording) _startStream();
//   }

//   Future<void> _toggleTorch() async {
//     // not all cameras support it—best effort
//     try {
//       if (_torch) {
//         await _controller.setFlashMode(FlashMode.off);
//       } else {
//         await _controller.setFlashMode(FlashMode.torch);
//       }
//       setState(() => _torch = !_torch);
//     } catch (_) {}
//   }

//   Future<void> _startStream() async {
//     if (_controller.value.isStreamingImages) return;
//     setState(() => _recording = true);

//     await _controller.startImageStream((CameraImage img) async {
//       _frameCount++;
//       if (_busy) return;
//       _busy = true;

//       _bufferW = img.width;
//       _bufferH = img.height;

//       try {
//         final results = await widget.vision.yoloOnFrame(
//           bytesList: img.planes.map((p) => p.bytes).toList(),
//           imageWidth: img.width,
//           imageHeight: img.height,
//           iouThreshold: _iou,
//           confThreshold: _conf,
//           classThreshold: _cls,
//         );

//         if (!mounted) return;
//         setState(() => _results = List<Map<String, dynamic>>.from(results));

//         if (kDebugMode && _results.isNotEmpty && _frameCount % 15 == 0) {
//           debugPrint('det sample: ${_results.first}');
//         }
//       } catch (e) {
//         if (kDebugMode) debugPrint('yoloOnFrame error: $e');
//       } finally {
//         _busy = false;
//       }
//     });
//   }

//   Future<void> _stopStream() async {
//     if (_controller.value.isStreamingImages) {
//       await _controller.stopImageStream();
//     }
//     setState(() {
//       _recording = false;
//       _results = const [];
//     });
//   }

//   @override
//   void dispose() {
//     _pulseCtrl.dispose();
//     _fpsTimer?.cancel();
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

//     // full-screen preview (cover)
//     final screen = MediaQuery.of(context).size;
//     final pv = _controller.value.previewSize!;
//     final screenH = math.max(screen.height, screen.width);
//     final screenW = math.min(screen.height, screen.width);
//     final prevH = math.max(pv.height, pv.width);
//     final prevW = math.min(pv.height, pv.width);
//     final screenRatio = screenH / screenW;
//     final previewRatio = prevH / prevW;

//     final bufferW = _bufferW == 0 ? prevW.toInt() : _bufferW;
//     final bufferH = _bufferH == 0 ? prevH.toInt() : _bufferH;
//     final rotationDeg = _camera.sensorOrientation;

//     final topThree = _results
//         .map((r) => _prettyLabel(r))
//         .where((s) => s.isNotEmpty)
//         .take(3)
//         .toList();

//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Text(widget.title),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//       ),
//       extendBodyBehindAppBar: true,
//       body: Stack(
//         children: [
//           // CAMERA
//           Center(
//             child: OverflowBox(
//               maxHeight:
//                   screenRatio > previewRatio ? screenH : (screenW / prevW) * prevH,
//               maxWidth:
//                   screenRatio > previewRatio ? (screenH / prevH) * prevW : screenW,
//               child: CameraPreview(_controller),
//             ),
//           ),

//           // TOP GRADIENT HUD
//           IgnorePointer(
//             child: Container(
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.center,
//                   colors: [Colors.black54, Colors.transparent],
//                 ),
//               ),
//             ),
//           ),

//           // BOXES
//           Positioned.fill(
//             child: CustomPaint(
//               painter: _BoxesPainter(
//                 results: _results,
//                 bufferW: bufferW,
//                 bufferH: bufferH,
//                 rotationDeg: rotationDeg,
//               ),
//             ),
//           ),

//           // LABEL CHIPS (top-left)
//           Positioned(
//             top: kToolbarHeight + 10,
//             left: 12,
//             child: Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: topThree
//                   .map((t) => _pill(t, Colors.white.withOpacity(.1)))
//                   .toList(),
//             ),
//           ),

//           // FPS + TORCH + SWITCH (top-right column)
//           Positioned(
//             top: kToolbarHeight + 10,
//             right: 10,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 _pill('${_fps.toStringAsFixed(1)} fps', Colors.white10),
//                 const SizedBox(height: 8),
//                 _roundIcon(
//                   icon: _torch ? Icons.flash_on : Icons.flash_off,
//                   onTap: _toggleTorch,
//                 ),
//                 const SizedBox(height: 8),
//                 _roundIcon(icon: Icons.cameraswitch, onTap: _switchCamera),
//               ],
//             ),
//           ),

//           // IDLE HINT
//           if (!_recording)
//             Positioned.fill(
//               child: IgnorePointer(
//                 child: Center(
//                   child: Container(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                     decoration: BoxDecoration(
//                       color: Colors.black54,
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: const Text(
//                       'Tip: Fill the frame with a single leaf • Hold steady • Good light',
//                       style: TextStyle(color: Colors.white, fontSize: 14),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),
//               ),
//             ),

//           // BOTTOM CONTROL SHEET
//           Positioned(
//             left: 12,
//             right: 12,
//             bottom: 110,
//             child: _QuickControls(
//               zoom: _zoom,
//               onZoomChanged: (v) async {
//                 setState(() => _zoom = v);
//                 try {
//                   await _controller.setZoomLevel(v);
//                 } catch (_) {}
//               },
//               conf: _conf,
//               iou: _iou,
//               cls: _cls,
//               onConfChanged: (v) => setState(() => _conf = v),
//               onIouChanged: (v) => setState(() => _iou = v),
//               onClsChanged: (v) => setState(() => _cls = v),
//             ),
//           ),
//         ],
//       ),

//       // PULSING RECORD / STOP
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
//       floatingActionButton: Stack(
//         alignment: Alignment.center,
//         children: [
//           if (!_recording)
//             AnimatedBuilder(
//               animation: _pulseCtrl,
//               builder: (_, __) {
//                 final t = _pulseCtrl.value;
//                 final scale = 1.0 + 0.25 * t;
//                 final op = (1.0 - t) * .6;
//                 return Transform.scale(
//                   scale: scale,
//                   child: Container(
//                     width: 86,
//                     height: 86,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: Colors.redAccent.withOpacity(op),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           FloatingActionButton.large(
//             backgroundColor: Colors.redAccent,
//             onPressed: _recording ? _stopStream : _startStream,
//             child: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _pill(String text, Color bg) => Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//         decoration: BoxDecoration(
//           color: bg,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Colors.white24),
//         ),
//         child: Text(
//           text,
//           style:
//               const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
//         ),
//       );

//   Widget _roundIcon({required IconData icon, required VoidCallback onTap}) =>
//       InkResponse(
//         onTap: onTap,
//         radius: 28,
//         child: Container(
//           width: 44,
//           height: 44,
//           decoration: BoxDecoration(
//             color: Colors.black54,
//             shape: BoxShape.circle,
//             border: Border.all(color: Colors.white24),
//           ),
//           child: Icon(icon, color: Colors.white),
//         ),
//       );

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
// }

// /// Small bottom card with zoom + thresholds
// class _QuickControls extends StatelessWidget {
//   const _QuickControls({
//     required this.zoom,
//     required this.onZoomChanged,
//     required this.conf,
//     required this.iou,
//     required this.cls,
//     required this.onConfChanged,
//     required this.onIouChanged,
//     required this.onClsChanged,
//   });

//   final double zoom;
//   final ValueChanged<double> onZoomChanged;

//   final double conf;
//   final double iou;
//   final double cls;
//   final ValueChanged<double> onConfChanged;
//   final ValueChanged<double> onIouChanged;
//   final ValueChanged<double> onClsChanged;

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       color: Colors.black54,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _sliderRow('Zoom', zoom, 1.0, 6.0, onZoomChanged),
//             const SizedBox(height: 4),
//             Row(
//               children: [
//                 Expanded(
//                   child: _miniSlider('Conf', conf, 0.05, 0.9, onConfChanged),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: _miniSlider('IOU', iou, 0.2, 0.8, onIouChanged),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: _miniSlider('Cls', cls, 0.05, 0.9, onClsChanged),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _sliderRow(String label, double value, double min, double max,
//       ValueChanged<double> onChanged) {
//     return Row(
//       children: [
//         SizedBox(width: 48, child: Text(label, style: _lbl)),
//         Expanded(
//           child: Slider(
//             value: value.clamp(min, max),
//             min: min,
//             max: max,
//             divisions: ((max - min) * 10).round(),
//             onChanged: onChanged,
//           ),
//         ),
//         SizedBox(
//           width: 48,
//           child: Text(value.toStringAsFixed(1), textAlign: TextAlign.right, style: _lbl),
//         ),
//       ],
//     );
//   }

//   Widget _miniSlider(String label, double value, double min, double max,
//       ValueChanged<double> onChanged) {
//     return Column(
//       children: [
//         Text(label, style: _lbl),
//         Slider(
//           value: value.clamp(min, max),
//           min: min,
//           max: max,
//           divisions: ((max - min) * 20).round(),
//           onChanged: onChanged,
//         ),
//       ],
//     );
//   }

//   TextStyle get _lbl =>
//       const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600);
// }

// /// Painter: robust parsing + rotation + cover-scaling + pretty pills/bar.
// class _BoxesPainter extends CustomPainter {
//   _BoxesPainter({
//     required this.results,
//     required this.bufferW,
//     required this.bufferH,
//     required this.rotationDeg,
//   });

//   final List<Map<String, dynamic>> results;
//   final int bufferW;
//   final int bufferH;
//   final int rotationDeg;

//   @override
//   void paint(Canvas canvas, Size size) {
//     // Fit = cover transform
//     final scale = math.max(size.width / bufferW, size.height / bufferH);
//     final drawW = bufferW * scale;
//     final drawH = bufferH * scale;
//     final dx = (size.width - drawW) / 2;
//     final dy = (size.height - drawH) / 2;

//     final stroke = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3
//       ..color = const Color(0xFF25D5FD);

//     for (final r in results) {
//       if (r['box'] is! List) continue;
//       final b = (r['box'] as List).map((e) => (e as num).toDouble()).toList();
//       if (b.length < 4) continue;

//       // -> corner pixels
//       double x0, y0, x1, y1;
//       double a = b[0], bb = b[1], c = b[2], d = b[3];
//       if (c > a && d > bb) {
//         x0 = a; y0 = bb; x1 = c; y1 = d; // [x1,y1,x2,y2]
//       } else {
//         x0 = a; y0 = bb; x1 = a + c; y1 = bb + d; // [x,y,w,h]
//         if (x1 <= x0 || y1 <= y0) {
//           x0 = a - c / 2.0; y0 = bb - d / 2.0; x1 = a + c / 2.0; y1 = bb + d / 2.0; // [cx,cy,w,h]
//         }
//       }
//       if (x1 <= 2 && y1 <= 2) { // normalized
//         x0 *= bufferW; x1 *= bufferW; y0 *= bufferH; y1 *= bufferH;
//       }

//       // rotation
//       double rx0, ry0, rx1, ry1;
//       switch (rotationDeg % 360) {
//         case 0:
//           rx0 = x0; ry0 = y0; rx1 = x1; ry1 = y1; break;
//         case 90:
//           rx0 = bufferH - y1; ry0 = x0; rx1 = bufferH - y0; ry1 = x1; break;
//         case 180:
//           rx0 = bufferW - x1; ry0 = bufferH - y1; rx1 = bufferW - x0; ry1 = bufferH - y0; break;
//         case 270:
//           rx0 = y0; ry0 = bufferW - x1; rx1 = y1; ry1 = bufferW - x0; break;
//         default:
//           rx0 = x0; ry0 = y0; rx1 = x1; ry1 = y1;
//       }

//       // clamp
//       rx0 = rx0.clamp(0.0, bufferW.toDouble());
//       ry0 = ry0.clamp(0.0, bufferH.toDouble());
//       rx1 = rx1.clamp(0.0, bufferW.toDouble());
//       ry1 = ry1.clamp(0.0, bufferH.toDouble());

//       // -> canvas
//       final left   = rx0 * scale + dx;
//       final top    = ry0 * scale + dy;
//       final right  = rx1 * scale + dx;
//       final bottom = ry1 * scale + dy;

//       if (right <= 0 || bottom <= 0 || left >= size.width || top >= size.height) {
//         continue;
//       }
//       final rect = Rect.fromLTRB(left, top, right, bottom);

//       // shadowed rounded stroke
//       canvas.drawRRect(
//         RRect.fromRectAndRadius(rect.inflate(1.5), const Radius.circular(10)),
//         Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 6,
//       );
//       canvas.drawRRect(
//         RRect.fromRectAndRadius(rect, const Radius.circular(10)),
//         stroke,
//       );

//       // label pill + confidence bar
//       final label = (r['tag'] ?? r['label'] ?? r['class_name'])?.toString() ?? 'obj';
//       final conf  = (r['confidence'] ?? r['score'] ?? (b.length > 4 ? b[4] : 0)) as num?;
//       final pct   = conf == null ? '' : ' ${(conf * 100).clamp(0, 100).toStringAsFixed(0)}%';
//       final text  = '$label$pct';

//       final tp = TextPainter(
//         text: TextSpan(
//           text: text,
//           style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
//         ),
//         textDirection: TextDirection.ltr,
//       )..layout(maxWidth: size.width - 16);

//       const padX = 8.0, padY = 5.0;
//       final pill = RRect.fromRectAndRadius(
//         Rect.fromLTWH(rect.left + 8, rect.top + 8, tp.width + padX * 2, tp.height + padY * 2),
//         const Radius.circular(8),
//       );
//       canvas.drawRRect(pill, Paint()..color = Colors.black.withOpacity(0.65));
//       tp.paint(canvas, Offset(pill.left + padX, pill.top + padY));

//       if (conf != null) {
//         final w = (tp.width + padX * 2) * conf.clamp(0, 1).toDouble();
//         final bar = Rect.fromLTWH(pill.left, pill.bottom + 4, w, 3.5);
//         canvas.drawRRect(
//           RRect.fromRectAndRadius(bar, const Radius.circular(2)),
//           Paint()..color = const Color(0xFF25D5FD),
//         );
//       }
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _BoxesPainter old) =>
//       old.results != results ||
//       old.bufferW != bufferW ||
//       old.bufferH != bufferH ||
//       old.rotationDeg != rotationDeg;
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
//     this.conf = 0.01,   // still used internally
//     this.iou  = 0.95,   // still used internally
//     this.cls  = 0.01,   // still used internally
//   });

//   final FlutterVision vision;
//   final String title;
//   final double conf;
//   final double iou;
//   final double cls;

//   @override
//   State<LiveDetectPage> createState() => _LiveDetectPageState();
// }

// class _LiveDetectPageState extends State<LiveDetectPage>
//     with SingleTickerProviderStateMixin {
//   late CameraController _controller;
//   late CameraDescription _camera;

//   bool _inited = false;
//   bool _busy = false;
//   bool _recording = false;
//   bool _torch = false;

//   int _bufferW = 0, _bufferH = 0;               // for scaling
//   List<Map<String, dynamic>> _results = const []; // recognitions

//   // simple FPS
//   int _frameCount = 0;
//   double _fps = 0;
//   Timer? _fpsTimer;

//   // camera/ui
//   double _zoom = 1.0;
//   late final double _conf;
//   late final double _iou;
//   late final double _cls;

//   late final AnimationController _pulseCtrl;

//   @override
//   void initState() {
//     super.initState();
//     _conf = widget.conf;
//     _iou  = widget.iou;
//     _cls  = widget.cls;

//     _pulseCtrl =
//         AnimationController(vsync: this, duration: const Duration(seconds: 1))
//           ..repeat(reverse: true);

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
//       ResolutionPreset.max,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );

//     await _controller.initialize();
//     await _controller.setFocusMode(FocusMode.auto);
//     await _controller.setExposureMode(ExposureMode.auto);
//     await _controller.setZoomLevel(_zoom);

//     _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//       setState(() {
//         _fps = _frameCount.toDouble();
//         _frameCount = 0;
//       });
//     });

//     if (!mounted) return;
//     setState(() => _inited = true);
//   }

//   Future<void> _switchCamera() async {
//     final cams = await availableCameras();
//     final idx = cams.indexOf(_camera);
//     final next = cams[(idx + 1) % cams.length];
//     _camera = next;

//     if (_controller.value.isStreamingImages) {
//       await _controller.stopImageStream();
//     }
//     await _controller.dispose();

//     _controller = CameraController(
//       _camera,
//       ResolutionPreset.max,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );
//     await _controller.initialize();
//     await _controller.setZoomLevel(_zoom);
//     await _controller.setFlashMode(FlashMode.off);
//     setState(() {});
//     if (_recording) _startStream();
//   }

//   Future<void> _toggleTorch() async {
//     try {
//       if (_torch) {
//         await _controller.setFlashMode(FlashMode.off);
//       } else {
//         await _controller.setFlashMode(FlashMode.torch);
//       }
//       setState(() => _torch = !_torch);
//     } catch (_) {}
//   }

//   Future<void> _startStream() async {
//     if (_controller.value.isStreamingImages) return;
//     setState(() => _recording = true);

//     await _controller.startImageStream((CameraImage img) async {
//       _frameCount++;
//       if (_busy) return;
//       _busy = true;

//       _bufferW = img.width;
//       _bufferH = img.height;

//       try {
//         final results = await widget.vision.yoloOnFrame(
//           bytesList: img.planes.map((p) => p.bytes).toList(),
//           imageWidth: img.width,
//           imageHeight: img.height,
//           iouThreshold: _iou,
//           confThreshold: _conf,
//           classThreshold: _cls,
//         );

//         if (!mounted) return;
//         setState(() => _results = List<Map<String, dynamic>>.from(results));

//         if (kDebugMode && _results.isNotEmpty && _frameCount % 15 == 0) {
//           debugPrint('det sample: ${_results.first}');
//         }
//       } catch (e) {
//         if (kDebugMode) debugPrint('yoloOnFrame error: $e');
//       } finally {
//         _busy = false;
//       }
//     });
//   }

//   Future<void> _stopStream() async {
//     if (_controller.value.isStreamingImages) {
//       await _controller.stopImageStream();
//     }
//     setState(() {
//       _recording = false;
//       _results = const [];
//     });
//   }

//   @override
//   void dispose() {
//     _pulseCtrl.dispose();
//     _fpsTimer?.cancel();
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

//     // full-screen preview (cover)
//     final screen = MediaQuery.of(context).size;
//     final pv = _controller.value.previewSize!;
//     final screenH = math.max(screen.height, screen.width);
//     final screenW = math.min(screen.height, screen.width);
//     final prevH = math.max(pv.height, pv.width);
//     final prevW = math.min(pv.height, pv.width);
//     final screenRatio = screenH / screenW;
//     final previewRatio = prevH / prevW;

//     final bufferW = _bufferW == 0 ? prevW.toInt() : _bufferW;
//     final bufferH = _bufferH == 0 ? prevH.toInt() : _bufferH;
//     final rotationDeg = _camera.sensorOrientation;

//     final topThree = _results
//         .map((r) => _labelOnly(r)) // no confidence text
//         .where((s) => s.isNotEmpty)
//         .take(3)
//         .toList();

//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Text(widget.title),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//       ),
//       extendBodyBehindAppBar: true,
//       body: Stack(
//         children: [
//           // CAMERA
//           Center(
//             child: OverflowBox(
//               maxHeight:
//                   screenRatio > previewRatio ? screenH : (screenW / prevW) * prevH,
//               maxWidth:
//                   screenRatio > previewRatio ? (screenH / prevH) * prevW : screenW,
//               child: CameraPreview(_controller),
//             ),
//           ),

//           // TOP GRADIENT HUD
//           IgnorePointer(
//             child: Container(
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.center,
//                   colors: [Colors.black54, Colors.transparent],
//                 ),
//               ),
//             ),
//           ),

//           // BOXES (no confidence bar drawn)
//           Positioned.fill(
//             child: CustomPaint(
//               painter: _BoxesPainter(
//                 results: _results,
//                 bufferW: bufferW,
//                 bufferH: bufferH,
//                 rotationDeg: rotationDeg,
//               ),
//             ),
//           ),

//           // LABEL CHIPS (top-left) — only names
//           Positioned(
//             top: kToolbarHeight + 10,
//             left: 12,
//             child: Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: topThree
//                   .map((t) => _pill(t, Colors.white.withOpacity(.1)))
//                   .toList(),
//             ),
//           ),

//           // FPS + TORCH + SWITCH (top-right column)
//           Positioned(
//             top: kToolbarHeight + 10,
//             right: 10,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 _pill('${_fps.toStringAsFixed(1)} fps', Colors.white10),
//                 const SizedBox(height: 8),
//                 _roundIcon(
//                   icon: _torch ? Icons.flash_on : Icons.flash_off,
//                   onTap: _toggleTorch,
//                 ),
//                 const SizedBox(height: 8),
//                 _roundIcon(icon: Icons.cameraswitch, onTap: _switchCamera),
//               ],
//             ),
//           ),

//           // IDLE HINT
//           if (!_recording)
//             Positioned.fill(
//               child: IgnorePointer(
//                 child: Center(
//                   child: Container(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                     decoration: BoxDecoration(
//                       color: Colors.black54,
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: const Text(
//                       'Tip: Fill the frame with a single leaf • Hold steady • Good light',
//                       style: TextStyle(color: Colors.white, fontSize: 14),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),

//       // PULSING RECORD / STOP
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
//       floatingActionButton: Stack(
//         alignment: Alignment.center,
//         children: [
//           if (!_recording)
//             AnimatedBuilder(
//               animation: _pulseCtrl,
//               builder: (_, __) {
//                 final t = _pulseCtrl.value;
//                 final scale = 1.0 + 0.25 * t;
//                 final op = (1.0 - t) * .6;
//                 return Transform.scale(
//                   scale: scale,
//                   child: Container(
//                     width: 86,
//                     height: 86,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: Colors.redAccent.withOpacity(op),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           FloatingActionButton.large(
//             backgroundColor: Colors.redAccent,
//             onPressed: _recording ? _stopStream : _startStream,
//             child: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _pill(String text, Color bg) => Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//         decoration: BoxDecoration(
//           color: bg,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Colors.white24),
//         ),
//         child: Text(
//           text,
//           style:
//               const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
//         ),
//       );

//   Widget _roundIcon({required IconData icon, required VoidCallback onTap}) =>
//       InkResponse(
//         onTap: onTap,
//         radius: 28,
//         child: Container(
//           width: 44,
//           height: 44,
//           decoration: BoxDecoration(
//             color: Colors.black54,
//             shape: BoxShape.circle,
//             border: Border.all(color: Colors.white24),
//           ),
//           child: Icon(icon, color: Colors.white),
//         ),
//       );

//   String _labelOnly(Map r) {
//     final tag = r['tag'] ?? r['label'] ?? r['class_name'];
//     return tag?.toString() ?? '';
//   }
// }

// /// Painter: robust parsing (List/Map) + rotation + cover-scaling.
// /// NO confidence bar; label text shows only the class name.
// class _BoxesPainter extends CustomPainter {
//   _BoxesPainter({
//     required this.results,
//     required this.bufferW,
//     required this.bufferH,
//     required this.rotationDeg,
//   });

//   final List<Map<String, dynamic>> results;
//   final int bufferW;
//   final int bufferH;
//   final int rotationDeg;

//   static ({double x0, double y0, double x1, double y1}) _parseBox(
//     dynamic box,
//     int bufW,
//     int bufH,
//   ) {
//     double x0, y0, x1, y1;

//     if (box is List && box.length >= 4) {
//       double a = (box[0] as num).toDouble();
//       double b = (box[1] as num).toDouble();
//       double c = (box[2] as num).toDouble();
//       double d = (box[3] as num).toDouble();

//       if (c > a && d > b) {
//         x0 = a; y0 = b; x1 = c; y1 = d;                // [x1,y1,x2,y2]
//       } else {
//         x0 = a; y0 = b; x1 = a + c; y1 = b + d;        // [x,y,w,h]
//         if (x1 <= x0 || y1 <= y0) {
//           x0 = a - c / 2.0; y0 = b - d / 2.0;          // [cx,cy,w,h]
//           x1 = a + c / 2.0; y1 = b + d / 2.0;
//         }
//       }

//       if (x1 <= 2 && y1 <= 2) { // normalized
//         x0 *= bufW; x1 *= bufW; y0 *= bufH; y1 *= bufH;
//       }
//       return (x0: x0, y0: y0, x1: x1, y1: y1);
//     }

//     if (box is Map) {
//       double? left = (box['left'] ?? box['x'])?.toDouble();
//       double? top = (box['top'] ?? box['y'])?.toDouble();
//       double? right = (box['right'])?.toDouble();
//       double? bottom = (box['bottom'])?.toDouble();
//       double? w = (box['w'] ?? box['width'])?.toDouble();
//       double? h = (box['h'] ?? box['height'])?.toDouble();
//       double? cx = (box['cx'])?.toDouble();
//       double? cy = (box['cy'])?.toDouble();

//       if (left != null && top != null && right != null && bottom != null) {
//         x0 = left; y0 = top; x1 = right; y1 = bottom;
//       } else if (left != null && top != null && w != null && h != null) {
//         x0 = left; y0 = top; x1 = left + w; y1 = top + h;
//       } else if (cx != null && cy != null && w != null && h != null) {
//         x0 = cx - w / 2; y0 = cy - h / 2; x1 = cx + w / 2; y1 = cy + h / 2;
//       } else {
//         return (x0: 0, y0: 0, x1: 0, y1: 0);
//       }

//       if (x1 <= 2 && y1 <= 2) { // normalized
//         x0 *= bufW; x1 *= bufW; y0 *= bufH; y1 *= bufH;
//       }
//       return (x0: x0, y0: y0, x1: y1 == 0 ? 0 : x1, y1: y1);
//     }

//     return (x0: 0, y0: 0, x1: 0, y1: 0);
//   }

//   @override
//   void paint(Canvas canvas, Size size) {
//     // BoxFit.cover transform buffer->canvas
//     final scale = math.max(size.width / bufferW, size.height / bufferH);
//     final drawW = bufferW * scale;
//     final drawH = bufferH * scale;
//     final dx = (size.width - drawW) / 2;
//     final dy = (size.height - drawH) / 2;

//     final stroke = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3
//       ..color = const Color(0xFF25D5FD);

//     final shadow = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 6
//       ..color = Colors.black38;

//     for (final r in results) {
//       final rawBox = r['box'];
//       if (rawBox == null) continue;

//       final p = _parseBox(rawBox, bufferW, bufferH);
//       double x0 = p.x0, y0 = p.y0, x1 = p.x1, y1 = p.y1;
//       if ((x1 - x0) <= 1 || (y1 - y0) <= 1) continue;

//       // Apply sensor rotation to get upright preview pixels
//       double rx0, ry0, rx1, ry1;
//       switch (rotationDeg % 360) {
//         case 0:
//           rx0 = x0; ry0 = y0; rx1 = x1; ry1 = y1; break;
//         case 90:
//           rx0 = bufferH - y1; ry0 = x0; rx1 = bufferH - y0; ry1 = x1; break;
//         case 180:
//           rx0 = bufferW - x1; ry0 = bufferH - y1; rx1 = bufferW - x0; ry1 = bufferH - y0; break;
//         case 270:
//           rx0 = y0; ry0 = bufferW - x1; rx1 = y1; ry1 = bufferW - x0; break;
//         default:
//           rx0 = x0; ry0 = y0; rx1 = x1; ry1 = y1;
//       }

//       // Clamp
//       rx0 = rx0.clamp(0.0, bufferW.toDouble());
//       ry0 = ry0.clamp(0.0, bufferH.toDouble());
//       rx1 = rx1.clamp(0.0, bufferW.toDouble());
//       ry1 = ry1.clamp(0.0, bufferH.toDouble());

//       // Scale to canvas (cover)
//       final left   = rx0 * scale + dx;
//       final top    = ry0 * scale + dy;
//       final right  = rx1 * scale + dx;
//       final bottom = ry1 * scale + dy;

//       if (right <= 0 || bottom <= 0 || left >= size.width || top >= size.height) {
//         continue;
//       }

//       final rect = Rect.fromLTRB(left, top, right, bottom);

//       // Draw box with slight outer shadow
//       final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
//       canvas.drawRRect(rr.inflate(1.5), shadow);
//       canvas.drawRRect(rr, stroke);

//       // Label pill (name only)
//       final label = (r['tag'] ?? r['label'] ?? r['class_name'])?.toString() ?? 'obj';

//       final tp = TextPainter(
//         text: TextSpan(
//           text: label,
//           style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
//         ),
//         textDirection: TextDirection.ltr,
//       )..layout(maxWidth: size.width - 16);

//       const padX = 8.0, padY = 5.0;
//       final pill = RRect.fromRectAndRadius(
//         Rect.fromLTWH(rect.left + 8, rect.top + 8, tp.width + padX * 2, tp.height + padY * 2),
//         const Radius.circular(8),
//       );
//       canvas.drawRRect(pill, Paint()..color = Colors.black.withOpacity(0.65));
//       tp.paint(canvas, Offset(pill.left + padX, pill.top + padY));
//       // (no confidence bar)
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _BoxesPainter old) =>
//       old.results != results ||
//       old.bufferW != bufferW ||
//       old.bufferH != bufferH ||
//       old.rotationDeg != rotationDeg;
// }


// lib/live_detect_page.dart
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
//     // thresholds are used internally only (no UI sliders)
//     this.conf = 0.01,
//     this.iou = 0.45,
//     this.cls = 0.03,
//   });

//   final FlutterVision vision;
//   final String title;
//   final double conf;
//   final double iou;
//   final double cls;

//   @override
//   State<LiveDetectPage> createState() => _LiveDetectPageState();
// }

// class _LiveDetectPageState extends State<LiveDetectPage>
//     with SingleTickerProviderStateMixin {
//   late CameraController _controller;
//   late CameraDescription _camera;

//   bool _inited = false;
//   bool _busy = false;
//   bool _recording = false;
//   bool _torch = false;

//   // latest camera buffer size (used to map boxes)
//   int _bufferW = 0, _bufferH = 0;

//   // latest recognitions
//   List<Map<String, dynamic>> _results = const [];

//   // fps meter
//   int _frameCount = 0;
//   double _fps = 0;
//   Timer? _fpsTimer;

//   // camera
//   double _zoom = 1.0;
//   late final double _conf;
//   late final double _iou;
//   late final double _cls;

//   late final AnimationController _pulseCtrl;

//   @override
//   void initState() {
//     super.initState();
//     _conf = widget.conf;
//     _iou = widget.iou;
//     _cls = widget.cls;

//     _pulseCtrl =
//         AnimationController(vsync: this, duration: const Duration(seconds: 1))
//           ..repeat(reverse: true);

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
//       ResolutionPreset.max,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );

//     await _controller.initialize();
//     await _controller.setFocusMode(FocusMode.auto);
//     await _controller.setExposureMode(ExposureMode.auto);
//     await _controller.setZoomLevel(_zoom);

//     _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//       if (!mounted) return;
//       setState(() {
//         _fps = _frameCount.toDouble();
//         _frameCount = 0;
//       });
//     });

//     if (!mounted) return;
//     setState(() => _inited = true);
//   }

//   Future<void> _switchCamera() async {
//     final cams = await availableCameras();
//     final idx = cams.indexOf(_camera);
//     final next = cams[(idx + 1) % cams.length];
//     _camera = next;

//     if (_controller.value.isStreamingImages) {
//       await _controller.stopImageStream();
//     }
//     await _controller.dispose();

//     _controller = CameraController(
//       _camera,
//       ResolutionPreset.max,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );
//     await _controller.initialize();
//     await _controller.setZoomLevel(_zoom);
//     await _controller.setFlashMode(FlashMode.off);

//     if (!mounted) return;
//     setState(() {});
//     if (_recording) _startStream();
//   }

//   Future<void> _toggleTorch() async {
//     try {
//       if (_torch) {
//         await _controller.setFlashMode(FlashMode.off);
//       } else {
//         await _controller.setFlashMode(FlashMode.torch);
//       }
//       if (!mounted) return;
//       setState(() => _torch = !_torch);
//     } catch (_) {}
//   }

//   Future<void> _startStream() async {
//     if (_controller.value.isStreamingImages) return;
//     setState(() => _recording = true);

//     await _controller.startImageStream((CameraImage img) async {
//       _frameCount++;
//       if (_busy) return;
//       _busy = true;

//       _bufferW = img.width;
//       _bufferH = img.height;

//       try {
//         final results = await widget.vision.yoloOnFrame(
//           bytesList: img.planes.map((p) => p.bytes).toList(),
//           imageWidth: img.width,
//           imageHeight: img.height,
//           iouThreshold: _iou,
//           confThreshold: _conf,
//           classThreshold: _cls,
//         );

//         if (!mounted) return;
//         setState(() => _results = List<Map<String, dynamic>>.from(results));

//         if (kDebugMode && _results.isNotEmpty && _frameCount % 15 == 0) {
//           debugPrint('det sample: ${_results.first}');
//         }
//       } catch (e) {
//         if (kDebugMode) debugPrint('yoloOnFrame error: $e');
//       } finally {
//         _busy = false;
//       }
//     });
//   }

//   Future<void> _stopStream() async {
//     if (_controller.value.isStreamingImages) {
//       await _controller.stopImageStream();
//     }
//     if (!mounted) return;
//     setState(() {
//       _recording = false;
//       _results = const [];
//     });
//   }

//   @override
//   void dispose() {
//     _pulseCtrl.dispose();
//     _fpsTimer?.cancel();
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

//     // full-screen preview (cover)
//     final screen = MediaQuery.of(context).size;
//     final pv = _controller.value.previewSize!;
//     final screenH = math.max(screen.height, screen.width);
//     final screenW = math.min(screen.height, screen.width);
//     final prevH = math.max(pv.height, pv.width);
//     final prevW = math.min(pv.height, pv.width);
//     final screenRatio = screenH / screenW;
//     final previewRatio = prevH / prevW;

//     final bufW = _bufferW == 0 ? prevW.toInt() : _bufferW;
//     final bufH = _bufferH == 0 ? prevH.toInt() : _bufferH;
//     final rotationDeg = _camera.sensorOrientation;

//     final topThree = _results
//         .map((r) => (r['tag'] ?? r['label'] ?? r['class_name'])?.toString() ?? '')
//         .where((s) => s.isNotEmpty)
//         .take(3)
//         .toList();

//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Text(widget.title),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//       ),
//       extendBodyBehindAppBar: true,
//       body: Stack(
//         children: [
//           // CAMERA
//           Center(
//             child: OverflowBox(
//               maxHeight:
//                   screenRatio > previewRatio ? screenH : (screenW / prevW) * prevH,
//               maxWidth:
//                   screenRatio > previewRatio ? (screenH / prevH) * prevW : screenW,
//               child: CameraPreview(_controller),
//             ),
//           ),

//           // subtle top gradient
//           IgnorePointer(
//             child: Container(
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.center,
//                   colors: [Colors.black54, Colors.transparent],
//                 ),
//               ),
//             ),
//           ),

//           // BOXES
//           Positioned.fill(
//             child: RepaintBoundary(
//               child: CustomPaint(
//                 isComplex: true,
//                 willChange: true,
//                 painter: _BoxesPainter(
//                   results: _results,
//                   bufferW: bufW,
//                   bufferH: bufH,
//                   rotationDeg: rotationDeg,
//                 ),
//               ),
//             ),
//           ),

//           // LABEL CHIPS (top-left) — names only
//           Positioned(
//             top: kToolbarHeight + 10,
//             left: 12,
//             child: Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: topThree
//                   .map((t) => _pill(t, Colors.white.withOpacity(.1)))
//                   .toList(),
//             ),
//           ),

//           // FPS + TORCH + SWITCH (top-right)
//           Positioned(
//             top: kToolbarHeight + 10,
//             right: 10,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 _pill('${_fps.toStringAsFixed(1)} fps', Colors.white10),
//                 const SizedBox(height: 8),
//                 _roundIcon(
//                   icon: _torch ? Icons.flash_on : Icons.flash_off,
//                   onTap: _toggleTorch,
//                 ),
//                 const SizedBox(height: 8),
//                 _roundIcon(icon: Icons.cameraswitch, onTap: _switchCamera),
//               ],
//             ),
//           ),

//           // IDLE HINT
//           if (!_recording)
//             Positioned.fill(
//               child: IgnorePointer(
//                 child: Center(
//                   child: Container(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                     decoration: BoxDecoration(
//                       color: Colors.black54,
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: const Text(
//                       'Tip: Fill the frame with a single leaf • Hold steady • Good light',
//                       style: TextStyle(color: Colors.white, fontSize: 14),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),
//               ),
//             ),

//           // ZOOM CONTROL (bottom center)
//           Positioned(
//             left: 16,
//             right: 16,
//             bottom: 120,
//             child: _ZoomControl(
//               zoom: _zoom,
//               onZoomChanged: (v) async {
//                 setState(() => _zoom = v);
//                 try {
//                   await _controller.setZoomLevel(v);
//                 } catch (_) {}
//               },
//             ),
//           ),
//         ],
//       ),

//       // RECORD / STOP (pulsing)
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
//       floatingActionButton: Stack(
//         alignment: Alignment.center,
//         children: [
//           if (!_recording)
//             AnimatedBuilder(
//               animation: _pulseCtrl,
//               builder: (_, __) {
//                 final t = _pulseCtrl.value;
//                 final scale = 1.0 + 0.25 * t;
//                 final op = (1.0 - t) * .6;
//                 return Transform.scale(
//                   scale: scale,
//                   child: Container(
//                     width: 86,
//                     height: 86,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: Colors.redAccent.withOpacity(op),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           FloatingActionButton.large(
//             backgroundColor: Colors.redAccent,
//             onPressed: _recording ? _stopStream : _startStream,
//             child: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _pill(String text, Color bg) => Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//         decoration: BoxDecoration(
//           color: bg,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Colors.white24),
//         ),
//         child: Text(
//           text,
//           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
//         ),
//       );

//   Widget _roundIcon({required IconData icon, required VoidCallback onTap}) =>
//       InkResponse(
//         onTap: onTap,
//         radius: 28,
//         child: Container(
//           width: 44,
//           height: 44,
//           decoration: BoxDecoration(
//             color: Colors.black54,
//             shape: BoxShape.circle,
//             border: Border.all(color: Colors.white24),
//           ),
//           child: Icon(icon, color: Colors.white),
//         ),
//       );
// }

// /// Zoom-only control card
// class _ZoomControl extends StatelessWidget {
//   const _ZoomControl({required this.zoom, required this.onZoomChanged});

//   final double zoom;
//   final ValueChanged<double> onZoomChanged;

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       color: Colors.black54,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
//         child: Row(
//           children: [
//             const SizedBox(
//               width: 48,
//               child: Text('Zoom',
//                   style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
//             ),
//             Expanded(
//               child: Slider(
//                 value: zoom.clamp(1.0, 6.0),
//                 min: 1.0,
//                 max: 6.0,
//                 divisions: 50,
//                 onChanged: onZoomChanged,
//               ),
//             ),
//             SizedBox(
//               width: 48,
//               child: Text(
//                 zoom.toStringAsFixed(1),
//                 textAlign: TextAlign.right,
//                 style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// Painter: robust parsing + rotation + BoxFit.cover scaling.
// /// Labels show class name only.
// class _BoxesPainter extends CustomPainter {
//   _BoxesPainter({
//     required this.results,
//     required this.bufferW,
//     required this.bufferH,
//     required this.rotationDeg,
//   });

//   final List<Map<String, dynamic>> results;
//   final int bufferW;
//   final int bufferH;
//   final int rotationDeg;

//   // Accepts [x1,y1,x2,y2], [x,y,w,h], [cx,cy,w,h], normalized or pixel.
//   static ({double x0, double y0, double x1, double y1}) _parseBox(
//     dynamic box,
//     int bufW,
//     int bufH,
//   ) {
//     double x0, y0, x1, y1;

//     if (box is List && box.length >= 4) {
//       double a = (box[0] as num).toDouble();
//       double b = (box[1] as num).toDouble();
//       double c = (box[2] as num).toDouble();
//       double d = (box[3] as num).toDouble();

//       if (c > a && d > b) {
//         // [x1,y1,x2,y2]
//         x0 = a; y0 = b; x1 = c; y1 = d;
//       } else {
//         // [x,y,w,h] or [cx,cy,w,h]
//         x0 = a; y0 = b; x1 = a + c; y1 = b + d;
//         if (x1 <= x0 || y1 <= y0) {
//           // [cx,cy,w,h]
//           x0 = a - c / 2.0; y0 = b - d / 2.0;
//           x1 = a + c / 2.0; y1 = b + d / 2.0;
//         }
//       }

//       if (x1 <= 2 && y1 <= 2) { // normalized
//         x0 *= bufW; x1 *= bufW; y0 *= bufH; y1 *= bufH;
//       }
//       return (x0: x0, y0: y0, x1: x1, y1: y1);
//     }

//     if (box is Map) {
//       double? left = (box['left'] ?? box['x'])?.toDouble();
//       double? top = (box['top'] ?? box['y'])?.toDouble();
//       double? right = (box['right'])?.toDouble();
//       double? bottom = (box['bottom'])?.toDouble();
//       double? w = (box['w'] ?? box['width'])?.toDouble();
//       double? h = (box['h'] ?? box['height'])?.toDouble();
//       double? cx = (box['cx'])?.toDouble();
//       double? cy = (box['cy'])?.toDouble();

//       if (left != null && top != null && right != null && bottom != null) {
//         x0 = left; y0 = top; x1 = right; y1 = bottom;
//       } else if (left != null && top != null && w != null && h != null) {
//         x0 = left; y0 = top; x1 = left + w; y1 = top + h;
//       } else if (cx != null && cy != null && w != null && h != null) {
//         x0 = cx - w / 2; y0 = cy - h / 2; x1 = cx + w / 2; y1 = cy + h / 2;
//       } else {
//         return (x0: 0, y0: 0, x1: 0, y1: 0);
//       }

//       if (x1 <= 2 && y1 <= 2) { // normalized
//         x0 *= bufW; x1 *= bufW; y0 *= bufH; y1 *= bufH;
//       }
//       return (x0: x0, y0: y0, x1: x1, y1: y1);
//     }

//     return (x0: 0, y0: 0, x1: 0, y1: 0);
//   }

//   @override
//   void paint(Canvas canvas, Size size) {
//     if (bufferW == 0 || bufferH == 0) return;

//     // BoxFit.cover transform (buffer -> canvas)
//     final scale = math.max(size.width / bufferW, size.height / bufferH);
//     final drawW = bufferW * scale;
//     final drawH = bufferH * scale;
//     final dx = (size.width - drawW) / 2;
//     final dy = (size.height - drawH) / 2;

//     final stroke = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3
//       ..color = const Color(0xFF25D5FD);

//     final shadow = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 6
//       ..color = Colors.black38;

//     for (final r in results) {
//       final rawBox = r['box'];
//       if (rawBox == null) continue;

//       final p = _parseBox(rawBox, bufferW, bufferH);
//       double x0 = p.x0, y0 = p.y0, x1 = p.x1, y1 = p.y1;
//       if ((x1 - x0) <= 1 || (y1 - y0) <= 1) continue;

//       // rotate from sensor to upright buffer coords
//       double rx0, ry0, rx1, ry1;
//       switch (rotationDeg % 360) {
//         case 0:   rx0 = x0; ry0 = y0; rx1 = x1; ry1 = y1; break;
//         case 90:  rx0 = bufferH - y1; ry0 = x0; rx1 = bufferH - y0; ry1 = x1; break;
//         case 180: rx0 = bufferW - x1; ry0 = bufferH - y1;
//                   rx1 = bufferW - x0; ry1 = bufferH - y0; break;
//         case 270: rx0 = y0; ry0 = bufferW - x1; rx1 = y1; ry1 = bufferW - x0; break;
//         default:  rx0 = x0; ry0 = y0; rx1 = x1; ry1 = y1;
//       }

//       // clamp
//       rx0 = rx0.clamp(0.0, bufferW.toDouble());
//       ry0 = ry0.clamp(0.0, bufferH.toDouble());
//       rx1 = rx1.clamp(0.0, bufferW.toDouble());
//       ry1 = ry1.clamp(0.0, bufferH.toDouble());

//       // map to canvas
//       final left   = rx0 * scale + dx;
//       final top    = ry0 * scale + dy;
//       final right  = rx1 * scale + dx;
//       final bottom = ry1 * scale + dy;

//       if (right <= 0 || bottom <= 0 || left >= size.width || top >= size.height) {
//         continue;
//       }

//       final rect = Rect.fromLTRB(left, top, right, bottom);
//       final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));

//       // outline + subtle outer shadow
//       canvas.drawRRect(rr.inflate(1.5), shadow);
//       canvas.drawRRect(rr, stroke);

//       // label chip (name only)
//       final label =
//           (r['tag'] ?? r['label'] ?? r['class_name'])?.toString() ?? 'obj';

//       final tp = TextPainter(
//         text: TextSpan(
//           text: label,
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 12,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//         textDirection: TextDirection.ltr,
//       )..layout(maxWidth: size.width - 16);

//       const padX = 8.0, padY = 5.0;
//       final pill = RRect.fromRectAndRadius(
//         Rect.fromLTWH(
//           rect.left + 8,
//           rect.top + 8,
//           tp.width + padX * 2,
//           tp.height + padY * 2,
//         ),
//         const Radius.circular(8),
//       );
//       canvas.drawRRect(pill, Paint()..color = Colors.black.withOpacity(0.65));
//       tp.paint(canvas, Offset(pill.left + padX, pill.top + padY));
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _BoxesPainter old) =>
//       old.results != results ||
//       old.bufferW != bufferW ||
//       old.bufferH != bufferH ||
//       old.rotationDeg != rotationDeg;
// }



// // lib/live_detect_page.dart
// import 'dart:async';
// import 'dart:math' as math;
// import 'package:camera/camera.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_vision/flutter_vision.dart';
 


// class LiveDetectPage extends StatefulWidget {
//   const LiveDetectPage({
//     super.key,
//     required this.vision,
//     this.title = 'Live Detection',
//     this.conf = 0.01,
//     this.iou  = 0.45,
//     this.cls  = 0.03,
//   });

//   final FlutterVision vision;
//   final String title;
//   final double conf;
//   final double iou;
//   final double cls;

//   @override
//   State<LiveDetectPage> createState() => _LiveDetectPageState();
// }

// class _LiveDetectPageState extends State<LiveDetectPage>
//     with SingleTickerProviderStateMixin {
//   late CameraController _controller;
//   late CameraDescription _camera;

//   bool _inited = false;
//   bool _busy = false;
//   bool _recording = false;
//   bool _torch = false;

//   // most-recent YUV buffer size (for box mapping)
//   int _bufferW = 0, _bufferH = 0;

//   // latest accepted results
//   List<Map<String, dynamic>> _results = const [];

//   // fps
//   int _frameCount = 0;
//   double _fps = 0;
//   Timer? _fpsTimer;

//   // zoom + thresholds (internal only)
//   double _zoom = 1.0;
//   late final double _conf, _iou, _cls;

//   // pulse
//   late final AnimationController _pulseCtrl;

//   // latency guards
//   final int _processEveryN = 5; // skip some frames to reduce lag (1 = process all)
//   int _seenFrames = 0;
//   int _seqCounter = 0;          // increments per submitted frame
//   int _latestAcceptedSeq = -1;  // only draw if seq >= this

//   @override
//   void initState() {
//     super.initState();
//     _conf = widget.conf;
//     _iou  = widget.iou;
//     _cls  = widget.cls;

//     _pulseCtrl =
//         AnimationController(vsync: this, duration: const Duration(seconds: 1))
//           ..repeat(reverse: true);

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
//       ResolutionPreset.max,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );

//     await _controller.initialize();
//     await _controller.setFocusMode(FocusMode.auto);
//     await _controller.setExposureMode(ExposureMode.auto);
//     await _controller.setZoomLevel(_zoom);

//     _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//       if (!mounted) return;
//       setState(() { _fps = _frameCount.toDouble(); _frameCount = 0; });
//     });

//     if (!mounted) return;
//     setState(() => _inited = true);
//   }

//   Future<void> _switchCamera() async {
//     final cams = await availableCameras();
//     final idx = cams.indexOf(_camera);
//     _camera = cams[(idx + 1) % cams.length];

//     if (_controller.value.isStreamingImages) {
//       await _controller.stopImageStream();
//     }
//     await _controller.dispose();

//     _controller = CameraController(
//       _camera,
//       ResolutionPreset.max,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );
//     await _controller.initialize();
//     await _controller.setZoomLevel(_zoom);
//     await _controller.setFlashMode(FlashMode.off);

//     if (!mounted) return;
//     setState(() {});
//     if (_recording) _startStream();
//   }

//   Future<void> _toggleTorch() async {
//     try {
//       await _controller.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
//       if (!mounted) return;
//       setState(() => _torch = !_torch);
//     } catch (_) {}
//   }

//   // Rotation to align sensor buffer -> upright preview
//   int _rotationForPreview() {
//     final sensor = _camera.sensorOrientation; // 0/90/180/270
//     final o = _controller.value.deviceOrientation;
//     switch (o) {
//       case DeviceOrientation.portraitUp:    return sensor % 360;
//       case DeviceOrientation.landscapeLeft: return (sensor + 270) % 360;
//       case DeviceOrientation.landscapeRight:return (sensor + 90)  % 360;
//       case DeviceOrientation.portraitDown:  return (sensor + 180) % 360;
//       default: return sensor % 360;
//     }
//   }

//   bool get _isFront => _camera.lensDirection == CameraLensDirection.front;

//   Future<void> _startStream() async {
//     if (_controller.value.isStreamingImages) return;
//     setState(() => _recording = true);

//     await _controller.startImageStream((CameraImage img) async {
//       _frameCount++;
//       _seenFrames++;
//       if ((_seenFrames % _processEveryN) != 0) return; // frame skipping

//       if (_busy) return;
//       _busy = true;

//       final seq = ++_seqCounter; // id for this inference

//       _bufferW = img.width;
//       _bufferH = img.height;

//       try {
//         final results = await widget.vision.yoloOnFrame(
//           bytesList: img.planes.map((p) => p.bytes).toList(),
//           imageWidth: img.width,
//           imageHeight: img.height,
//           iouThreshold: _iou,
//           confThreshold: _conf,
//           classThreshold: _cls,
//         );

//         // Drop late results (if a newer inference already finished)
//         if (seq < _latestAcceptedSeq) return;

//         if (!mounted) return;
//         _latestAcceptedSeq = seq;
//         setState(() => _results = List<Map<String, dynamic>>.from(results));
//       } catch (e) {
//         if (kDebugMode) debugPrint('yoloOnFrame error: $e');
//       } finally {
//         _busy = false;
//       }
//     });
//   }

//   Future<void> _stopStream() async {
//     if (_controller.value.isStreamingImages) {
//       await _controller.stopImageStream();
//     }
//     if (!mounted) return;
//     setState(() {
//       _recording = false;
//       _results = const [];
//     });
//   }

//   @override
//   void dispose() {
//     _pulseCtrl.dispose();
//     _fpsTimer?.cancel();
//     () async {
//       try { if (_controller.value.isStreamingImages) await _controller.stopImageStream(); } catch (_) {}
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

//     // preview sizing (cover)
//     final screen = MediaQuery.of(context).size;
//     final pv = _controller.value.previewSize!;
//     final screenH = math.max(screen.height, screen.width);
//     final screenW = math.min(screen.height, screen.width);
//     final prevH = math.max(pv.height, pv.width);
//     final prevW = math.min(pv.height, pv.width);
//     final screenRatio = screenH / screenW;
//     final previewRatio = prevH / prevW;

//     final bufW = _bufferW == 0 ? prevW.toInt() : _bufferW;
//     final bufH = _bufferH == 0 ? prevH.toInt() : _bufferH;

//     final rotationDeg = _rotationForPreview(); // ✅ device+sensor
//     final mirror = _isFront;                   // ✅ mirror front camera

//     final topThree = _results
//         .map((r) => (r['tag'] ?? r['label'] ?? r['class_name'])?.toString() ?? '')
//         .where((s) => s.isNotEmpty)
//         .take(3)
//         .toList();

//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Text(widget.title),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//       ),
//       extendBodyBehindAppBar: true,
//       body: Stack(
//         children: [
//           // CAMERA
//           Center(
//             child: OverflowBox(
//               maxHeight:
//                   screenRatio > previewRatio ? screenH : (screenW / prevW) * prevH,
//               maxWidth:
//                   screenRatio > previewRatio ? (screenH / prevH) * prevW : screenW,
//               child: CameraPreview(_controller),
//             ),
//           ),

//           // subtle top gradient
//           IgnorePointer(
//             child: Container(
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.center,
//                   colors: [Colors.black54, Colors.transparent],
//                 ),
//               ),
//             ),
//           ),

//           // BOXES
//           Positioned.fill(
//             child: RepaintBoundary(
//               child: CustomPaint(
//                 isComplex: true,
//                 willChange: true,
//                 painter: _BoxesPainter(
//                   results: _results,
//                   bufferW: bufW,
//                   bufferH: bufH,
//                   rotationDeg: rotationDeg,
//                   mirror: mirror,
//                 ),
//               ),
//             ),
//           ),

//           // LABEL CHIPS (top-left)
//           Positioned(
//             top: kToolbarHeight + 10,
//             left: 12,
//             child: Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: topThree
//                   .map((t) => _pill(t, Colors.white.withOpacity(.1)))
//                   .toList(),
//             ),
//           ),

//           // FPS + TORCH + SWITCH (top-right)
//           Positioned(
//             top: kToolbarHeight + 10,
//             right: 10,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 _pill('${_fps.toStringAsFixed(1)} fps', Colors.white10),
//                 const SizedBox(height: 8),
//                 _roundIcon(
//                   icon: _torch ? Icons.flash_on : Icons.flash_off,
//                   onTap: _toggleTorch,
//                 ),
//                 const SizedBox(height: 8),
//                 _roundIcon(icon: Icons.cameraswitch, onTap: _switchCamera),
//               ],
//             ),
//           ),

//           // IDLE HINT
//           if (!_recording)
//             Positioned.fill(
//               child: IgnorePointer(
//                 child: Center(
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                     decoration: BoxDecoration(
//                       color: Colors.black54,
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: const Text(
//                       'Tip: Fill the frame with a single leaf • Hold steady • Good light',
//                       style: TextStyle(color: Colors.white, fontSize: 14),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),
//               ),
//             ),

//           // ZOOM CONTROL (bottom center)
//           Positioned(
//             left: 16,
//             right: 16,
//             bottom: 120,
//             child: _ZoomControl(
//               zoom: _zoom,
//               onZoomChanged: (v) async {
//                 setState(() => _zoom = v);
//                 try { await _controller.setZoomLevel(v); } catch (_) {}
//               },
//             ),
//           ),
//         ],
//       ),

//       // RECORD / STOP (pulsing)
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
//       floatingActionButton: Stack(
//         alignment: Alignment.center,
//         children: [
//           if (!_recording)
//             AnimatedBuilder(
//               animation: _pulseCtrl,
//               builder: (_, __) {
//                 final t = _pulseCtrl.value;
//                 final scale = 1.0 + 0.25 * t;
//                 final op = (1.0 - t) * .6;
//                 return Transform.scale(
//                   scale: scale,
//                   child: Container(
//                     width: 86,
//                     height: 86,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: Colors.redAccent.withOpacity(op),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           FloatingActionButton.large(
//             backgroundColor: Colors.redAccent,
//             onPressed: _recording ? _stopStream : _startStream,
//             child: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _pill(String text, Color bg) => Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//         decoration: BoxDecoration(
//           color: bg,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Colors.white24),
//         ),
//         child: Text(
//           text,
//           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
//         ),
//       );

//   Widget _roundIcon({required IconData icon, required VoidCallback onTap}) =>
//       InkResponse(
//         onTap: onTap,
//         radius: 28,
//         child: Container(
//           width: 44,
//           height: 44,
//           decoration: BoxDecoration(
//             color: Colors.black54,
//             shape: BoxShape.circle,
//             border: Border.all(color: Colors.white24),
//           ),
//           child: Icon(icon, color: Colors.white),
//         ),
//       );
// }

// class _ZoomControl extends StatelessWidget {
//   const _ZoomControl({required this.zoom, required this.onZoomChanged});
//   final double zoom;
//   final ValueChanged<double> onZoomChanged;

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       color: Colors.black54,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
//         child: Row(
//           children: [
//             const SizedBox(
//               width: 48,
//               child: Text('Zoom',
//                   style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
//             ),
//             Expanded(
//               child: Slider(
//                 value: zoom.clamp(1.0, 6.0),
//                 min: 1.0,
//                 max: 6.0,
//                 divisions: 50,
//                 onChanged: onZoomChanged,
//               ),
//             ),
//             SizedBox(
//               width: 48,
//               child: Text(
//                 zoom.toStringAsFixed(1),
//                 textAlign: TextAlign.right,
//                 style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// Painter: rotation + optional mirroring + BoxFit.cover scaling
// class _BoxesPainter extends CustomPainter {
//   _BoxesPainter({
//     required this.results,
//     required this.bufferW,
//     required this.bufferH,
//     required this.rotationDeg,
//     required this.mirror,
//   });

//   final List<Map<String, dynamic>> results;
//   final int bufferW;
//   final int bufferH;
//   final int rotationDeg;
//   final bool mirror;

//   // Accept [x1,y1,x2,y2] OR [x,y,w,h] OR [cx,cy,w,h], normalized or pixels
//   static ({double x0,double y0,double x1,double y1}) _parseBox(dynamic box,int bw,int bh){
//     double x0,y0,x1,y1;
//     if (box is List && box.length >= 4){
//       double a=(box[0] as num).toDouble(), b=(box[1] as num).toDouble(),
//              c=(box[2] as num).toDouble(), d=(box[3] as num).toDouble();
//       if (c>a && d>b){ x0=a; y0=b; x1=c; y1=d; }
//       else{ x0=a; y0=b; x1=a+c; y1=b+d; if(x1<=x0 || y1<=y0){ x0=a-c/2; y0=b-d/2; x1=a+c/2; y1=b+d/2; } }
//       if (x1<=2 && y1<=2){ x0*=bw; x1*=bw; y0*=bh; y1*=bh; }
//       return (x0:x0,y0:y0,x1:x1,y1:y1);
//     }
//     if (box is Map){
//       double? left=(box['left']??box['x'])?.toDouble(),
//               top=(box['top']??box['y'])?.toDouble(),
//               right=box['right']?.toDouble(),
//               bottom=box['bottom']?.toDouble(),
//               w=(box['w']??box['width'])?.toDouble(),
//               h=(box['h']??box['height'])?.toDouble(),
//               cx=box['cx']?.toDouble(),
//               cy=box['cy']?.toDouble();
//       if (left!=null && top!=null && right!=null && bottom!=null){ x0=left; y0=top; x1=right; y1=bottom; }
//       else if (left!=null && top!=null && w!=null && h!=null){ x0=left; y0=top; x1=left+w; y1=top+h; }
//       else if (cx!=null && cy!=null && w!=null && h!=null){ x0=cx-w/2; y0=cy-h/2; x1=cx+w/2; y1=cy+h/2; }
//       else { return (x0:0,y0:0,x1:0,y1:0); }
//       if (x1<=2 && y1<=2){ x0*=bw; x1*=bw; y0*=bh; y1*=bh; }
//       return (x0:x0,y0:y0,x1:x1,y1:y1);
//     }
//     return (x0:0,y0:0,x1:0,y1:0);
//   }

//   @override
//   void paint(Canvas canvas, Size size) {
//     if (bufferW == 0 || bufferH == 0) return;

//     // After rotation, the "upright" buffer size may swap W/H
//     final rotatedOddQuarter = (rotationDeg ~/ 90) % 2 == 1;
//     final effW = rotatedOddQuarter ? bufferH : bufferW;
//     final effH = rotatedOddQuarter ? bufferW : bufferH;

//     // BoxFit.cover mapping from upright buffer -> canvas
//     final scale = math.max(size.width / effW, size.height / effH);
//     final drawW = effW * scale;
//     final drawH = effH * scale;
//     final dx = (size.width - drawW) / 2;
//     final dy = (size.height - drawH) / 2;

//     final stroke = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3
//       ..color = const Color(0xFF25D5FD);
//     final shadow = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 6
//       ..color = Colors.black38;

//     for (final r in results) {
//       final raw = r['box']; if (raw == null) continue;

//       final p = _parseBox(raw, bufferW, bufferH);
//       double x0=p.x0, y0=p.y0, x1=p.x1, y1=p.y1;
//       if ((x1 - x0) <= 1 || (y1 - y0) <= 1) continue;

//       // rotate sensor -> upright
//       double rx0,ry0,rx1,ry1;
//       switch (rotationDeg % 360) {
//         case 0:   rx0=x0;             ry0=y0;             rx1=x1;             ry1=y1;             break;
//         case 90:  rx0=bufferH-y1;     ry0=x0;             rx1=bufferH-y0;     ry1=x1;             break;
//         case 180: rx0=bufferW-x1;     ry0=bufferH-y1;     rx1=bufferW-x0;     ry1=bufferH-y0;     break;
//         case 270: rx0=y0;             ry0=bufferW-x1;     rx1=y1;             ry1=bufferW-x0;     break;
//         default:  rx0=x0;             ry0=y0;             rx1=x1;             ry1=y1;
//       }

//       // mirror horizontally for front camera
//       if (mirror) {
//         final nx0 = effW - rx1;
//         final nx1 = effW - rx0;
//         rx0 = nx0; rx1 = nx1;
//       }

//       // clamp to upright buffer size
//       rx0 = rx0.clamp(0.0, effW.toDouble());
//       ry0 = ry0.clamp(0.0, effH.toDouble());
//       rx1 = rx1.clamp(0.0, effW.toDouble());
//       ry1 = ry1.clamp(0.0, effH.toDouble());

//       // map to canvas
//       final left   = rx0 * scale + dx;
//       final top    = ry0 * scale + dy;
//       final right  = rx1 * scale + dx;
//       final bottom = ry1 * scale + dy;
//       if (right <= 0 || bottom <= 0 || left >= size.width || top >= size.height) continue;

//       final rect = Rect.fromLTRB(left, top, right, bottom);
//       final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
//       canvas.drawRRect(rr.inflate(1.5), shadow);
//       canvas.drawRRect(rr, stroke);

//       // label chip (name only)
//       final label = (r['tag'] ?? r['label'] ?? r['class_name'])?.toString() ?? 'obj';
//       final tp = TextPainter(
//         text: TextSpan(
//           text: label,
//           style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
//         ),
//         textDirection: TextDirection.ltr,
//       )..layout(maxWidth: size.width - 16);

//       const padX = 8.0, padY = 5.0;
//       final pill = RRect.fromRectAndRadius(
//         Rect.fromLTWH(rect.left + 8, rect.top + 8, tp.width + padX * 2, tp.height + padY * 2),
//         const Radius.circular(8),
//       );
//       canvas.drawRRect(pill, Paint()..color = Colors.black.withOpacity(0.65));
//       tp.paint(canvas, Offset(pill.left + padX, pill.top + padY));
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _BoxesPainter old) =>
//       old.results != results ||
//       old.bufferW != bufferW ||
//       old.bufferH != bufferH ||
//       old.rotationDeg != rotationDeg ||
//       old.mirror != mirror;
// }


// lib/live_detect_page.dart
// import 'dart:async';
// import 'dart:math' as math;
// import 'package:camera/camera.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show DeviceOrientation; // <- needed
// import 'package:flutter_vision/flutter_vision.dart';

// class LiveDetectPage extends StatefulWidget {
//   const LiveDetectPage({
//     super.key,
//     required this.vision,
//     this.title = 'Live Detection',
//     this.conf = 0.01,
//     this.iou = 0.45,
//     this.cls = 0.03,
//   });

//   final FlutterVision vision;
//   final String title;
//   final double conf;
//   final double iou;
//   final double cls;

//   @override
//   State<LiveDetectPage> createState() => _LiveDetectPageState();
// }

// class _LiveDetectPageState extends State<LiveDetectPage>
//     with SingleTickerProviderStateMixin {
//   late CameraController _controller;
//   late CameraDescription _camera;

//   bool _inited = false;
//   bool _busy = false;
//   bool _recording = false;
//   bool _torch = false;

//   // Latest frame VISUAL data (results + the exact buffer/rotation used to get them)
//   _VisData? _vis;

//   // fps
//   int _frameCount = 0;
//   double _fps = 0;
//   Timer? _fpsTimer;

//   // camera
//   double _zoom = 1.0;
//   late final double _conf = widget.conf;
//   late final double _iou  = widget.iou;
//   late final double _cls  = widget.cls;

//   late final AnimationController _pulseCtrl;

//   @override
//   void initState() {
//     super.initState();
//     _pulseCtrl =
//         AnimationController(vsync: this, duration: const Duration(seconds: 1))
//           ..repeat(reverse: true);
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
//       ResolutionPreset.max,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );

//     await _controller.initialize();
//     await _controller.setFocusMode(FocusMode.auto);
//     await _controller.setExposureMode(ExposureMode.auto);
//     await _controller.setZoomLevel(_zoom);

//     _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//       if (!mounted) return;
//       setState(() {
//         _fps = _frameCount.toDouble();
//         _frameCount = 0;
//       });
//     });

//     if (!mounted) return;
//     setState(() => _inited = true);
//   }

//   Future<void> _switchCamera() async {
//     final cams = await availableCameras();
//     final idx = cams.indexOf(_camera);
//     final next = cams[(idx + 1) % cams.length];
//     _camera = next;

//     if (_controller.value.isStreamingImages) {
//       await _controller.stopImageStream();
//     }
//     await _controller.dispose();

//     _controller = CameraController(
//       _camera,
//       ResolutionPreset.max,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );
//     await _controller.initialize();
//     await _controller.setZoomLevel(_zoom);
//     await _controller.setFlashMode(FlashMode.off);

//     if (!mounted) return;
//     setState(() => _vis = null);
//     if (_recording) _startStream();
//   }

//   Future<void> _toggleTorch() async {
//     try {
//       await _controller.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
//       if (!mounted) return;
//       setState(() => _torch = !_torch);
//     } catch (_) {}
//   }

//   // Map sensor orientation + device orientation -> the rotation used by preview
//   int _rotationForPreview() {
//     final sensor = _camera.sensorOrientation;            // 0/90/180/270
//     final o = _controller.value.deviceOrientation;       // DeviceOrientation
//     switch (o) {
//       case DeviceOrientation.portraitUp:    return sensor % 360;
//       case DeviceOrientation.landscapeLeft: return (sensor + 270) % 360;
//       case DeviceOrientation.landscapeRight:return (sensor + 90)  % 360;
//       case DeviceOrientation.portraitDown:  return (sensor + 180) % 360;
//       default: return sensor % 360;
//     }
//   }

//   Future<void> _startStream() async {
//     if (_controller.value.isStreamingImages) return;
//     setState(() => _recording = true);

//     await _controller.startImageStream((CameraImage img) async {
//       _frameCount++;
//       if (_busy) return;
//       _busy = true;

//       // Capture the exact geometry used for THIS inference
//       final thisBufW = img.width;
//       final thisBufH = img.height;
//       final thisRot  = _rotationForPreview();

//       try {
//         final results = await widget.vision.yoloOnFrame(
//           bytesList: img.planes.map((p) => p.bytes).toList(),
//           imageWidth: img.width,
//           imageHeight: img.height,
//           iouThreshold: _iou,
//           confThreshold: _conf,
//           classThreshold: _cls,
//         );

//         if (!mounted) return;
//         // Frame-locked: store results + their own buffer/rotation
//         setState(() {
//           _vis = _VisData(
//             results: List<Map<String, dynamic>>.from(results),
//             bufferW: thisBufW,
//             bufferH: thisBufH,
//             rotationDeg: thisRot,
//           );
//         });

//         if (kDebugMode && _vis!.results.isNotEmpty && _frameCount % 15 == 0) {
//           debugPrint('det sample: ${_vis!.results.first}');
//         }
//       } catch (e) {
//         if (kDebugMode) debugPrint('yoloOnFrame error: $e');
//       } finally {
//         _busy = false;
//       }
//     });
//   }

//   Future<void> _stopStream() async {
//     if (_controller.value.isStreamingImages) {
//       await _controller.stopImageStream();
//     }
//     if (!mounted) return;
//     setState(() {
//       _recording = false;
//       _vis = null;
//     });
//   }

//   @override
//   void dispose() {
//     _pulseCtrl.dispose();
//     _fpsTimer?.cancel();
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

//     final screen = MediaQuery.of(context).size;
//     final pv = _controller.value.previewSize!;
//     final screenH = math.max(screen.height, screen.width);
//     final screenW = math.min(screen.height, screen.width);
//     final prevH = math.max(pv.height, pv.width);
//     final prevW = math.min(pv.height, pv.width);
//     final screenRatio = screenH / screenW;
//     final previewRatio = prevH / prevW;

//     final names = (_vis?.results ?? const [])
//         .map((r) => (r['tag'] ?? r['label'] ?? r['class_name'])?.toString() ?? '')
//         .where((s) => s.isNotEmpty)
//         .take(3)
//         .toList();

//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Text(widget.title),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//       ),
//       extendBodyBehindAppBar: true,
//       body: Stack(
//         children: [
//           // CAMERA
//           Center(
//             child: OverflowBox(
//               maxHeight:
//                   screenRatio > previewRatio ? screenH : (screenW / prevW) * prevH,
//               maxWidth:
//                   screenRatio > previewRatio ? (screenH / prevH) * prevW : screenW,
//               child: CameraPreview(_controller),
//             ),
//           ),

//           // top gradient
//           IgnorePointer(
//             child: Container(
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.center,
//                   colors: [Colors.black54, Colors.transparent],
//                 ),
//               ),
//             ),
//           ),

//           // BOXES (frame-locked)
//           Positioned.fill(
//             child: RepaintBoundary(
//               child: CustomPaint(
//                 isComplex: true,
//                 willChange: true,
//                 painter: _BoxesPainter(
//                   results: _vis?.results ?? const [],
//                   bufferW: _vis?.bufferW ?? 0,
//                   bufferH: _vis?.bufferH ?? 0,
//                   rotationDeg: _vis?.rotationDeg ?? 0,
//                 ),
//               ),
//             ),
//           ),

//           // LABEL CHIPS (top-left)
//           Positioned(
//             top: kToolbarHeight + 10,
//             left: 12,
//             child: Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: names.map((t) => _pill(t, Colors.white.withOpacity(.1))).toList(),
//             ),
//           ),

//           // FPS + TORCH + SWITCH (top-right)
//           Positioned(
//             top: kToolbarHeight + 10,
//             right: 10,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 _pill('${_fps.toStringAsFixed(1)} fps', Colors.white10),
//                 const SizedBox(height: 8),
//                 _roundIcon(
//                   icon: _torch ? Icons.flash_on : Icons.flash_off,
//                   onTap: _toggleTorch,
//                 ),
//                 const SizedBox(height: 8),
//                 _roundIcon(icon: Icons.cameraswitch, onTap: _switchCamera),
//               ],
//             ),
//           ),

//           // HINT
//           if (!_recording)
//             Positioned.fill(
//               child: IgnorePointer(
//                 child: Center(
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                     decoration: BoxDecoration(
//                       color: Colors.black54,
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: const Text(
//                       'Tip: Fill the frame with a single leaf • Hold steady • Good light',
//                       style: TextStyle(color: Colors.white, fontSize: 14),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),
//               ),
//             ),

//           // ZOOM
//           Positioned(
//             left: 16,
//             right: 16,
//             bottom: 120,
//             child: _ZoomControl(
//               zoom: _zoom,
//               onZoomChanged: (v) async {
//                 setState(() => _zoom = v);
//                 try { await _controller.setZoomLevel(v); } catch (_) {}
//               },
//             ),
//           ),
//         ],
//       ),

//       floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
//       floatingActionButton: Stack(
//         alignment: Alignment.center,
//         children: [
//           if (!_recording)
//             AnimatedBuilder(
//               animation: _pulseCtrl,
//               builder: (_, __) {
//                 final t = _pulseCtrl.value;
//                 final scale = 1.0 + 0.25 * t;
//                 final op = (1.0 - t) * .6;
//                 return Transform.scale(
//                   scale: scale,
//                   child: Container(
//                     width: 86, height: 86,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: Colors.redAccent.withOpacity(op),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           FloatingActionButton.large(
//             backgroundColor: Colors.redAccent,
//             onPressed: _recording ? _stopStream : _startStream,
//             child: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _pill(String text, Color bg) => Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//         decoration: BoxDecoration(
//           color: bg,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Colors.white24),
//         ),
//         child: Text(text,
//             style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
//       );

//   Widget _roundIcon({required IconData icon, required VoidCallback onTap}) =>
//       InkResponse(
//         onTap: onTap,
//         radius: 28,
//         child: Container(
//           width: 44,
//           height: 44,
//           decoration: BoxDecoration(
//             color: Colors.black54,
//             shape: BoxShape.circle,
//             border: Border.all(color: Colors.white24),
//           ),
//           child: Icon(icon, color: Colors.white),
//         ),
//       );
// }

// class _ZoomControl extends StatelessWidget {
//   const _ZoomControl({required this.zoom, required this.onZoomChanged});
//   final double zoom;
//   final ValueChanged<double> onZoomChanged;

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       color: Colors.black54,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
//         child: Row(
//           children: [
//             const SizedBox(
//               width: 48,
//               child: Text('Zoom',
//                   style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
//             ),
//             Expanded(
//               child: Slider(
//                 value: zoom.clamp(1.0, 6.0),
//                 min: 1.0, max: 6.0, divisions: 50,
//                 onChanged: onZoomChanged,
//               ),
//             ),
//             SizedBox(
//               width: 48,
//               child: Text(zoom.toStringAsFixed(1),
//                   textAlign: TextAlign.right,
//                   style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ---------------- Painter & helpers ----------------

// class _VisData {
//   _VisData({
//     required this.results,
//     required this.bufferW,
//     required this.bufferH,
//     required this.rotationDeg,
//   });

//   final List<Map<String, dynamic>> results;
//   final int bufferW;
//   final int bufferH;
//   final int rotationDeg;
// }

// /// Painter uses the EXACT buffer size + rotation from the same frame
// class _BoxesPainter extends CustomPainter {
//   _BoxesPainter({
//     required this.results,
//     required this.bufferW,
//     required this.bufferH,
//     required this.rotationDeg,
//   });

//   final List<Map<String, dynamic>> results;
//   final int bufferW;
//   final int bufferH;
//   final int rotationDeg;

//   static ({double x0, double y0, double x1, double y1}) _parseBox(
//     dynamic box,
//     int bufW,
//     int bufH,
//   ) {
//     double x0, y0, x1, y1;
//     if (box is List && box.length >= 4) {
//       double a = (box[0] as num).toDouble();
//       double b = (box[1] as num).toDouble();
//       double c = (box[2] as num).toDouble();
//       double d = (box[3] as num).toDouble();

//       if (c > a && d > b) { // [x1,y1,x2,y2]
//         x0 = a; y0 = b; x1 = c; y1 = d;
//       } else {               // [x,y,w,h] or [cx,cy,w,h]
//         x0 = a; y0 = b; x1 = a + c; y1 = b + d;
//         if (x1 <= x0 || y1 <= y0) {
//           x0 = a - c / 2.0; y0 = b - d / 2.0; x1 = a + c / 2.0; y1 = b + d / 2.0;
//         }
//       }
//       if (x1 <= 2 && y1 <= 2) { // normalized -> pixels
//         x0 *= bufW; x1 *= bufW; y0 *= bufH; y1 *= bufH;
//       }
//       return (x0: x0, y0: y0, x1: x1, y1: y1);
//     }
//     if (box is Map) {
//       double? left = (box['left'] ?? box['x'])?.toDouble();
//       double? top = (box['top'] ?? box['y'])?.toDouble();
//       double? right = (box['right'])?.toDouble();
//       double? bottom = (box['bottom'])?.toDouble();
//       double? w = (box['w'] ?? box['width'])?.toDouble();
//       double? h = (box['h'] ?? box['height'])?.toDouble();
//       double? cx = (box['cx'])?.toDouble();
//       double? cy = (box['cy'])?.toDouble();

//       if (left != null && top != null && right != null && bottom != null) {
//         x0 = left; y0 = top; x1 = right; y1 = bottom;
//       } else if (left != null && top != null && w != null && h != null) {
//         x0 = left; y0 = top; x1 = left + w; y1 = top + h;
//       } else if (cx != null && cy != null && w != null && h != null) {
//         x0 = cx - w / 2; y0 = cy - h / 2; x1 = cx + w / 2; y1 = cy + h / 2;
//       } else {
//         return (x0: 0, y0: 0, x1: 0, y1: 0);
//       }
//       if (x1 <= 2 && y1 <= 2) { x0 *= bufW; x1 *= bufW; y0 *= bufH; y1 *= bufH; }
//       return (x0: x0, y0: y0, x1: x1, y1: y1);
//     }
//     return (x0: 0, y0: 0, x1: 0, y1: 0);
//   }

//   @override
//   void paint(Canvas canvas, Size size) {
//     if (bufferW == 0 || bufferH == 0) return;

//     // Effective buffer after rotation (matches the preview)
//     final rotated = (rotationDeg ~/ 90) % 2 == 1;
//     final effW = rotated ? bufferH : bufferW;
//     final effH = rotated ? bufferW : bufferH;

//     // BoxFit.cover transform
//     final scale = math.max(size.width / effW, size.height / effH);
//     final drawW = effW * scale, drawH = effH * scale;
//     final dx = (size.width - drawW) / 2, dy = (size.height - drawH) / 2;

//     final stroke = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3
//       ..color = const Color(0xFF25D5FD);
//     final shadow = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 6
//       ..color = Colors.black38;

//     for (final r in results) {
//       final rawBox = r['box'];
//       if (rawBox == null) continue;

//       final p = _parseBox(rawBox, bufferW, bufferH);
//       double x0 = p.x0, y0 = p.y0, x1 = p.x1, y1 = p.y1;
//       if ((x1 - x0) <= 1 || (y1 - y0) <= 1) continue;

//       // Rotate into preview-upright pixel space
//       double rx0, ry0, rx1, ry1;
//       switch (rotationDeg % 360) {
//         case 0:   rx0 = x0; ry0 = y0; rx1 = x1; ry1 = y1; break;
//         case 90:  rx0 = bufferH - y1; ry0 = x0; rx1 = bufferH - y0; ry1 = x1; break;
//         case 180: rx0 = bufferW - x1; ry0 = bufferH - y1; rx1 = bufferW - x0; ry1 = bufferH - y0; break;
//         case 270: rx0 = y0; ry0 = bufferW - x1; rx1 = y1; ry1 = bufferW - x0; break;
//         default:  rx0 = x0; ry0 = y0; rx1 = x1; ry1 = y1;
//       }

//       // Clamp to effective bounds
//       rx0 = rx0.clamp(0.0, effW.toDouble());
//       ry0 = ry0.clamp(0.0, effH.toDouble());
//       rx1 = rx1.clamp(0.0, effW.toDouble());
//       ry1 = ry1.clamp(0.0, effH.toDouble());

//       // Map to canvas
//       final left = rx0 * scale + dx, top = ry0 * scale + dy;
//       final right = rx1 * scale + dx, bottom = ry1 * scale + dy;
//       if (right <= 0 || bottom <= 0 || left >= size.width || top >= size.height) {
//         continue;
//       }

//       final rect = Rect.fromLTRB(left, top, right, bottom);
//       final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
//       canvas.drawRRect(rr.inflate(1.5), shadow);
//       canvas.drawRRect(rr, stroke);

//       final label =
//           (r['tag'] ?? r['label'] ?? r['class_name'])?.toString() ?? 'obj';
//       final tp = TextPainter(
//         text: TextSpan(
//           text: label,
//           style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
//         ),
//         textDirection: TextDirection.ltr,
//       )..layout(maxWidth: size.width - 16);

//       const padX = 8.0, padY = 5.0;
//       final pill = RRect.fromRectAndRadius(
//         Rect.fromLTWH(rect.left + 8, rect.top + 8, tp.width + padX * 2, tp.height + padY * 2),
//         const Radius.circular(8),
//       );
//       canvas.drawRRect(pill, Paint()..color = Colors.black.withOpacity(0.65));
//       tp.paint(canvas, Offset(pill.left + padX, pill.top + padY));
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _BoxesPainter old) =>
//       old.results != results ||
//       old.bufferW != bufferW ||
//       old.bufferH != bufferH ||
//       old.rotationDeg != rotationDeg;
// }



// lib/live_detect_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vision/flutter_vision.dart';

class LiveDetectPage extends StatefulWidget {
  const LiveDetectPage({
    super.key,
    required this.vision,
    this.title = 'Live Detection',
    // thresholds are used internally only (no UI sliders)
    this.conf = 0.01,
    this.iou = 0.45,
    this.cls = 0.03,
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

  // latest camera buffer size (used to map boxes)
  int _bufferW = 0, _bufferH = 0;

  // latest recognitions
  List<Map<String, dynamic>> _results = const [];

  // fps meter
  int _frameCount = 0;
  double _fps = 0;
  Timer? _fpsTimer;

  // camera
  double _zoom = 1.0;
  late final double _conf;
  late final double _iou;
  late final double _cls;

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
      ResolutionPreset.max,
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
    if (!mounted) return;
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

          // subtle top gradient
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

          // LABEL CHIPS (top-left) — names only
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

          // FPS + TORCH + SWITCH (top-right)
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

          // ZOOM CONTROL (bottom center)
          Positioned(
            left: 16,
            right: 16,
            bottom: 120,
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

      // RECORD / STOP (pulsing)
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
}

class _ZoomControl extends StatelessWidget {
  const _ZoomControl({required this.zoom, required this.onZoomChanged});

  final double zoom;
  final ValueChanged<double> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black54,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            const SizedBox(
              width: 48,
              child: Text('Zoom',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Slider(
                value: zoom.clamp(1.0, 6.0),
                min: 1.0,
                max: 6.0,
                divisions: 50,
                onChanged: onZoomChanged,
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                zoom.toStringAsFixed(1),
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
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



 