 
import 'dart:io';
import 'package:image/image.dart' as img;

Future<File> renderDetectionsOnImage(
  File imageFile,
  List<dynamic> detections,
) async {
  final bytes = await imageFile.readAsBytes();

  // Decode + BAKE EXIF so pixels == what we draw on
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Failed to decode image');
  final im = img.bakeOrientation(decoded);

  int _clamp(int v, int min, int max) => v < min ? min : (v > max ? max : v);

  List<int> _toLTRBBox(List<dynamic> box, int imgW, int imgH) {
    final raw = box.take(4).map((e) => (e as num).toDouble()).toList();
    double x1 = raw[0], y1 = raw[1], x2 = raw[2], y2 = raw[3];

    int fx(double v, int max) => v.isNaN ? 0 : _clamp(v.floor(), 0, max - 1);
    int cx(double v, int max) => v.isNaN ? 0 : _clamp(v.ceil(), 0, max - 1);

    return [fx(x1, imgW), fx(y1, imgH), cx(x2, imgW), cx(y2, imgH)];
  }

   final white = img.getColor(255, 255, 255);
  final font  = img.arial_24;      // larger label text
  const int padX = 6, padY = 4;
  const int barH = 32;      

  for (final raw in detections) {
    if (raw is! Map) continue;
    final det = raw;

    final boxList = det['box'];
    if (boxList is! List || boxList.length < 4) continue;

    final ltrb = _toLTRBBox(boxList, im.width, im.height);
    int x1 = ltrb[0], y1 = ltrb[1], x2 = ltrb[2], y2 = ltrb[3];
    if (x2 <= x1 || y2 <= y1) continue;

    final tag = (det['tag'] ?? det['label'] ?? 'obj').toString();
    final col = _paletteColor(tag);

    // 1) Box (positional API)
    _drawThickRect(im, x1: x1, y1: y1, x2: x2 - 1, y2: y2 - 1, color: col, thickness:5);

    // 2) Compose label text
    double? conf;
    if (boxList.length >= 5 && boxList[4] is num) conf = (boxList[4] as num).toDouble();
    conf ??= (det['confidence'] ?? det['score'] ?? det['prob']) is num
        ? (det['confidence'] ?? det['score'] ?? det['prob']).toDouble()
        : null;
    final text = conf == null ? tag : '$tag ${conf.toStringAsFixed(2)}';

    // Bar across the box (no font.height needed)
    final top = _clamp(y1 - barH - 2, 0, im.height - barH);
    img.fillRect(im, x1, top, x2, top + barH, _withAlpha(col, 220));

    // 4) Text (named color OK in v3)
    // Text
    img.drawString(im, font, x1 + padX, top + padY, text, color: white);
  }

  final out = File(
    '${Directory.systemTemp.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  await out.writeAsBytes(img.encodeJpg(im, quality: 90), flush: true);
  return out;
}

// ----- helpers -----

void _drawThickRect(
  img.Image dst, {
  required int x1,
  required int y1,
  required int x2,
  required int y2,
  required int color,
  int thickness = 3,
}) {
  for (int t = 0; t < thickness; t++) {
    // positional: x1, y1, x2, y2, color
    img.drawRect(dst, x1 - t, y1 - t, x2 + t, y2 + t, color);
  }
}

int _withAlpha(int color, int a) {
  final r = img.getRed(color), g = img.getGreen(color), b = img.getBlue(color);
  return img.getColor(r, g, b, a);
}

int _paletteColor(String label) {
  switch (label.toLowerCase()) {
    case 'healthy': return img.getColor(255, 77, 77);
    case 'magnesium': return img.getColor(204, 51, 255);
    case 'potassium': return img.getColor(0, 204, 255);
    case 'blister blight': return img.getColor(0, 180, 255);
    default: return _hashColor(label);
  }
}

int _hashColor(String s) {
  final h = s.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x00FFFFFF);
  return img.getColor((h >> 16) & 0xFF, (h >> 8) & 0xFF, h & 0xFF);
}
