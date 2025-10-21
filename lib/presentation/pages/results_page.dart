 
 
// import 'dart:io';
// import 'package:flutter/material.dart';

// class ResultPage extends StatelessWidget {
//   final String prediction;   // e.g., "magnesium - 0.89"
//   final String imagePath;    // <-- annotated image path
  
//   const ResultPage({
//     Key? key,
//     required this.prediction,
//     required this.imagePath,
     
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         centerTitle: true,
//         title: const Text(
//           'Prediction Results',
//           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          
//         ),
//       ),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
            
//             children: [
//               // Image area: keep aspect ratio and avoid overflow
//               Expanded(
//                 child: Center(
//                   child: Image.file(
//                     File(imagePath),
//                     fit: BoxFit.contain,   // ✅ keeps boxes aligned
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
              
              
//               Text(
//                 'Prediction : $prediction',
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Color(0xFF032868),
                  
//                 ),
                
//               ),
//               const SizedBox(height: 8),
              
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

 
// import 'dart:io';
// import 'package:flutter/material.dart';

// /// Final payload shown on the results screen.
// class DetectionResult {
//   final String prediction;   // e.g. "blister blight - 0.84"
//   final String imagePath;    // annotated image path (or original on failure)
//   const DetectionResult(this.prediction, this.imagePath);
// }

// /// Shows ONLY a spinner until [future] completes, then shows result.
// class ResultPage extends StatelessWidget {
//   final Future<DetectionResult> future;

//   const ResultPage({super.key, required this.future});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         centerTitle: true,
//         title: const Text(
//           'Prediction Results',
//           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
//         ),
//       ),
//       body: SafeArea(
//         child: FutureBuilder<DetectionResult>(
//           future: future,
//           builder: (context, snap) {
//             if (snap.connectionState != ConnectionState.done) {
//               // 🔵 ONLY loading icon while computing (no photo yet)
//               return const Center(child: CircularProgressIndicator());
//             }
//             if (snap.hasError || !snap.hasData) {
//               return Center(
//                 child: Text(
//                   'Failed: ${snap.error ?? "Unknown error"}',
//                   textAlign: TextAlign.center,
//                 ),
//               );
//             }

//             final res = snap.data!;
//             return Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   Expanded(
//                     child: Center(
//                       child: Image.file(
//                         File(res.imagePath),
//                         fit: BoxFit.contain,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     'Prediction : ${res.prediction}',
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Color(0xFF032868),
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                 ],
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
 
// import 'dart:io';
// import 'package:flutter/material.dart';

// /// Final payload shown on the results screen.
// class DetectionResult {
//   final String prediction;   // e.g. "blister blight - 0.84"
//   final String imagePath;    // annotated image path (or original on failure)
//   const DetectionResult(this.prediction, this.imagePath);
// }

// /// Shows ONLY a spinner until [future] completes, then shows result.
// class ResultPage extends StatelessWidget {
//   final Future<DetectionResult> future;

//   const ResultPage({super.key, required this.future});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         centerTitle: true,
//         title: const Text(
//           'Prediction Results',
//           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
//         ),
//       ),
//       body: SafeArea(
//         child: FutureBuilder<DetectionResult>(
//           future: future,
//           builder: (context, snap) {
//             if (snap.connectionState != ConnectionState.done) {
//               // 🔵 ONLY loading icon while computing (no photo yet)
//               return const Center(child: CircularProgressIndicator());
//             }
//             if (snap.hasError || !snap.hasData) {
//               return Center(
//                 child: Text(
//                   'Failed: ${snap.error ?? "Unknown error"}',
//                   textAlign: TextAlign.center,
//                 ),
//               );
//             }

//             final res = snap.data!;
//             return Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   Expanded(
//                     child: Center(
//                       child: Image.file(
//                         File(res.imagePath),
//                         fit: BoxFit.contain,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     'Prediction : ${res.prediction}',
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Color(0xFF032868),
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                 ],
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }


// import 'dart:io';
// import 'package:flutter/material.dart';

// /// Final payload shown on the results screen.
// class DetectionResult {
//   final String prediction;   // e.g. "blister blight - 0.84"
//   final String imagePath;    // annotated image path (or original on failure)
//   const DetectionResult(this.prediction, this.imagePath);
// }

