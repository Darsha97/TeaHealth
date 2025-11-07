import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_provider.dart';
import 'history_service.dart';
import 'location_service.dart';
import '../../data/diseases_treatments.dart';
import 'tea_doctor_ai.dart';

class DetectionPreviewPage extends ConsumerStatefulWidget {
  const DetectionPreviewPage({
    super.key,
    required this.image,
    required this.label,
    this.refinedImage,
    this.refinedLabel,
    this.refinedResults,
    this.initialResults,
    this.confidence,
  });

  final File image;
  final String label;
  final Future<File?>? refinedImage;
  final Future<String>? refinedLabel;
  final Future<List<Map<String, dynamic>>>? refinedResults;
  final List<Map<String, dynamic>>? initialResults;
  final double? confidence;

  @override
  ConsumerState<DetectionPreviewPage> createState() => _DetectionPreviewPageState();
}

class _DetectionPreviewPageState extends ConsumerState<DetectionPreviewPage> {
  bool _saving = false;
  bool _saved = false;
  String? _displayLabel;
  double? _displayConf;
  String? _advice;
  bool _loadingAdvice = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() async {
    // Get the final label (refined or initial)
    if (widget.refinedLabel != null) {
      final refined = await widget.refinedLabel;
      _displayLabel = refined ?? widget.label;
    } else {
      _displayLabel = widget.label;
    }

    // Calculate confidence from results if available
    double? conf = widget.confidence;
    List<Map<String, dynamic>>? resultsToUse = widget.initialResults;
    if (widget.refinedResults != null) {
      final refinedRes = await widget.refinedResults;
      if (refinedRes != null && refinedRes.isNotEmpty) {
        resultsToUse = refinedRes;
      }
    }

    if (resultsToUse != null && resultsToUse.isNotEmpty) {
      double sum = 0.0;
      int count = 0;
      for (final r in resultsToUse) {
        final box = r['box'];
        double c = 0.0;
        if (box is List && box.length >= 5 && box[4] is num) {
          c = (box[4] as num).toDouble();
        } else {
          final v = r['confidence'] ?? r['score'] ?? r['prob'];
          c = (v is num) ? v.toDouble() : 0.0;
        }
        if (c > 0) {
          sum += c;
          count++;
        }
      }
      conf = count > 0 ? (sum / count) : widget.confidence;
    }

    if (mounted) {
      setState(() {
        _displayConf = conf;
      });
      if (_displayLabel != null && !_loadingAdvice) {
        Future.microtask(_loadAdvice);
      }
    }
  }

  Color _labelColor(String label) {
    final l = label.toLowerCase();
    if (l.contains('healthy') || l.contains('normal')) return Colors.green;
    return Colors.redAccent;
  }

