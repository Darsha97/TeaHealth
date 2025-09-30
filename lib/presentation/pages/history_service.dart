// history_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
// Optional compression utils below – see section 3

class HistoryItem {
  final String id;
  final String imageB64;          // <-- Base64 image data
  final String label;
  final double? confidence;
  final DateTime createdAt;
  final String source;            // "image" | "video"
  final GeoPoint? geo;     // <-- added
  final String? locName;

  HistoryItem({
    required this.id,
    required this.imageB64,
    required this.label,
    required this.createdAt,
    this.confidence,
    this.source = 'image',
    this.geo,
    this.locName,
  });

  factory HistoryItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    final ts = data['createdAt'];
    final created = ts is Timestamp
        ? ts.toDate()
        : DateTime.fromMillisecondsSinceEpoch(
            (data['createdAtMs'] as int?) ?? DateTime.now().millisecondsSinceEpoch);

    return HistoryItem(
      id: d.id,
      imageB64: (data['imageB64'] ?? data['imageData'] ?? '') as String, // support either key
      label: (data['label'] ?? 'Unknown') as String,
      confidence: (data['confidence'] is num) ? (data['confidence'] as num).toDouble() : null,
      createdAt: created,
      source: (data['source'] ?? 'image') as String,
      geo: data['geo'] as GeoPoint?,              // <-- read
      locName: data['locName'] as String?,        // <-- read
    );
  }
}

class HistoryService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _scansCol(String uid) =>
      _db.collection('users').doc(uid).collection('scans');

  /// Firestore-only: reads the file, (optionally compresses), writes Base64 to Firestore.
  Future<String> saveScan({
    required String uid,
    required File imageFile,
    required String label,
    double? confidence, // 0..1
    String source = 'image',
    GeoPoint? geo,           // <-- added
    String? locName,         // <-- added
  }) async {
    final docRef = _scansCol(uid).doc();

    // --- Read & (optionally) compress ---
    final bytes = await imageFile.readAsBytes();
    // If you add compression (section 3), replace the next line with: final bytes = await _compress(bytes);
    final b64 = base64Encode(bytes);

    // --- Write Firestore doc ---
    await docRef.set({
      'imageB64': b64,                      // store image here
      'label': label,
      'confidence': confidence,
      'source': source,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      'geo': geo,            // GeoPoint(lat, lng)
      'locName': locName,    // readable place
    });

    return docRef.id;
  }

  Stream<List<HistoryItem>> streamScans(String uid, {int limit = 100}) {
    return _scansCol(uid)
        .orderBy('createdAt', descending: true) // or 'createdAtMs'
        .limit(limit)
        .snapshots()
        .map((qs) => qs.docs.map((d) => HistoryItem.fromDoc(d)).toList());
  }

  Future<void> deleteScan({required String uid, required String id}) async {
    await _scansCol(uid).doc(id).delete(); // nothing to delete in Storage anymore
  }
}