// class ResultPage extends StatelessWidget {
//   final Future<DetectionResult> future;
//   const ResultPage({super.key, required this.future});

//   // --- Helpers ---
//   (String label, double? conf) _parsePrediction(String p) {
//     // Accepts "label - 0.84" or "label–0.84" etc.
//     final parts = p.split(RegExp(r'\s*[-–]\s*'));
//     String label = parts.isNotEmpty ? parts.first.trim() : p.trim();
//     double? conf;
//     if (parts.length > 1) {
//       final raw = parts.last.trim();
//       final c = double.tryParse(raw);
//       if (c != null && c >= 0 && c <= 1) conf = c;
//       // also handle "84%" form
//       if (conf == null && raw.endsWith('%')) {
//         final n = double.tryParse(raw.replaceAll('%', ''));
//         if (n != null) conf = (n / 100).clamp(0, 1);
//       }
//     }
//     return (label, conf);
//   }

//   Color _labelColor(String label) {
//     final l = label.toLowerCase();
//     if (l.contains('healthy') || l.contains('normal')) return Colors.green;
//     return Colors.redAccent;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       // Transparent app bar over gradient
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         centerTitle: true,
//         title: const Text(
//           'Prediction Results',
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//       ),
//       extendBodyBehindAppBar: true,
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFF2ecc71), Color(0xFF27ae60)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: SafeArea(
//           child: FutureBuilder<DetectionResult>(
//             future: future,
//             builder: (context, snap) {
//               if (snap.connectionState != ConnectionState.done) {
//                 return const Center(child: CircularProgressIndicator(color: Colors.white));
//               }
//               if (snap.hasError || !snap.hasData) {
//                 return Center(
//                   child: Padding(
//                     padding: const EdgeInsets.all(24),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Icon(Icons.error_outline, color: Colors.white, size: 42),
//                         const SizedBox(height: 12),
//                         Text(
//                           'Failed: ${snap.error ?? "Unknown error"}',
//                           textAlign: TextAlign.center,
//                           style: const TextStyle(color: Colors.white, fontSize: 16),
//                         ),
//                         const SizedBox(height: 16),
//                         OutlinedButton.icon(
//                           style: OutlinedButton.styleFrom(
//                             foregroundColor: Colors.white,
//                             side: const BorderSide(color: Colors.white),
//                           ),
//                           onPressed: () => Navigator.pop(context),
//                           icon: const Icon(Icons.arrow_back),
//                           label: const Text('Go back'),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               }

//               final res = snap.data!;
//               final (label, conf) = _parsePrediction(res.prediction);
//               final confPct = conf != null ? (conf * 100).round() : null;

//               return Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
//                 child: Column(
//                   children: [
//                     // Image card with overlay label
//                     Card(
//                       elevation: 10,
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                       clipBehavior: Clip.antiAlias,
//                       child: Stack(
//                         children: [
//                           // Image
//                           AspectRatio(
//                             aspectRatio: 4 / 3,
//                             child: Image.file(
//                               File(res.imagePath),
//                               fit: BoxFit.cover,
//                               errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 48)),
//                             ),
//                           ),
//                           // Bottom gradient for readability
//                           Positioned.fill(
//                             child: IgnorePointer(
//                               child: DecoratedBox(
//                                 decoration: BoxDecoration(
//                                   gradient: LinearGradient(
//                                     begin: Alignment.bottomCenter,
//                                     end: Alignment.center,
//                                     colors: [
//                                       Colors.black.withOpacity(0.35),
//                                       Colors.transparent,
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                           // Label chip
//                           Positioned(
//                             left: 12,
//                             top: 12,
//                             child: Chip(
//                               backgroundColor: _labelColor(label).withOpacity(0.15),
//                               avatar: Icon(
//                                 label.toLowerCase().contains('healthy') ? Icons.eco : Icons.warning_amber_rounded,
//                                 color: _labelColor(label),
//                                 size: 18,
//                               ),
//                               label: Text(
//                                 label.isEmpty ? 'Unknown' : label,
//                                 style: TextStyle(
//                                   color: _labelColor(label),
//                                   fontWeight: FontWeight.w700,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           // Confidence badge
//                           if (confPct != null)
//                             Positioned(
//                               right: 12,
//                               top: 12,
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                                 decoration: BoxDecoration(
//                                   color: Colors.black.withOpacity(0.55),
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                                 child: Text(
//                                   '$confPct%',
//                                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),

//                     const SizedBox(height: 16),

//                     // Confidence bar + text
//                     if (conf != null)
//                       Column(
//                         children: [
//                           Row(
//                             children: [
//                               const Text('Confidence', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
//                               const Spacer(),
//                               Text(
//                                 '$confPct%',
//                                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//                           ClipRRect(
//                             borderRadius: BorderRadius.circular(8),
//                             child: LinearProgressIndicator(
//                               value: conf.clamp(0, 1),
//                               minHeight: 10,
//                               backgroundColor: Colors.white24,
//                               valueColor: AlwaysStoppedAnimation<Color>(_labelColor(label)),
//                             ),
//                           ),
//                           const SizedBox(height: 14),
//                         ],
//                       ),

//                     // Prediction text
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(14),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.06),
//                             blurRadius: 12,
//                             offset: const Offset(0, 6),
//                           ),
//                         ],
//                       ),
//                       child: Text(
//                         'Prediction: $label${confPct != null ? ' • $confPct%' : ''}',
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.w700,
//                           color: Color(0xFF032868),
//                         ),
//                       ),
//                     ),

//                     const Spacer(),

//                     // Actions
//                     Row(
//                       children: [
//                         Expanded(
//                           child: OutlinedButton.icon(
//                             onPressed: () => Navigator.pop(context),
//                             icon: const Icon(Icons.camera_alt_outlined),
//                             label: const Text('Scan again'),
//                             style: OutlinedButton.styleFrom(
//                               foregroundColor: Colors.white,
//                               side: const BorderSide(color: Colors.white),
//                               padding: const EdgeInsets.symmetric(vertical: 14),
//                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: ElevatedButton.icon(
//                             onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
//                             icon: const Icon(Icons.check_circle_outline),
//                             label: const Text('Close'),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.white,
//                               foregroundColor: const Color(0xFF27ae60),
//                               padding: const EdgeInsets.symmetric(vertical: 14),
//                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }
// }


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'tea_doctor_ai.dart'; // ⬅️ import the service

/// Final payload shown on the results screen.
class DetectionResult {
  final String prediction;   // e.g. "blister blight - 0.84"
  final String imagePath;    // annotated image path (or original on failure)
  const DetectionResult(this.prediction, this.imagePath);
}

class ResultPage extends StatefulWidget {
  final Future<DetectionResult> future;
  const ResultPage({super.key, required this.future});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

const String kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

final _model = GenerativeModel(
  model: "gemini-2.5-flash",
  apiKey: kGeminiApiKey,
);

class _ResultPageState extends State<ResultPage> {
  String? _label;
  double? _conf;
  String? _advice;
  bool _loadingAdvice = false;

  @override
  void initState() {
    super.initState();
    _pingGemini();        // 👈 runs once when the page opens
  }

  Future<void> _pingGemini() async {
    try {
      final r = await _model.generateContent([Content.text('hello')]);
      debugPrint('Gemini OK: ${r.text}');
    } catch (e) {
      debugPrint('Gemini call failed: $e');
    }
  }

  // --- Helpers ---
  (String label, double? conf) _parsePrediction(String p) {
    final parts = p.split(RegExp(r'\s*[-–]\s*'));
    String label = parts.isNotEmpty ? parts.first.trim() : p.trim();
    double? conf;
    if (parts.length > 1) {
      final raw = parts.last.trim();
      final c = double.tryParse(raw);
      if (c != null && c >= 0 && c <= 1) conf = c;
      if (conf == null && raw.endsWith('%')) {
        final n = double.tryParse(raw.replaceAll('%', ''));
        if (n != null) conf = (n / 100).clamp(0, 1);
      }
    }
    return (label, conf);
  }

  Color _labelColor(String label) {
    final l = label.toLowerCase();
    if (l.contains('healthy') || l.contains('normal')) return Colors.green;
    return Colors.redAccent;
  }

  Future<void> _loadAdvice() async {
    if (_label == null) return;
    setState(() => _loadingAdvice = true);
    try {
      final txt = await TeaDoctorAI.instance().advice(
        label: _label!,
        confidence: _conf,
        // lat/lng/locName: add later if you pass location into this page
      );
      if (mounted) setState(() => _advice = txt);
    } catch (e) {
      if (mounted) setState(() => _advice = 'Assistant unavailable: $e');
    } finally {
      if (mounted) setState(() => _loadingAdvice = false);
    }
  }

  void _openChat() {
  if (_label == null) return;

  final chat = TeaDoctorAI.instance().startChat(
    label: _label!,
    confidence: _conf,
  );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      // Lift the whole sheet when the keyboard appears.
      final kb = MediaQuery.of(ctx).viewInsets.bottom;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: kb),
        child: _TeaChatSheet(chat: chat),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Prediction Results', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2ecc71), Color(0xFF27ae60)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<DetectionResult>(
            future: widget.future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (snap.hasError || !snap.hasData) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white, size: 42),
                        const SizedBox(height: 12),
                        Text(
                          'Failed: ${snap.error ?? "Unknown error"}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                          ),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Go back'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final res = snap.data!;
              final parsed = _parsePrediction(res.prediction);
              _label ??= parsed.$1.isEmpty ? 'Unknown' : parsed.$1;
              _conf ??= parsed.$2;
              final confPct = _conf != null ? (_conf! * 100).round() : null;

              // Kick off advice load once
              if (_advice == null && !_loadingAdvice) {
                // microtask avoids setState during build warning
                Future.microtask(_loadAdvice);
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              
                  children: [
                    // Image card with overlay label
                    Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.file(
                              File(res.imagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 48)),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.center,
                                    colors: [Colors.black.withOpacity(0.35), Colors.transparent],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            top: 12,
                            child: Chip(
                              backgroundColor: _labelColor(_label!).withOpacity(0.15),
                              avatar: Icon(
                                _label!.toLowerCase().contains('healthy') ? Icons.eco : Icons.warning_amber_rounded,
                                color: _labelColor(_label!),
                                size: 18,
                              ),
                              label: Text(
                                _label!,
                                style: TextStyle(color: _labelColor(_label!), fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          if (confPct != null)
                            Positioned(
                              right: 12,
                              top: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('$confPct%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_conf != null)
                      Column(
                        children: [
                          Row(
                            children: [
                              const Text('Confidence', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                               const SizedBox(height: 12),
                              Text('${(_conf! * 100).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _conf!.clamp(0, 1),
                              minHeight: 10,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(_labelColor(_label!)),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),

                    // Prediction text
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
                      ),
                      child: Text(
                        'Prediction: ${_label!}${confPct != null ? ' • $confPct%' : ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF032868)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🔹 Auto-recommendation + Ask more
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Recommended treatment', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            if (_loadingAdvice)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: LinearProgressIndicator(minHeight: 6),
                              )
                            else
                              Text(_advice ?? '—'),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                label: const Text('Ask more'),
                                onPressed: _label == null ? null : _openChat,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                     const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Scan again'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Close'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF27ae60),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
              
              );
            },
          ),
        ),
      ),
    );
  }
}

// Simple chat sheet for follow-ups
class _TeaChatSheet extends StatefulWidget {
  const _TeaChatSheet({required this.chat});
  final TeaDoctorChat chat;

  @override
  State<_TeaChatSheet> createState() => _TeaChatSheetState();
}

class _TeaChatSheetState extends State<_TeaChatSheet> {
  final _ctrl = TextEditingController();
  final List<Map<String, String>> _msgs = [];
  bool _busy = false;

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() { _msgs.add({'role': 'user', 'content': text}); _busy = true; });
    try {
      final reply = await widget.chat.send(text);
      setState(() { _msgs.add({'role': 'assistant', 'content': reply}); });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.40,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Material(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: _msgs.length,
                itemBuilder: (_, i) {
                  final m = _msgs[i]; final isUser = m['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.green.shade600 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        m['content']!,
                        style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Input row — wrapped in SafeArea so it stays above system bars.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4, // grows as you type
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Ask about treatment…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          isDense: true,
                        ),
                        onSubmitted: (v) { _ctrl.clear(); _send(v); },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _busy ? null : () {
                        final v = _ctrl.text; _ctrl.clear(); _send(v);
                      },
                      child: _busy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
