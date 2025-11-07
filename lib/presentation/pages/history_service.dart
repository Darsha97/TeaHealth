// history_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

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

  /// Compress image to stay under Firestore's 1MB limit per field
  /// Target: max 800KB (base64 encoded) to leave headroom
  Future<Uint8List> _compressImage(Uint8List originalBytes) async {
    try {
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) return originalBytes;

      // Target dimensions: max 1200px on longest side (maintains aspect ratio)
      const maxDimension = 1200;
      img.Image resized = decoded;
      if (decoded.width > maxDimension || decoded.height > maxDimension) {
        if (decoded.width >= decoded.height) {
          resized = img.copyResize(decoded, width: maxDimension);
        } else {
          resized = img.copyResize(decoded, height: maxDimension);
        }
      }

      // Encode with quality 75 (good balance between size and quality)
      // Keep reducing quality until under ~600KB raw (which becomes ~800KB base64)
      int quality = 75;
      Uint8List compressed = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      
      // If still too large, reduce quality further
      while (compressed.length > 600000 && quality > 30) {
        quality -= 10;
        compressed = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      }

      // If still too large, resize more aggressively
      if (compressed.length > 600000) {
        const aggressiveMax = 800;
        if (decoded.width >= decoded.height) {
          resized = img.copyResize(decoded, width: aggressiveMax);
        } else {
          resized = img.copyResize(decoded, height: aggressiveMax);
        }
        compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 65));
      }

      return compressed;
    } catch (e) {
      // If compression fails, return original (will fail if too large, but at least we tried)
      return originalBytes;
    }
  }

  /// Firestore-only: reads the file, compresses it, writes Base64 to Firestore.
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

    // --- Read & compress ---
    final originalBytes = await imageFile.readAsBytes();
    final compressedBytes = await _compressImage(originalBytes);
    final b64 = base64Encode(compressedBytes);

    // Check if still too large (1MB base64 limit ≈ 750KB raw)
    if (b64.length > 1000000) {
      throw Exception('Image too large even after compression: ${(b64.length / 1024).toStringAsFixed(1)}KB');
    }

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
