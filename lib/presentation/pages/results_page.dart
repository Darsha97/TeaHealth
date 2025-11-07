 

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_provider.dart';
import 'tea_doctor_ai.dart'; // ⬅️ import the service
import '../../data/diseases_treatments.dart'; // ⬅️ import diseases treatments database

/// Final payload shown on the results screen.
class DetectionResult {
  final String prediction;   // e.g. "blister blight - 0.84"
  final String imagePath;    // annotated image path (or original on failure)
  const DetectionResult(this.prediction, this.imagePath);
}

class ResultPage extends ConsumerStatefulWidget {
  final Future<DetectionResult> future;
  const ResultPage({super.key, required this.future});

  @override
  ConsumerState<ResultPage> createState() => _ResultPageState();
}

const String kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

final _model = GenerativeModel(
  model: "gemini-2.5-flash",
  apiKey: kGeminiApiKey,
);

class _ResultPageState extends ConsumerState<ResultPage> {
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
      // Use diseases database for treatment recommendations
      // Handle multiple diseases (comma-separated) and remove confidence scores
      final cleanLabel = _label!.split('-').first.trim(); // Remove confidence score if present
      final diseases = cleanLabel.split(',').map((d) => d.trim()).toList();
      final buffer = StringBuffer();
      final localizations = AppLocalizations.of(context);
      
      for (int i = 0; i < diseases.length; i++) {
        // Remove any trailing confidence scores from individual diseases
        final disease = diseases[i].split('-').first.trim();
        final localizedTreatment = DiseasesTreatmentsDB.getLocalizedTreatment(disease, localizations);
        
        if (localizedTreatment != null) {
          if (diseases.length > 1 && i > 0) {
            buffer.writeln('\n');
          }
          buffer.writeln('**${localizedTreatment.disease}**\n');
          for (int j = 0; j < localizedTreatment.treatments.length; j++) {
            buffer.writeln('${j + 1}. ${localizedTreatment.treatments[j]}');
          }
        } else {
          // If disease not found in database, provide generic advice
          if (diseases.length > 1 && i > 0) {
            buffer.writeln('\n');
          }
          buffer.writeln('**$disease**\n');
          buffer.writeln(localizations?.translate('treatmentNotAvailable') ?? 
                        'Treatment information not available for this condition. Please consult with a tea cultivation expert or use the "Ask More Questions" feature for detailed advice.');
        }
      }
      
