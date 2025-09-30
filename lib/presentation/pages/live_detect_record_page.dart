// import 'dart:async';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:camerawesome/camerawesome_plugin.dart';
// import 'package:flutter_vision/flutter_vision.dart';
// import 'package:path_provider/path_provider.dart';

// /// Live preview with YOLO boxes while recording video.
// class LiveDetectRecordPage extends StatefulWidget {
//   final FlutterVision vision;
//   const LiveDetectRecordPage({super.key, required this.vision});

//   @override
//   State<LiveDetectRecordPage> createState() => _LiveDetectRecordPageState();
// }

// class _LiveDetectRecordPageState extends State<LiveDetectRecordPage> {
//   // detection state
//   List<Map<String, dynamic>> _boxes = [];
//   bool _busy = false;
//   DateTime _lastInfer = DateTime.fromMillisecondsSinceEpoch(0);

//   // frame size for overlay scaling
//   int _frameW = 640;
//   int _frameH = 640;

//   bool _recording = false;

//   Future<void> _onFrame(AnalysisImage img) async {
//     // throttle to keep UI smooth (≈5–6 fps)
//     final now = DateTime.now();
//     if (_busy || now.difference(_lastInfer).inMilliseconds < 180) return;
//     _lastInfer = now;
//     _busy = true;

//     try {
//       // camerawesome helper to convert NV21/BGRA frame → JPEG bytes
//       final Uint8List jpeg = await img.toJpeg();
//       _frameW = img.width;
//       _frameH = img.height;

//       final results = await widget.vision.yoloOnImage(
//         bytesList: jpeg,
//         imageHeight: img.height,
//         imageWidth: img.width,
//         iouThreshold: 0.45,
//         confThreshold: 0.25,
//         classThreshold: 0.25,
//       );

//       if (!mounted) return;

//       // normalize to List<Map> with a 'box'
//       final parsed = <Map<String, dynamic>>[];
//       for (final r in results) {
//         final m = (r as Map).cast<String, dynamic>();
//         if (m['box'] is List && (m['box'] as List).length >= 4) parsed.add(m);
//       }
//       setState(() => _boxes = parsed);
//     } catch (_) {
//       // ignore individual frame errors
//     } finally {
//       _busy = false;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return CamerawesomeBuilder.awesome(
//       // SaveConfig → where video file is stored
//       saveConfig: SaveConfig.video(
//         mirrorFrontCamera: false,
//         videoOptions: const VideoOptions.bitrate(Bitrate.medium),
//         pathBuilder: (p) async => (await getTemporaryDirectory()).uri,
//       ),

//       sensorConfig: SensorConfig.single(
//         sensor: Sensor.position(SensorPosition.back),
//         aspectRatio: CameraAspectRatios.ratio_16_9,
//         flashMode: FlashMode.none,
//       ),

//       analysisConfig: AnalysisConfig(
//         androidOptions: const AndroidAnalysisOptions.nv21(width: 480, height: 480),
//         // iOS uses BGRA; toJpeg() works there too
//         maxFramesPerSecond: 8,
//         autoStart: true,
//       ),

//       previewFit: CameraPreviewFit.contain,
//       onImageForAnalysis: _onFrame,

//       theme: AwesomeTheme(
//         bottomActions: AwesomeBottomActions(
//           left: AwesomeFlashButton(),
//           right: AwesomeSwitchCameraButton(),
//           recordButtonBuilder: (state) => AwesomeRecordButton(
//             state: state,
//             recording: _recording,
//             onRecordStart: () async {
//               await state.startRecording();
//               setState(() => _recording = true);
//             },
//             onRecordEnd: () async {
//               final mediaCapture = await state.stopRecording();
//               setState(() => _recording = false);
//               if (!mounted) return;
//               final path = mediaCapture?.file?.path ?? 'unknown';
//               ScaffoldMessenger.of(context)
//                   .showSnackBar(SnackBar(content: Text('Saved: $path')));
//               Navigator.of(context).pop(); // return to previous screen
//             },
//           ),
//         ),
//       ),

//       // draw YOLO boxes on top
//       children: [
//         Positioned.fill(
//           child: IgnorePointer(
//             child: CustomPaint(
//               painter: _BoxPainter(
//                 boxes: _boxes,
//                 frameW: _frameW,
//                 frameH: _frameH,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _BoxPainter extends CustomPainter {
//   final List<Map<String, dynamic>> boxes;
//   final int frameW;
//   final int frameH;

//   _BoxPainter({required this.boxes, required this.frameW, required this.frameH});

//   @override
//   void paint(Canvas canvas, Size size) {
//     if (frameW <= 0 || frameH <= 0) return;
//     final sx = size.width / frameW;
//     final sy = size.height / frameH;

//     final boxPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3
//       ..color = const Color(0xFF00B4FF);

//     final barPaint = Paint()..color = const Color(0xCC00B4FF);
//     const textStyle = TextStyle(
//       color: Colors.white,
//       fontSize: 14,
//       fontWeight: FontWeight.bold,
//     );

//     for (final m in boxes) {
//       final b = (m['box'] as List).cast<num>();
//       final x1 = (b[0] * sx).toDouble();
//       final y1 = (b[1] * sy).toDouble();
//       final x2 = (b[2] * sx).toDouble();
//       final y2 = (b[3] * sy).toDouble();

//       final rect = Rect.fromLTRB(x1, y1, x2, y2);
//       canvas.drawRect(rect, boxPaint);

//       final label = (m['tag'] ?? m['label'] ?? '').toString();
//       if (label.isEmpty) continue;

//       final tp = TextPainter(
//         text: const TextSpan(text: ''), // we’ll set text later
//         textDirection: TextDirection.ltr,
//       );
//       tp.text = TextSpan(text: label, style: textStyle);
//       tp.layout();

//       final bw = tp.width + 10;
//       final bh = tp.height + 6;
//       final barTop = (y1 - bh).clamp(0, size.height - bh);
//       final barRect = Rect.fromLTWH(x1, barTop, bw, bh);
//       canvas.drawRect(barRect, barPaint);
//       tp.paint(canvas, Offset(barRect.left + 5, barRect.top + 3));
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _BoxPainter old) =>
//       old.boxes != boxes || old.frameW != frameW || old.frameH != frameH;
// }
