import 'package:flutter/material.dart';

import '../../services/feature_settings.dart';

class AdminFeatureSettings extends StatefulWidget {
  const AdminFeatureSettings({super.key});

  @override
  State<AdminFeatureSettings> createState() => _AdminFeatureSettingsState();
}

class _AdminFeatureSettingsState extends State<AdminFeatureSettings> {
  late Map<String, bool> values = <String, bool>{...FeatureSettings.defaults};
  bool loading = true;
  bool saving = false;

  static const sections = <String, List<Map<String, String>>>{
    'General': [
      {'key': 'registrationEnabled', 'title': 'New registrations', 'hint': 'Allow new Farmer, Kendra and Call Center account creation.'},
      {'key': 'advertisementsEnabled', 'title': 'KCN advertisements', 'hint': 'Show your KCN advertisements to active users.'},
      {'key': 'adMobEnabled', 'title': 'Google AdMob', 'hint': 'Allow AdMob ads on supported mobile screens.'},
      {'key': 'appUpdateChecksEnabled', 'title': 'App update check', 'hint': 'Allow the app to check the Admin-configured minimum version.'},
    ],
    'Farmer': [
      {'key': 'farmerProductsEnabled', 'title': 'Company Products', 'hint': 'Show the company product catalogue.'},
      {'key': 'farmerGroupsEnabled', 'title': 'Product Groups', 'hint': 'Show product group offers.'},
      {'key': 'farmerOrdersEnabled', 'title': 'My Orders', 'hint': 'Allow farmers to view their network orders.'},
      {'key': 'farmerNetworkEnabled', 'title': 'My Network', 'hint': 'Show the farmer network/tree area.'},
      {'key': 'farmerCreditEnabled', 'title': 'My Credit', 'hint': 'Show the farmer credit summary.'},
      {'key': 'networkOrderingEnabled', 'title': 'Network ordering', 'hint': 'Allow farmers to place product and group orders.'},
      {'key': 'networkRewardsEnabled', 'title': 'Network rewards', 'hint': 'Allow reward features to be displayed after eligible sales.'},
    ],
    'Krishi Kendra': [
      {'key': 'kendraCreditEnabled', 'title': 'Credit entry', 'hint': 'Allow Kendra credit operations.'},
      {'key': 'kendraPaymentEnabled', 'title': 'Payment entry', 'hint': 'Allow Kendra payment operations.'},
      {'key': 'kendraOutstandingEnabled', 'title': 'Outstanding', 'hint': 'Show outstanding bills.'},
      {'key': 'kendraLedgerEnabled', 'title': 'Ledger', 'hint': 'Show bill-wise ledger and payment history.'},
      {'key': 'kendraSearchEnabled', 'title': 'KCN Search', 'hint': 'Allow Kendra KCN search and permission requests.'},
      {'key': 'kendraBackdateEnabled', 'title': 'Back-Date', 'hint': 'Allow approved Kendra back-date entry workflow.'},
      {'key': 'kendraFollowupEnabled', 'title': 'Payment Follow-up', 'hint': 'Allow Kendra collection follow-up requests.'},
    ],
    'Call Center': [
      {'key': 'callOrdersEnabled', 'title': 'Network Orders', 'hint': 'Allow network order operations.'},
      {'key': 'callMembersEnabled', 'title': 'Network Members', 'hint': 'Allow network member operations.'},
      {'key': 'callRewardsEnabled', 'title': 'Rewards', 'hint': 'Allow reward support operations.'},
      {'key': 'callFollowupEnabled', 'title': 'Payment Follow-up', 'hint': 'Allow payment follow-up operations.'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final map = await FeatureSettings.instance.ref.get();
      if (!mounted) return;
      setState(() {
        values = FeatureSettings.instance.readMap(map.data() ?? {});
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to load settings. $e')));
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await FeatureSettings.instance.save(values);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App feature settings saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save settings. $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _confirmDisable(String title, String key, bool next) async {
    if (next) {
      setState(() => values[key] = true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Turn off $title?'),
        content: const Text('This will hide/disable this feature for the applicable users. Existing records are not deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep On')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Turn Off')),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => values[key] = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('App Feature Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text('Admin can turn supported app options on or off for all applicable users. Turning an option off does not delete existing data.'),
          ),
        ),
        const SizedBox(height: 12),
        for (final section in sections.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(section.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Card(
            child: Column(
              children: [
                for (final item in section.value)
                  SwitchListTile.adaptive(
                    value: values[item['key']] ?? true,
                    onChanged: saving ? null : (v) => _confirmDisable(item['title']!, item['key']!, v),
                    title: Text(item['title']!),
                    subtitle: Text(item['hint']!),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? 'Saving...' : 'Save All Settings'),
        ),
      ],
    );
  }
}