      final txt = buffer.toString().trim();
      if (mounted) {
        setState(() => _advice = txt.isEmpty ? (localizations?.noRecommendationsAvailable ?? 'No recommendations available') : txt);
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() => _advice = '${localizations?.errorLoadingRecommendations ?? 'Error loading recommendations'}: $e');
      }
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
    // Watch locale to trigger rebuild on language change
    ref.watch(localeProvider);
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
              localizations?.detectionResults ?? 'Detection Results',
              style: const TextStyle(
                color: Colors.white,
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            localizations?.analyzing ?? 'Analyzing...',
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
                );
              }
              if (snap.hasError || !snap.hasData) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(context);
                                return Text(
                                  localizations?.detectionFailed ?? 'Detection Failed',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(context);
                                return Text(
                                  snap.error?.toString() ?? (localizations?.unknownErrorOccurred ?? 'Unknown error occurred'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                              label: Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(context);
                                  return Text(localizations?.goBack ?? 'Go back');
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              final res = snap.data!;
              final parsed = _parsePrediction(res.prediction);
              _label ??= parsed.$1.isEmpty ? 'Unknown' : parsed.$1;
              _conf ??= parsed.$2;

              // Kick off advice load once
              if (_advice == null && !_loadingAdvice) {
                // microtask avoids setState during build warning
                Future.microtask(_loadAdvice);
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              
                  children: [
                    // Image card with overlay label - zoomable
                    Card(
                      elevation: 12,
                      shadowColor: Colors.black.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            width: double.infinity,
                            child: InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: Image.file(
                                File(res.imagePath),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 48)),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.center,
                                    colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            top: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _labelColor(_label!).withOpacity(0.95),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _label!.toLowerCase().contains('healthy') ? Icons.eco : Icons.warning_amber_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _label!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Zoom hint
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Builder(
                                    builder: (context) {
                                      final localizations = AppLocalizations.of(context);
                                      return Text(
                                        localizations?.pinchToZoom ?? 'Pinch to zoom',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_conf != null)
                      Card(
                        elevation: 6,
                        shadowColor: Colors.black.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Colors.grey.shade50,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: _labelColor(_label!).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Icon(
                                          Icons.analytics,
                                          color: _labelColor(_label!),
                                          size: 10,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Builder(
                                        builder: (context) {
                                          final localizations = AppLocalizations.of(context);
                                          return Text(
                                            localizations?.detectionAccuracy ?? 'Detection Accuracy',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _labelColor(_label!).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _labelColor(_label!).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '${(_conf! * 100).round()}%',
                                      style: TextStyle(
                                        color: _labelColor(_label!),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: _conf!.clamp(0, 1),
                                  minHeight: 4,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(_labelColor(_label!)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Prediction text
                    Card(
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _labelColor(_label!).withOpacity(0.1),
                              _labelColor(_label!).withOpacity(0.05),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              _label!.toLowerCase().contains('healthy') ? Icons.eco : Icons.warning_rounded,
                              color: _labelColor(_label!),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _label!,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _labelColor(_label!),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🔹 Auto-recommendation + Ask more
                    Card(
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              Colors.grey.shade50,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.medical_services,
                                    color: Colors.blue.shade700,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final localizations = AppLocalizations.of(context);
                                      return Text(
                                        localizations?.recommendedTreatment ?? 'Recommended Treatment',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                          color: Colors.black87,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_loadingAdvice)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Column(
                                  children: [
                                    const LinearProgressIndicator(minHeight: 6),
                                    const SizedBox(height: 12),
                                    Builder(
                                      builder: (context) {
                                        final localizations = AppLocalizations.of(context);
                                        return Text(
                                          localizations?.gettingRecommendations ?? 'Getting recommendations...',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final localizations = AppLocalizations.of(context);
                                    return Text(
                                      _advice ?? (localizations?.noRecommendationsAvailable ?? 'No recommendations available'),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey.shade800,
                                        height: 1.5,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                                label: Builder(
                                  builder: (context) {
                                    final localizations = AppLocalizations.of(context);
                                    return Text(
                                      localizations?.askMoreQuestions ?? 'Ask More Questions',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _label == null ? null : _openChat,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                     const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white, size: 22),
                                const SizedBox(width: 8),
                                Builder(
                                  builder: (context) {
                                    final localizations = AppLocalizations.of(context);
                                    return Text(
                                      localizations?.done ?? 'Done',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
                padding: const EdgeInsets.all(16),
                itemCount: _msgs.length,
                itemBuilder: (_, i) {
                  final m = _msgs[i]; final isUser = m['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        gradient: isUser
                            ? LinearGradient(
                                colors: [Colors.green.shade600, Colors.green.shade700],
                              )
                            : null,
                        color: isUser ? null : Colors.grey.shade100,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isUser ? 18 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        m['content']!,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 15,
                          height: 1.4,
                        ),
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
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)?.askAboutTreatment ?? 'Ask about treatment…',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.green.shade400, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (v) { _ctrl.clear(); _send(v); },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _busy
                              ? [Colors.grey.shade400, Colors.grey.shade500]
                              : [Colors.green.shade600, Colors.green.shade700],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _busy
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _busy
                              ? null
                              : () {
                                  final v = _ctrl.text;
                                  _ctrl.clear();
                                  _send(v);
                                },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.send, size: 22, color: Colors.white),
                          ),
                        ),
                      ),
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
