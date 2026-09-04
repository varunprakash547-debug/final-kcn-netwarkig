import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  UpdateService._();
  static final instance = UpdateService._();

  Future<Map<String, dynamic>?> config() async {
    final doc = await FirebaseFirestore.instance
        .collection('app_settings_v3')
        .doc('app_update')
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<bool> isUpdateAvailable() async {
    final data = await config();
    if (data == null) return false;
    final minVersion = data['minVersion']?.toString() ?? '';
    if (minVersion.isEmpty) return false;
    final info = await PackageInfo.fromPlatform();
    return _compare(info.version, minVersion) < 0;
  }

  int _compare(String a, String b) {
    final av = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bv = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < av.length ? av[i] : 0;
      final y = i < bv.length ? bv[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  Future<void> openUpdateTarget(Map<String, dynamic> data) async {
    final url = kIsWeb
        ? (data['webUrl']?.toString() ?? '')
        : (data['androidUrl']?.toString() ?? '');
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
