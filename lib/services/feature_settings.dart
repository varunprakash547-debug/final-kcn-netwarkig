import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/collections.dart';

class FeatureSettings {
  FeatureSettings._();
  static final instance = FeatureSettings._();

  static const Map<String, bool> defaults = {
    'registrationEnabled': true,
    'advertisementsEnabled': true,
    'adMobEnabled': true,
    'appUpdateChecksEnabled': true,
    'farmerProductsEnabled': true,
    'farmerGroupsEnabled': true,
    'farmerOrdersEnabled': true,
    'farmerNetworkEnabled': true,
    'farmerCreditEnabled': true,
    'kendraCreditEnabled': true,
    'kendraPaymentEnabled': true,
    'kendraOutstandingEnabled': true,
    'kendraLedgerEnabled': true,
    'kendraSearchEnabled': true,
    'kendraBackdateEnabled': true,
    'kendraFollowupEnabled': true,
    'callOrdersEnabled': true,
    'callMembersEnabled': true,
    'callRewardsEnabled': true,
    'callFollowupEnabled': true,
    'networkOrderingEnabled': true,
    'networkRewardsEnabled': true,
  };

  DocumentReference<Map<String, dynamic>> get ref =>
      FirebaseFirestore.instance.collection(Collections.settings).doc('features');

  Stream<Map<String, bool>> stream() {
    return ref.snapshots().map((snapshot) {
      final data = snapshot.data() ?? <String, dynamic>{};
      return readMap(data);
    });
  }

  Map<String, bool> readMap(Map<String, dynamic> data) {
    final result = <String, bool>{...defaults};
    for (final entry in defaults.keys) {
      final value = data[entry];
      if (value is bool) result[entry] = value;
    }
    return result;
  }

  Future<bool> isEnabled(String key) async {
    final snapshot = await ref.get();
    final data = readMap(snapshot.data() ?? const <String, dynamic>{});
    return data[key] ?? true;
  }

  Future<void> save(Map<String, bool> values) async {
    await ref.set({
      ...values,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class FeatureGate extends StatelessWidget {
  const FeatureGate({
    required this.featureKey,
    required this.child,
    super.key,
    this.title,
  });

  final String featureKey;
  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, bool>>(
      stream: FeatureSettings.instance.stream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return child;
        final enabled = snapshot.data?[featureKey] ?? FeatureSettings.defaults[featureKey] ?? true;
        if (enabled) return child;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pause_circle_outline, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      title ?? 'This feature is currently unavailable',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'KCN Admin has temporarily turned off this option. Please try again later.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