  Future<void> _loadAdvice() async {
    if (_displayLabel == null) return;
    setState(() => _loadingAdvice = true);
    try {
      // Use diseases database for treatment recommendations
      final cleanLabel = _displayLabel!.split('-').first.trim();
      final diseases = cleanLabel.split(',').map((d) => d.trim()).toList();
      final buffer = StringBuffer();
      final localizations = AppLocalizations.of(context);
      
      for (int i = 0; i < diseases.length; i++) {
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
          if (diseases.length > 1 && i > 0) {
            buffer.writeln('\n');
          }
          buffer.writeln('**$disease**\n');
          buffer.writeln(localizations?.translate('treatmentNotAvailable') ?? 
                        'Treatment information not available for this condition. Please consult with a tea cultivation expert.');
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
    if (_displayLabel == null) return;

    final chat = TeaDoctorAI.instance().startChat(
      label: _displayLabel!,
      confidence: _displayConf,
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

  Future<void> _saveToHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations?.pleaseLoginToSaveScans ?? 'Please log in to save scans')),
        );
      }
      return;
    }

    setState(() => _saving = true);

    try {
      // Wait for refined image if available, otherwise use initial
      File? imageToSave = widget.image;
      String labelToSave = _displayLabel ?? widget.label;
      double? confidenceToSave = _displayConf ?? widget.confidence;

      if (widget.refinedImage != null) {
        final refined = await widget.refinedImage;
        if (refined != null) {
          imageToSave = refined;
        }
      }

      if (widget.refinedLabel != null) {
        final refinedLabel = await widget.refinedLabel;
        if (refinedLabel != null && refinedLabel.isNotEmpty) {
          labelToSave = refinedLabel;
        }
      }

      // Use refined results if available for better confidence calculation
      List<Map<String, dynamic>>? resultsToUse = widget.initialResults;
      if (widget.refinedResults != null) {
        final refinedRes = await widget.refinedResults;
        if (refinedRes != null && refinedRes.isNotEmpty) {
          resultsToUse = refinedRes;
        }
      }

      // Recalculate confidence from results if available
      if (resultsToUse != null && resultsToUse.isNotEmpty) {
        double sum = 0.0;
        int count = 0;
        for (final r in resultsToUse) {
          final box = r['box'];
          double conf = 0.0;
          if (box is List && box.length >= 5 && box[4] is num) {
            conf = (box[4] as num).toDouble();
          } else {
            final v = r['confidence'] ?? r['score'] ?? r['prob'];
            conf = (v is num) ? v.toDouble() : 0.0;
          }
          if (conf > 0) {
            sum += conf;
            count++;
          }
        }
        confidenceToSave = count > 0 ? (sum / count) : widget.confidence;
      }

      // Get location
      final (geo, locName) = await getScanLocation();

      // Save to history
      await HistoryService().saveScan(
        uid: user.uid,
        imageFile: imageToSave,
        label: labelToSave,
        confidence: confidenceToSave,
        source: 'live',
        geo: geo,
        locName: locName,
      );

      if (mounted) {
        setState(() => _saved = true);
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations?.scanSavedToHistory ?? 'Scan saved to history'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations?.failedToSave ?? 'Failed to save'}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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
          child: FutureBuilder<File?>(
            future: widget.refinedImage,
            builder: (context, imageSnap) {
              final displayImage = imageSnap.data ?? widget.image;
              final displayLabel = _displayLabel ?? widget.label;
              final displayConf = _displayConf ?? widget.confidence;

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
                              displayImage,
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
                              color: _labelColor(displayLabel).withOpacity(0.95),
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
                                  displayLabel.toLowerCase().contains('healthy') ? Icons.eco : Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    displayLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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

                  // Detection Accuracy Box
                  if (displayConf != null)
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
                                        color: _labelColor(displayLabel).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Icon(
                                        Icons.analytics,
                                        color: _labelColor(displayLabel),
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
                                    color: _labelColor(displayLabel).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _labelColor(displayLabel).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '${(displayConf * 100).round()}%',
                                    style: TextStyle(
                                      color: _labelColor(displayLabel),
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
                                value: displayConf.clamp(0, 1),
                                minHeight: 4,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(_labelColor(displayLabel)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

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
                            _labelColor(displayLabel).withOpacity(0.1),
                            _labelColor(displayLabel).withOpacity(0.05),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            displayLabel.toLowerCase().contains('healthy') ? Icons.eco : Icons.warning_rounded,
                            color: _labelColor(displayLabel),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              displayLabel,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _labelColor(displayLabel),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Recommended Treatment Section
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
                              onPressed: _displayLabel == null ? null : _openChat,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 2),
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
                              onTap: _saving || _saved ? null : _saveToHistory,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_saving)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    else
                                      Icon(
                                        _saved ? Icons.check_circle : Icons.save,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Builder(
                                        builder: (context) {
                                          final localizations = AppLocalizations.of(context);
                                          return Text(
                                            _saved ? (localizations?.saved ?? 'Saved') : (localizations?.save ?? 'Save'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 2),
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
                              onTap: () => Navigator.of(context).pop('rescan'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Builder(
                                        builder: (context) {
                                          final localizations = AppLocalizations.of(context);
                                          return Text(
                                            localizations?.scanAgain ?? 'Scan Again',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
