import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

Future<(GeoPoint?, String?)> getScanLocation() async {
  // 1) Request/check permission
  LocationPermission perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
    return (null, null); // user said no — save without location
  }

  // 2) Get position
  final pos = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.best,
  );
  final geo = GeoPoint(pos.latitude, pos.longitude);

  // 3) Reverse geocode (optional)
  try {
    final placemarks = await gc.placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (placemarks.isNotEmpty) {
      final p = placemarks.first;
      final name = [
        p.name,
        p.subLocality,
        p.locality,
        p.administrativeArea,
        p.country
      ].where((e) => (e != null && e.trim().isNotEmpty)).join(', ');
      return (geo, name);
    }
  } catch (_) {
    // ignore reverse geocode errors
  }
  return (geo, null);
}


Future<void> _openMaps(double lat, double lng) async {
  final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    // fallback noop
  }
}
