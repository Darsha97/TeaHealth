 
 
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


import 'dart:io';
import 'package:flutter/material.dart';

/// Final payload shown on the results screen.
class DetectionResult {
  final String prediction;   // e.g. "blister blight - 0.84"
  final String imagePath;    // annotated image path (or original on failure)
  const DetectionResult(this.prediction, this.imagePath);
}

class ResultPage extends StatelessWidget {
  final Future<DetectionResult> future;
  const ResultPage({super.key, required this.future});

  // --- Helpers ---
  (String label, double? conf) _parsePrediction(String p) {
    // Accepts "label - 0.84" or "label–0.84" etc.
    final parts = p.split(RegExp(r'\s*[-–]\s*'));
    String label = parts.isNotEmpty ? parts.first.trim() : p.trim();
    double? conf;
    if (parts.length > 1) {
      final raw = parts.last.trim();
      final c = double.tryParse(raw);
      if (c != null && c >= 0 && c <= 1) conf = c;
      // also handle "84%" form
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent app bar over gradient
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Prediction Results',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
            future: future,
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
              final (label, conf) = _parsePrediction(res.prediction);
              final confPct = conf != null ? (conf * 100).round() : null;

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    // Image card with overlay label
                    Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          // Image
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.file(
                              File(res.imagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 48)),
                            ),
                          ),
                          // Bottom gradient for readability
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.center,
                                    colors: [
                                      Colors.black.withOpacity(0.35),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Label chip
                          Positioned(
                            left: 12,
                            top: 12,
                            child: Chip(
                              backgroundColor: _labelColor(label).withOpacity(0.15),
                              avatar: Icon(
                                label.toLowerCase().contains('healthy') ? Icons.eco : Icons.warning_amber_rounded,
                                color: _labelColor(label),
                                size: 18,
                              ),
                              label: Text(
                                label.isEmpty ? 'Unknown' : label,
                                style: TextStyle(
                                  color: _labelColor(label),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          // Confidence badge
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
                                child: Text(
                                  '$confPct%',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Confidence bar + text
                    if (conf != null)
                      Column(
                        children: [
                          Row(
                            children: [
                              const Text('Confidence', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text(
                                '$confPct%',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: conf.clamp(0, 1),
                              minHeight: 10,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(_labelColor(label)),
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        'Prediction: $label${confPct != null ? ' • $confPct%' : ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF032868),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Actions
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
