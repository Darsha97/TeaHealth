import 'package:google_generative_ai/google_generative_ai.dart';

const _system = '''
You are Tea Doctor for tea leaf diseases.
Return concise, actionable guidance. If healthy: monitoring + hygiene.
If disease: 3–5 treatment steps with typical % rates when common.
ALWAYS remind to follow local labels (PHI/REI) and rotate FRAC groups.
If confidence < 0.6, suggest verification/rescan. Keep under ~180 words.
''';

class TeaDoctorAI {
  TeaDoctorAI._(this._model);
  final GenerativeModel _model;

  static TeaDoctorAI? _i;
  static TeaDoctorAI instance() {
    if (_i != null) return _i!;
    const key = String.fromEnvironment('GEMINI_API_KEY');
    if (key.isEmpty) {
      throw StateError('GEMINI_API_KEY missing. Run with --dart-define.');
    }
    final model = GenerativeModel(
      model: "gemini-2.5-flash",
      apiKey: key,
      systemInstruction: Content.text(_system),
    );
    _i = TeaDoctorAI._(model);
    return _i!;
  }

  Future<String> advice({
    required String label,
    double? confidence,
    double? lat,
    double? lng,
    String? locName,
  }) async {
    final prompt = '''
Scan:
- Label: $label
- Confidence: ${confidence ?? 'n/a'}
- Location: ${locName ?? ((lat!=null&&lng!=null) ? '$lat,$lng' : 'unknown')}

Return:
- Title (one line)
- 3–5 bullet steps
- Caution line (PHI/REI + FRAC)
- If low confidence, add "Verification" line
''';
    final r = await _model.generateContent([Content.text(prompt)]);
    return r.text?.trim() ?? 'No advice available.';
  }

  TeaDoctorChat startChat({
    required String label,
    double? confidence,
    double? lat,
    double? lng,
    String? locName,
  }) {
    final ctx = '''
Context:
- Label: $label
- Confidence: ${confidence ?? 'n/a'}
- Location: ${locName ?? ((lat!=null&&lng!=null) ? '$lat,$lng' : 'unknown')}
''';
    final session = _model.startChat(history: [Content.text(ctx)]);
    return TeaDoctorChat._(session);
  }
}

class TeaDoctorChat {
  TeaDoctorChat._(this._chat);
  final ChatSession _chat;

  Future<String> send(String userMessage) async {
    final r = await _chat.sendMessage(Content.text(userMessage));
    return r.text?.trim() ?? 'No reply.';
  }
}
