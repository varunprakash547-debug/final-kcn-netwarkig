import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/app_theme.dart';
import 'core/collections.dart';
import 'services/auth_service.dart';
import 'services/ad_service.dart';
import 'services/credit_service.dart';
import 'services/update_service.dart';
import 'services/feature_settings.dart';
import 'services/notification_service.dart';
import 'screens/admin/admin_feature_settings.dart';

class KcnApp extends StatelessWidget {
  const KcnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Krishi Credit Network',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppGate(),
    );
  }
}

class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.hasData ? const RoleGate() : const LoginScreen();
      },
    );
  }
}

class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    final email = AuthService.instance.currentUser?.email?.toLowerCase() ?? '';
    if (uid == null) return const LoginScreen();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection(Collections.users).doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const MissingProfileScreen();
        }
        final data = snapshot.data!.data() ?? {};
        final role = data['role']?.toString() ?? '';
        final status = data['status']?.toString() ?? 'pending';
        final isActive = data['isActive'] == true;

        if (email == 'varunprakash547@gmail.com' &&
            (role == 'super_admin' || role == 'superAdmin')) {
          return const AdminDashboard();
        }
        if (!isActive || !(status == 'active' || status == 'approved')) {
          return PendingScreen(status: status);
        }

        switch (role) {
          case 'farmer':
            return const FarmerDashboard();
          case 'krishiKendra':
            return const KendraDashboard();
          case 'callCenter':
            return const CallCenterDashboard();
          case 'superAdmin':
          case 'super_admin':
          case 'admin':
            return const AdminDashboard();
          default:
            return const MissingProfileScreen();
        }
      },
    );
  }
}

class PendingScreen extends StatelessWidget {
  const PendingScreen({required this.status, super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final rejected = status == 'rejected';
    return Scaffold(
      appBar: AppBar(title: const Text('KCN Account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(rejected ? Icons.block : Icons.hourglass_top, size: 64),
                  const SizedBox(height: 14),
                  Text(
                    rejected ? 'Account rejected' : 'Account awaiting approval',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    rejected
                        ? 'Please contact KCN support for the next step.'
                        : 'Your account has been created. KCN approval is required before using this role.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: AuthService.instance.signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MissingProfileScreen extends StatelessWidget {
  const MissingProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KCN')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_outlined, size: 56),
                const SizedBox(height: 12),
                const Text('KCN profile not found.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: AuthService.instance.signOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class LegalSupportPage extends StatelessWidget {
  const LegalSupportPage({super.key});

  static const privacyUrl = 'https://thekcn.in/privacy-policy.html';
  static const termsUrl = 'https://thekcn.in/terms.html';
  static const deleteUrl = 'https://thekcn.in/delete-account.html';
  static const supportUrl = 'https://thekcn.in/support.html';
  static const aboutUrl = 'https://thekcn.in/about.html';
  static const supportEmail = 'support@thekcn.in';

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open $url')),
      );
    }
  }

  Future<void> _emailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': 'KCN Support Request'},
    );
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open email application.')),
      );
    }
  }

  Widget _linkTile(BuildContext context, IconData icon, String title, String subtitle, String url) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _open(context, url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Krishi Credit Network', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'KCN provides farmer credit management, network commerce and related support services. '
            'Please review the legal documents before using the service.',
          ),
          const SizedBox(height: 16),
          _linkTile(context, Icons.privacy_tip_outlined, 'Privacy Policy', 'How KCN collects, uses and protects information.', privacyUrl),
          _linkTile(context, Icons.gavel_outlined, 'Terms & Conditions', 'Terms governing use of KCN services.', termsUrl),
          _linkTile(context, Icons.delete_outline, 'Delete Account', 'Request deletion of your account and eligible associated data.', deleteUrl),
          _linkTile(context, Icons.support_agent_outlined, 'Support', 'Get help from KCN support.', supportUrl),
          _linkTile(context, Icons.info_outline, 'About KCN', 'Company and app information.', aboutUrl),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email Support'),
              subtitle: const Text(supportEmail),
              trailing: const Icon(Icons.send_outlined),
              onTap: () => _emailSupport(context),
            ),
          ),
          const SizedBox(height: 12),
          const InfoBanner(
            text: 'Privacy, security and consent settings are subject to applicable laws and regulations. '
                 'KCN does not represent a government/CIBIL credit report service unless separately authorized.',
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      _msg('Enter email and password.');
      return;
    }
    setState(() => loading = true);
    try {
      await AuthService.instance.signIn(email.text, password.text);
    } on FirebaseAuthException catch (e) {
      _msg(_authError(e));
    } catch (e) {
      _msg(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _reset() async {
    if (email.text.trim().isEmpty) {
      _msg('Enter your email first.');
      return;
    }
    try {
      await AuthService.instance.resetPassword(email.text);
      _msg('Password reset link sent.');
    } catch (e) {
      _msg(e.toString());
    }
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text.replaceFirst('Exception: ', ''))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Krishi Credit Network'),
        actions: [
          IconButton(
            tooltip: 'Legal & Support',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalSupportPage())),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.eco, size: 72),
                    const SizedBox(height: 8),
                    Text('Krishi Credit Network', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text('Email + Password Login ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ No OTP', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email ID', prefixIcon: Icon(Icons.email_outlined))),
                    const SizedBox(height: 14),
                    TextField(
                      controller: password,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility : Icons.visibility_off)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: TextButton(onPressed: loading ? null : _reset, child: const Text('Forgot Password?'))),
                    const SizedBox(height: 8),
                    FilledButton.icon(onPressed: loading ? null : _login, icon: const Icon(Icons.login), label: Text(loading ? 'Signing in...' : 'Login')),
                    const SizedBox(height: 12),
                    FeatureGate(
                      featureKey: 'registrationEnabled',
                      title: 'New registration is temporarily disabled',
                      child: OutlinedButton.icon(
                        onPressed: loading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Create KCN Account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      default:
        return e.message ?? 'Login failed.';
    }
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final mobile = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final village = TextEditingController();
  final district = TextEditingController();
  final state = TextEditingController();
  final referral = TextEditingController();
  final aadhaar = TextEditingController();
  String role = 'farmer';
  bool aadhaarConsent = false;
  bool legalConsent = false;
  bool loading = false;

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.replaceFirst('Exception: ', ''))),
    );
  }

  @override
  void dispose() {
    for (final c in [name, mobile, email, password, village, district, state, referral, aadhaar]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!form.currentState!.validate()) return;
    if (!legalConsent) {
      _msg('Please accept the Privacy Policy and Terms & Conditions.');
      return;
    }
    if (role == 'farmer') {
      final a = aadhaar.text.replaceAll(' ', '').trim();
      if (!RegExp(r'^\d{12}$').hasMatch(a)) {
        _msg('Enter a valid 12-digit Aadhaar number.');
        return;
      }
      if (!aadhaarConsent) {
        _msg('Please give consent for Aadhaar-based identity verification.');
        return;
      }
    }
    setState(() => loading = true);
    try {
      final aadhaarRaw = role == 'farmer' ? aadhaar.text.replaceAll(' ', '').trim() : '';
      final aadhaarHash = aadhaarRaw.isEmpty ? '' : sha256.convert(utf8.encode(aadhaarRaw)).toString();
      final aadhaarLast4 = aadhaarRaw.isEmpty ? '' : aadhaarRaw.substring(8);
      final c = await AuthService.instance.register(
        email: email.text,
        password: password.text,
        name: name.text,
        role: role,
        mobile: mobile.text,
        village: village.text,
        district: district.text,
        state: state.text,
        referral: referral.text,
        aadhaarHash: aadhaarHash,
        aadhaarLast4: aadhaarLast4,
        aadhaarConsent: aadhaarConsent,
      );
      final uid = c.user!.uid;
      final db = FirebaseFirestore.instance;
      if (role == 'farmer') {
        await db.collection(Collections.farmers).doc(uid).set({
          'uid': uid,
          'kcnId': null,
          'name': name.text.trim(),
          'mobile': mobile.text.trim(),
          'village': village.text.trim(),
          'district': district.text.trim(),
          'state': state.text.trim(),
          'referralCode': 'KCN-RF${uid.substring(0, 8).toUpperCase()}',
          'referralInput': referral.text.trim(),
          'referredBy': referral.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await db.collection(Collections.creditProfiles).doc(uid).set({
          'farmerId': uid,
          'kcnId': null,
          'creditScore': 650,
          'totalCredit': 0.0,
          'totalPaid': 0.0,
          'outstanding': 0.0,
          'activeCenters': 0,
          'overdueCenters': 0,
          'authorizedKendraIds': <String>[],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await db.collection(Collections.creditPublic).doc(uid).set({
          'farmerId': uid,
          'kcnId': null,
          'farmerName': name.text.trim(),
          'creditScore': 650,
          'outstanding': 0.0,
          'activeCenters': 0,
          'overdueCenters': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (role == 'krishiKendra') {
        await db.collection(Collections.kendras).doc(uid).set({
          'uid': uid,
          'name': name.text.trim(),
          'mobile': mobile.text.trim(),
          'village': village.text.trim(),
          'district': district.text.trim(),
          'state': state.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. Please wait for approval.')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create KCN Account')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              value: role,
              decoration: _dec('Account type', Icons.person_outline),
              items: const [
                DropdownMenuItem(value: 'farmer', child: Text('Farmer')),
                DropdownMenuItem(value: 'krishiKendra', child: Text('Krishi Kendra')),
                DropdownMenuItem(value: 'callCenter', child: Text('Call Center')),
              ],
              onChanged: loading ? null : (v) => setState(() => role = v ?? 'farmer'),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: name, decoration: _dec('Name / Business Name', Icons.person), validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: mobile, keyboardType: TextInputType.phone, decoration: _dec('Mobile number', Icons.phone), validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: _dec('Email ID', Icons.email), validator: (v) => v!.contains('@') ? null : 'Valid email required'),
            const SizedBox(height: 12),
            TextFormField(controller: password, obscureText: true, decoration: _dec('Password', Icons.lock), validator: (v) => v!.length < 6 ? 'Minimum 6 characters' : null),
            const SizedBox(height: 12),
            TextFormField(controller: village, decoration: _dec('Village', Icons.location_on_outlined)),
            const SizedBox(height: 12),
            TextFormField(controller: district, decoration: _dec('District', Icons.map_outlined)),
            const SizedBox(height: 12),
            TextFormField(controller: state, decoration: _dec('State', Icons.public)),
            if (role == 'farmer') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: aadhaar,
                keyboardType: TextInputType.number,
                maxLength: 12,
                obscureText: true,
                decoration: _dec('Aadhaar number (required)', Icons.badge_outlined),
                validator: (v) {
                  final x = (v ?? '').replaceAll(' ', '').trim();
                  return RegExp(r'^\d{12}$').hasMatch(x) ? null : '12-digit Aadhaar required';
                },
              ),
              CheckboxListTile(
                value: aadhaarConsent,
                onChanged: loading ? null : (v) => setState(() => aadhaarConsent = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I consent to Aadhaar-based identity verification. KCN will not store the full Aadhaar number.'),
              ),
              const SizedBox(height: 8),
              TextFormField(controller: referral, decoration: _dec('Referral code (optional)', Icons.share_outlined)),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              value: legalConsent,
              onChanged: loading ? null : (v) => setState(() => legalConsent = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Wrap(
                children: [
                  const Text('I agree to the '),
                  InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalSupportPage())),
                    child: const Text('Privacy Policy and Terms & Conditions', style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w700)),
                  ),
                  const Text('.'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: loading ? null : _register, child: Text(loading ? 'Creating...' : 'Create account')),
          ],
        ),
      ),
    );
  }
}

class UpdateCheckButton extends StatelessWidget {
  const UpdateCheckButton({super.key});

  Future<void> _check(BuildContext context) async {
    try {
      final data = await UpdateService.instance.config();
      if (data == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No update information available.')),
          );
        }
        return;
      }
      final available = await UpdateService.instance.isUpdateAvailable();
      if (!context.mounted) return;
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are using the latest version.')),
        );
        return;
      }
      final force = data['forceUpdate'] == true;
      await showDialog<void>(
        context: context,
        barrierDismissible: !force,
        builder: (dialogContext) => AlertDialog(
          title: Text(force ? 'Update Required' : 'Update Available'),
          content: Text(
            data['message']?.toString() ??
                'A newer KCN version is available. Please update the app.',
          ),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () async {
                await UpdateService.instance.openUpdateTarget(data);
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update check failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: FeatureSettings.instance.isEnabled('appUpdateChecksEnabled'),
      builder: (context, snapshot) {
        if (snapshot.data == false) return const SizedBox.shrink();
        return IconButton(
          tooltip: 'Check for updates',
          onPressed: () => _check(context),
          icon: const Icon(Icons.system_update_alt),
        );
      },
    );
  }}

class Shell extends StatelessWidget {
  const Shell({required this.title, required this.child, super.key, this.actions, this.onSignOut = true});
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [if (actions != null) ...actions!, if (onSignOut) IconButton(onPressed: AuthService.instance.signOut, icon: const Icon(Icons.logout))]),
      body: child,
    );
  }
}

class NotificationIcon extends StatelessWidget {
  const NotificationIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(Collections.notifications)
          .where('recipientId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final unread = docs.where((d) => d.data()['read'] != true).length;
        return IconButton(
          tooltip: unread > 0 ? '$unread unread notifications' : 'Notifications',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );
          },
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: const Icon(Icons.notifications_none_outlined),
          ),
        );
      },
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Future<void> _handleAction(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String action,
  ) async {
    final data = doc.data();
    final type = data['type']?.toString() ?? '';
    final payload = Map<String, dynamic>.from(data['payload'] ?? const {});
    try {
      if (type == 'access_request') {
        final requestId = payload['requestId']?.toString() ?? '';
        if (requestId.isEmpty) throw Exception('Request is missing its ID.');
        final status = action == 'approve' ? 'approved' : 'rejected';
        await FirebaseFirestore.instance
            .collection(Collections.accessRequests)
            .doc(requestId)
            .update({
          'status': status,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final kendraId = payload['kendraId']?.toString() ?? '';
        final farmerName = payload['farmerName']?.toString() ?? 'Farmer';
        if (kendraId.isNotEmpty) {
          await NotificationService.instance.create(
            recipientId: kendraId,
            title: 'Farmer permission ${status == 'approved' ? 'approved' : 'rejected'}',
            message: '$farmerName has ${status == 'approved' ? 'approved' : 'rejected'} your detailed credit access request.',
            type: 'access_request_result',
            payload: {'requestId': requestId, 'status': status},
          );
        }
      }
      await NotificationService.instance.markRead(doc.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(action == 'approve' ? 'Permission approved.' : 'Permission rejected.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Session not found.'));

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(Collections.notifications)
            .where('recipientId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load notifications.\n${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...snapshot.data!.docs];
          docs.sort((a, b) {
            final at = a.data()['createdAt'];
            final bt = b.data()['createdAt'];
            final ams = at is Timestamp ? at.millisecondsSinceEpoch : 0;
            final bms = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
            return bms.compareTo(ams);
          });

          if (docs.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final type = data['type']?.toString() ?? 'general';
              final read = data['read'] == true;
              final isAccessRequest = type == 'access_request';

              return Card(
                color: read ? null : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isAccessRequest
                                ? Icons.lock_open_outlined
                                : Icons.notifications_outlined,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              data['title']?.toString() ?? 'KCN Notification',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (!read)
                            IconButton(
                              tooltip: 'Mark read',
                              onPressed: () => NotificationService.instance.markRead(doc.id),
                              icon: const Icon(Icons.done),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(data['message']?.toString() ?? ''),
                      if (isAccessRequest) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _handleAction(context, doc, 'approve'),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _handleAction(context, doc, 'reject'),
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FarmerDashboard extends StatefulWidget {
  const FarmerDashboard({super.key});
  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  int tab = 0;
  Map<String, dynamic>? user;
  Map<String, dynamic>? farmer;
  Map<String, dynamic>? profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final db = FirebaseFirestore.instance;
    try {
      final results = await Future.wait([
        db.collection(Collections.users).doc(uid).get(),
        db.collection(Collections.farmers).doc(uid).get(),
        db.collection(Collections.creditProfiles).doc(uid).get(),
      ]);
      if (!mounted) return;
      setState(() {
        user = results[0].data();
        farmer = results[1].data();
        profile = results[2].data();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to load profile: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      FarmerHome(user: user, farmer: farmer, profile: profile, onRefresh: _load),
      const FeatureGate(
        featureKey: 'farmerProductsEnabled',
        title: 'Company Products are currently disabled',
        child: FeatureGate(
          featureKey: 'networkOrderingEnabled',
          title: 'Network ordering is currently disabled',
          child: FarmerProductsPage(),
        ),
      ),
      const FeatureGate(
        featureKey: 'farmerGroupsEnabled',
        title: 'Product Groups are currently disabled',
        child: FeatureGate(
          featureKey: 'networkOrderingEnabled',
          title: 'Network ordering is currently disabled',
          child: FarmerGroupsPage(),
        ),
      ),
      const FeatureGate(featureKey: 'farmerOrdersEnabled', title: 'My Orders are currently disabled', child: FarmerOrdersPage()),
      const FarmerNetworkPage(),
      FeatureGate(featureKey: 'farmerCreditEnabled', title: 'My Credit is currently disabled', child: FarmerCreditPage(profile: profile)),
    ];
    final destinations = const <NavigationDestination>[
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Products'),
      NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Groups'),
      NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
      NavigationDestination(icon: Icon(Icons.account_tree_outlined), selectedIcon: Icon(Icons.account_tree), label: 'Network'),
      NavigationDestination(icon: Icon(Icons.credit_score_outlined), selectedIcon: Icon(Icons.credit_score), label: 'Credit'),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('KCN Farmer'),
        actions: [const NotificationIcon(), IconButton(tooltip: 'Legal & Support', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalSupportPage())), icon: const Icon(Icons.info_outline)), const UpdateCheckButton(), IconButton(tooltip: 'Logout', onPressed: AuthService.instance.signOut, icon: const Icon(Icons.logout))],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: tab,
                  onDestinationSelected: (v) {
                    if (v == tab) return;
                    AdService.instance.onUserNavigation();
                    setState(() => tab = v);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations.map((d) => NavigationRailDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: Text(d.label))).toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[tab]),
              ],
            )
          : pages[tab],
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (v) {
              if (v == tab) return;
              AdService.instance.onUserNavigation();
              setState(() => tab = v);
            },
            destinations: destinations,
          ),
    );
  }
}

class FarmerHome extends StatelessWidget {
  const FarmerHome({
    required this.user,
    required this.farmer,
    required this.profile,
    required this.onRefresh,
    super.key,
  });

  final Map<String, dynamic>? user;
  final Map<String, dynamic>? farmer;
  final Map<String, dynamic>? profile;
  final Future<void> Function() onRefresh;

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (farmer?['name'] ?? user?['name'] ?? 'Farmer').toString();
    final kcn = (farmer?['kcnId'] ?? '-').toString();
    final score = ((profile?['creditScore'] ?? 650) as num).toInt();
    final outstanding =
        ((profile?['outstanding'] ?? 0) as num).toDouble();

    final services = <Widget>[
      FeatureTile(
        icon: Icons.shopping_bag,
        title: 'Company Products',
        onTap: () => _openPage(context, const FarmerProductsPage()),
      ),
      FeatureTile(
        icon: Icons.receipt_long,
        title: 'My Orders',
        onTap: () => _openPage(context, const FarmerOrdersPage()),
      ),
      const FeatureTile(
        icon: Icons.stars_outlined,
        title: 'My Points',
      ),
      const FeatureTile(
        icon: Icons.local_offer_outlined,
        title: 'Discount',
      ),
      FeatureTile(
        icon: Icons.group_add_outlined,
        title: 'Join Network',
        onTap: () => _openPage(context, const JoinNetworkPage()),
      ),
      FeatureTile(
        icon: Icons.account_tree,
        title: 'My Network',
        onTap: () => _openPage(context, const FarmerNetworkPage()),
      ),
      const FeatureTile(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Network Income',
      ),
      const FeatureTile(
        icon: Icons.wallet_outlined,
        title: 'Wallet',
      ),
      const FeatureTile(
        icon: Icons.person_outline,
        title: 'Profile',
      ),
      const FeatureTile(
        icon: Icons.support_agent,
        title: 'Support',
      ),
      const FeatureTile(
        icon: Icons.more_horiz,
        title: 'More',
      ),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const KcnAdBanner(),
          const SizedBox(height: 10),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $name',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('KCN ID: $kcn'),
                  Text(
                    'Referral: ${(farmer?['referralCode'] ?? '-')}',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          const GlobalAdvertisementBanner(),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'KCN Score',
                  value: '$score',
                  icon: Icons.speed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'Unpaid Bill',
                  value: 'ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¹${money(outstanding)}',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: StatCard(
                  label: 'Network Points',
                  value: '0',
                  icon: Icons.stars_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Text(
            'Your KCN Services',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.30,
            children: services,
          ),

          const SizedBox(height: 18),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Summary',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _summaryRow('KCN ID', kcn),
                  _summaryRow('Name', name),
                  _summaryRow('Points', '0'),
                  _summaryRow('Network Status', 'Not Joined'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  static Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}
class FarmerProductsPage extends StatelessWidget {
  const FarmerProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(Collections.products).where('active', isEqualTo: true).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Unable to load products.\n${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No products available yet.'));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const KcnAdBanner(),
            const SizedBox(height: 8),
            ...List.generate(docs.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ProductCard(doc: docs[i]),
            )),
          ],
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({required this.doc, super.key});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final p = doc.data();
    final price = ((p['farmerPrice'] ?? p['price'] ?? 0) as num).toDouble();
    final stock = ((p['stock'] ?? 0) as num).toInt();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: stock > 0 ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(productId: doc.id, product: p))) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ProductImage(path: p['imageAsset']?.toString(), url: p['imageUrl']?.toString(), size: 84),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 4), if ((p['technicalName'] ?? '').toString().isNotEmpty) Text('Technical: ${p['technicalName']}'), const SizedBox(height: 6), Text('ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(price)}'), Text('Points: ${p['points'] ?? 0}'), Text(stock > 0 ? 'Stock: $stock' : 'Out of stock', style: TextStyle(color: stock > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w600))])),
              FilledButton(onPressed: stock > 0 ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(productId: doc.id, product: p))) : null, child: const Text('Order')),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({required this.productId, required this.product, super.key});
  final String productId;
  final Map<String, dynamic> product;
  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int qty = 1;
  bool ordering = false;

  Future<void> _placeOrder() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => ordering = true);
    try {
      final farmer = await FirebaseFirestore.instance.collection(Collections.farmers).doc(uid).get();
      final p = widget.product;
      final price = ((p['farmerPrice'] ?? 0) as num).toDouble();
      final total = price * qty;
      final ref = FirebaseFirestore.instance.collection(Collections.orders).doc();
      await ref.set({
        'orderId': ref.id,
        'farmerId': uid,
        'farmerName': farmer.data()?['name'] ?? '',
        'kcnId': farmer.data()?['kcnId'] ?? '',
        'productId': widget.productId,
        'productName': p['name'] ?? '',
        'quantity': qty,
        'unitPrice': price,
        'totalAmount': total,
        'points': ((p['points'] ?? 0) as num).toInt() * qty,
        'status': 'pending_inventory',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'rewardCalculated': false,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed successfully.')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => ordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final price = ((p['farmerPrice'] ?? 0) as num).toDouble();
    final stock = ((p['stock'] ?? 0) as num).toInt();
    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const KcnAdBanner(),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: ProductImage(path: p['imageAsset']?.toString(), url: p['imageUrl']?.toString(), size: 220, fit: BoxFit.contain))),
          const SizedBox(height: 14),
          Text(p['name']?.toString() ?? '-', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(price)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(stock > 0 ? 'In Stock: $stock' : 'Out of stock', style: TextStyle(color: stock > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if ((p['technicalName'] ?? '').toString().isNotEmpty) Text('Technical Name: ${p['technicalName']}'),
          const SizedBox(height: 8),
          Text('Points: ${p['points'] ?? 0}'),
          const SizedBox(height: 8),
          Text(p['description']?.toString() ?? 'Company product.'),
          const SizedBox(height: 18),
          Row(children: [const Text('Quantity'), const Spacer(), IconButton(onPressed: qty > 1 ? () => setState(() => qty--) : null, icon: const Icon(Icons.remove_circle_outline)), Text('$qty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(onPressed: qty < stock ? () => setState(() => qty++) : null, icon: const Icon(Icons.add_circle_outline))]),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: ordering || stock <= 0 ? null : _placeOrder, icon: const Icon(Icons.shopping_cart_checkout), label: Text(ordering ? 'Placing Order...' : 'Place Order ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(price * qty)}')),
        ],
      ),
    );
  }
}


class FarmerGroupsPage extends StatelessWidget {
  const FarmerGroupsPage({super.key});

  Future<void> _buyGroup(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> groupDoc) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final group = groupDoc.data();
    final rawItems = group['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This group has no products.')));
      return;
    }
    final farmerSnap = await FirebaseFirestore.instance.collection(Collections.farmers).doc(uid).get();
    final items = <Map<String, dynamic>>[];
    var totalPoints = 0;
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final productId = item['productId']?.toString() ?? '';
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      if (productId.isEmpty || quantity <= 0) continue;
      final productSnap = await FirebaseFirestore.instance.collection(Collections.products).doc(productId).get();
      if (!productSnap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A group product is unavailable.')));
        return;
      }
      final p = productSnap.data() ?? {};
      if (p['active'] != true || ((p['stock'] ?? 0) as num).toInt() < quantity) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('One or more group products are out of stock.')));
        return;
      }
      totalPoints += ((p['points'] ?? 0) as num).toInt() * quantity;
      items.add({
        'productId': productId,
        'productName': p['name']?.toString() ?? '',
        'quantity': quantity,
        'unitPrice': ((p['farmerPrice'] ?? 0) as num).toDouble(),
      });
    }
    if (items.isEmpty) return;
    final groupPrice = ((group['groupPrice'] ?? 0) as num).toDouble();
    final ref = FirebaseFirestore.instance.collection(Collections.orders).doc();
    await ref.set({
      'orderId': ref.id,
      'orderType': 'group',
      'groupId': groupDoc.id,
      'groupName': group['name']?.toString() ?? 'Product Group',
      'items': items,
      'farmerId': uid,
      'farmerName': farmerSnap.data()?['name'] ?? '',
      'kcnId': farmerSnap.data()?['kcnId'] ?? '',
      'quantity': 1,
      'totalAmount': groupPrice,
      'points': totalPoints,
      'status': 'pending_inventory',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'rewardCalculated': false,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group order placed successfully.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(Collections.productGroups).where('active', isEqualTo: true).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Unable to load groups.\n${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No product groups available.'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final d = docs[index].data();
            final normal = ((d['normalTotal'] ?? 0) as num).toDouble();
            final groupPrice = ((d['groupPrice'] ?? 0) as num).toDouble();
            final saving = normal - groupPrice;
            final items = d['items'] is List ? (d['items'] as List).length : 0;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['name']?.toString() ?? 'Product Group', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(d['description']?.toString() ?? ''),
                    const SizedBox(height: 10),
                    Text('$items products'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: Text('Normal ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(normal)}', style: const TextStyle(decoration: TextDecoration.lineThrough))),
                      Expanded(child: Text('Group ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(groupPrice)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      if (saving > 0) Text('Save ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(saving)}'),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _buyGroup(context, docs[index]), icon: const Icon(Icons.shopping_cart_checkout), label: Text('Buy Group ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(groupPrice)}'))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class KcnOrderWorkflow {
  static int orderedQuantity(Map<String, dynamic> d) {
    if (d['orderType'] == 'group' && d['items'] is List) {
      var total = 0;
      for (final raw in (d['items'] as List)) {
        if (raw is Map) {
          total += (raw['quantity'] as num?)?.toInt() ?? 0;
        }
      }
      return total;
    }
    return (d['quantity'] as num?)?.toInt() ?? 0;
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'processing':
        return 'Processing';
      case 'dispatched':
        return 'Dispatched';
      case 'not_dispatched':
        return 'Not Dispatched';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  static String paymentStatusLabel(String status) {
    switch (status) {
      case 'received':
        return 'Received';
      case 'partial':
        return 'Partial';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  static Future<void> open(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final d = doc.data();
    final orderedQty = orderedQuantity(d);

    String status = d['status']?.toString() ?? 'pending';
    String paymentMethod = d['paymentMethod']?.toString() ?? 'COD';
    String paymentStatus = d['paymentStatus']?.toString() ?? 'pending';

    final reasonController = TextEditingController(
      text: d['notDispatchedReason']?.toString() ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isNotDispatched = status == 'not_dispatched';

            return AlertDialog(
              title: Text(d['productName']?.toString() ?? 'Order'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order ID: ${doc.id}'),
                      const SizedBox(height: 6),
                      Text('Farmer: ${d['farmerName']?.toString() ?? d['farmerId']?.toString() ?? '-'}'),
                      const SizedBox(height: 6),
                      Text('Ordered Quantity: $orderedQty'),
                      const SizedBox(height: 6),
                      Text(
                        'Total: Rs ${money(((d['totalAmount'] ?? 0) as num).toDouble())}',
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: 'Order Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'pending_inventory',
                            child: Text('Pending Inventory'),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'processing',
                            child: Text('Processing'),
                          ),
                          DropdownMenuItem(
                            value: 'dispatched',
                            child: Text('Dispatched'),
                          ),
                          DropdownMenuItem(
                            value: 'not_dispatched',
                            child: Text('Not Dispatched'),
                          ),
                          DropdownMenuItem(
                            value: 'delivered',
                            child: Text('Delivered'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('Cancelled'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => status = value);
                          }
                        },
                      ),
                      if (status == 'dispatched' || status == 'delivered') ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.green.withOpacity(0.08),
                          ),
                          child: Text(
                            'Dispatch Quantity: $orderedQty (same as ordered quantity)',
                          ),
                        ),
                      ],
                      if (isNotDispatched) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: reasonController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Reason for not dispatching',
                            hintText: 'Enter reason',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment Method',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'COD',
                            child: Text('Cash on Delivery'),
                          ),
                          DropdownMenuItem(
                            value: 'Prepaid',
                            child: Text('Prepaid'),
                          ),
                          DropdownMenuItem(
                            value: 'UPI',
                            child: Text('UPI'),
                          ),
                          DropdownMenuItem(
                            value: 'Bank',
                            child: Text('Bank'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => paymentMethod = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: paymentStatus,
                        decoration: const InputDecoration(
                          labelText: 'Payment Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'pending_inventory',
                            child: Text('Pending Inventory'),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'received',
                            child: Text('Received'),
                          ),
                          DropdownMenuItem(
                            value: 'partial',
                            child: Text('Partial'),
                          ),
                          DropdownMenuItem(
                            value: 'failed',
                            child: Text('Failed'),
                          ),
                          DropdownMenuItem(
                            value: 'refunded',
                            child: Text('Refunded'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => paymentStatus = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext, {
                      'status': status,
                      'paymentMethod': paymentMethod,
                      'paymentStatus': paymentStatus,
                      'reason': reasonController.text.trim(),
                    });
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();

    if (result == null) return;

    final newStatus = result['status']?.toString() ?? 'pending';
    final reason = result['reason']?.toString().trim() ?? '';

    if (newStatus == 'not_dispatched' && reason.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reason is required when product is not dispatched.'),
          ),
        );
      }
      return;
    }

    final currentData = doc.data();

    if (newStatus == 'delivered') {
      final currentDispatchQty =
          (currentData['dispatchedQuantity'] as num?)?.toInt() ?? 0;

      if (currentDispatchQty != orderedQty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Mark the complete ordered quantity as dispatched before delivery.',
              ),
            ),
          );
        }
        return;
      }
    }

    final uid = AuthService.instance.currentUser?.uid;

    final updateData = <String, dynamic>{
      'status': newStatus,
      'paymentMethod': result['paymentMethod']?.toString() ?? 'COD',
      'paymentStatus': result['paymentStatus']?.toString() ?? 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    };

    if (newStatus == 'dispatched') {
      updateData['dispatchedQuantity'] = orderedQty;
      updateData['dispatchedAt'] = FieldValue.serverTimestamp();
      updateData['dispatchConfirmed'] = true;

      if (currentData['orderType'] == 'group' &&
          currentData['items'] is List) {
        updateData['dispatchedItems'] = List<Map<String, dynamic>>.from(
          (currentData['items'] as List)
              .whereType<Map>()
              .map(
                (raw) => {
                  'productId': raw['productId']?.toString() ?? '',
                  'quantity': (raw['quantity'] as num?)?.toInt() ?? 0,
                },
              ),
        );
      }
    }

    if (newStatus == 'delivered') {
      updateData['deliveredQuantity'] = orderedQty;
      updateData['deliveredAt'] = FieldValue.serverTimestamp();
    }

    if (newStatus == 'not_dispatched') {
      updateData['notDispatchedReason'] = reason;
      updateData['notDispatchedAt'] = FieldValue.serverTimestamp();
      updateData['dispatchConfirmed'] = false;
      updateData['dispatchedQuantity'] = 0;
    } else {
      updateData['notDispatchedReason'] = FieldValue.delete();
    }

    await doc.reference.update(updateData);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order updated: ${statusLabel(newStatus)}',
          ),
        ),
      );
    }
  }
}

class FarmerOrdersPage extends StatelessWidget {
  const FarmerOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text('Not signed in.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(Collections.orders)
          .where('farmerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('Unable to load orders.\n${snap.error}'),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = [...snap.data!.docs]
          ..sort(
            (a, b) => _ts(b.data()['createdAt'])
                .compareTo(_ts(a.data()['createdAt'])),
          );

        if (docs.isEmpty) {
          return const Center(child: Text('No orders yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final doc = docs[i];
            final d = doc.data();
            final orderedQty = KcnOrderWorkflow.orderedQuantity(d);
            final status = d['status']?.toString() ?? 'pending';
            final paymentStatus =
                d['paymentStatus']?.toString() ?? 'pending';
            final dispatchedQty =
                (d['dispatchedQuantity'] as num?)?.toInt() ?? 0;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            d['productName']?.toString() ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        StatusChip(
                          text: KcnOrderWorkflow.statusLabel(status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Order: ${doc.id}'),
                    Text('Ordered Qty: $orderedQty'),
                    Text(
                      'Amount: Rs ${money(((d['totalAmount'] ?? 0) as num).toDouble())}',
                    ),
                    if (status == 'dispatched' || status == 'delivered')
                      Text('Dispatched Qty: $dispatchedQty / $orderedQty'),
                    Text(
                      'Payment: ${KcnOrderWorkflow.paymentStatusLabel(paymentStatus)}',
                    ),
                    if (status == 'not_dispatched')
                      Text(
                        'Reason: ${d['notDispatchedReason']?.toString() ?? '-'}',
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class JoinNetworkPage extends StatefulWidget {
  const JoinNetworkPage({super.key});

  @override
  State<JoinNetworkPage> createState() => _JoinNetworkPageState();
}

class _JoinNetworkPageState extends State<JoinNetworkPage> {
  final TextEditingController sponsorController = TextEditingController();

  bool loading = false;
  Map<String, dynamic>? sponsor;
  bool confirmed = false;

  @override
  void dispose() {
    sponsorController.dispose();
    super.dispose();
  }

  Future<void> findSponsor() async {
    final uid = AuthService.instance.currentUser?.uid;

    if (uid == null) {
      _message('Please sign in first.');
      return;
    }

    final kcnId = sponsorController.text.trim().toUpperCase();

    if (kcnId.isEmpty) {
      _message('Please enter Sponsor KCN ID.');
      return;
    }

    setState(() {
      loading = true;
      sponsor = null;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection(Collections.farmers)
          .where('kcnId', isEqualTo: kcnId)
          .limit(1)
          .get();

      if (!mounted) return;

      if (query.docs.isEmpty) {
        _message('Sponsor KCN ID not found.');
        setState(() => loading = false);
        return;
      }

      final doc = query.docs.first;

      if (doc.id == uid) {
        _message('You cannot use your own KCN ID as Sponsor.');
        setState(() => loading = false);
        return;
      }

      final data = doc.data();

      setState(() {
        sponsor = {
          'id': doc.id,
          ...data,
        };
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _message('Unable to find Sponsor: $e');
    }
  }

  Future<void> submitJoinRequest() async {
    final uid = AuthService.instance.currentUser?.uid;
    final s = sponsor;

    if (uid == null || s == null) {
      _message('Please select a valid Sponsor first.');
      return;
    }

    if (!confirmed) {
      _message('Please confirm the Sponsor details.');
      return;
    }

    setState(() => loading = true);

    try {
      final farmerRef = FirebaseFirestore.instance
          .collection(Collections.farmers)
          .doc(uid);

      await farmerRef.set({
        'networkJoinRequest': {
          'status': 'pending',
          'sponsorId': s['id']?.toString() ?? '',
          'sponsorKcnId': s['kcnId']?.toString() ?? '',
          'sponsorName': s['name']?.toString() ?? '',
          'requestedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() => loading = false);

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NetworkJoinRequestSuccessPage(
            sponsor: s,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _message('Unable to submit Join Request: $e');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = sponsor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join KCN Network'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.account_tree_outlined,
                    size: 52,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'KCN Network à¤®à¥‡à¤‚ à¤œà¥à¤¡à¤¼à¥‡à¤‚',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'à¤…à¤ªà¤¨à¥‡ Sponsor à¤•à¥€ KCN ID à¤¡à¤¾à¤²à¥‡à¤‚ à¤”à¤° '
                    'KCN Network à¤•à¤¾ à¤¹à¤¿à¤¸à¥à¤¸à¤¾ à¤¬à¤¨à¥‡à¤‚à¥¤',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: sponsorController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Sponsor KCN ID *',
              hintText: 'KCN-XXXXXXXXXXXX',
              prefixIcon: const Icon(Icons.badge_outlined),
              suffixIcon: IconButton(
                tooltip: 'Search Sponsor',
                onPressed: loading ? null : findSponsor,
                icon: const Icon(Icons.search),
              ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => findSponsor(),
          ),

          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: loading ? null : findSponsor,
            icon: const Icon(Icons.search),
            label: const Text('Find Sponsor'),
          ),

          const SizedBox(height: 16),

          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),

          if (s != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sponsor Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          child: Icon(Icons.person),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s['name']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'KCN ID: ${s['kcnId']?.toString() ?? '-'}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      'Name: ${s['name']?.toString() ?? '-'}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mobile: ${s['mobile']?.toString() ?? '-'}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'KCN ID: ${s['kcnId']?.toString() ?? '-'}',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            Card(
              color: const Color(0xFFFFF7D6),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: confirmed,
                      onChanged: (v) {
                        setState(() => confirmed = v ?? false);
                      },
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'à¤®à¥ˆà¤‚à¤¨à¥‡ Sponsor à¤•à¥€ à¤œà¤¾à¤¨à¤•à¤¾à¤°à¥€ à¤œà¤¾à¤à¤š à¤²à¥€ à¤¹à¥ˆ '
                          'à¤”à¤° à¤®à¥ˆà¤‚ à¤‡à¤¸à¥€ Sponsor à¤•à¥‡ à¤¸à¤¾à¤¥ KCN Network '
                          'Join à¤•à¤°à¤¨à¥‡ à¤•à¤¾ à¤…à¤¨à¥à¤°à¥‹à¤§ à¤•à¤°à¤¤à¤¾/à¤•à¤°à¤¤à¥€ à¤¹à¥‚à¤à¥¤',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            FilledButton.icon(
              onPressed: loading ? null : submitJoinRequest,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm & Join'),
            ),
          ],
        ],
      ),
    );
  }
}

class NetworkJoinRequestSuccessPage extends StatelessWidget {
  const NetworkJoinRequestSuccessPage({
    required this.sponsor,
    super.key,
  });

  final Map<String, dynamic> sponsor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Join'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 42,
                    child: Icon(
                      Icons.check,
                      size: 46,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Join Request Submitted',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'à¤†à¤ªà¤•à¤¾ KCN Network Join Request '
                    'successfully submit à¤¹à¥‹ à¤—à¤¯à¤¾ à¤¹à¥ˆà¥¤',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  Card(
                    color: const Color(0xFFEAF7EC),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Sponsor',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sponsor['name']?.toString() ?? '-',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sponsor['kcnId']?.toString() ?? '-',
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Status: Pending Approval',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go to My Network'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class FarmerNetworkPage extends StatefulWidget {
  const FarmerNetworkPage({super.key});

  @override
  State<FarmerNetworkPage> createState() => _FarmerNetworkPageState();
}

class _FarmerNetworkPageState extends State<FarmerNetworkPage> {
  bool _submitting = false;

  Future<void> _requestExit(Map<String, dynamic> member) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || _submitting) return;

    final sponsorId = member['sponsorId']?.toString() ?? '';
    final isRoot = sponsorId.isEmpty || member['isRootMember'] == true;

    if (isRoot) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Root member cannot exit the network.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit Network?'),
        content: const Text(
          'If you exit, your direct members will automatically move '
          'under your original sponsor. The rest of the tree will stay '
          'connected and its levels will be adjusted. Your old orders '
          'and rewards will remain unchanged.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Exit Network'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);

    final requestRef = FirebaseFirestore.instance
        .collection('network_exit_requests_v3')
        .doc(uid);

    try {
      await requestRef.set({
        'farmerId': uid,
        'farmerName': member['memberName']?.toString() ?? '',
        'kcnId': member['kcnId']?.toString() ?? '',
        'sponsorId': sponsorId,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Exit request submitted. Your network will be adjusted automatically.',
            ),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        final message = e.code == 'already-exists'
            ? 'An exit request already exists or this member has already exited.'
            : 'Exit request failed: ${e.message ?? e.code}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exit request failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Not signed in.'));

    final db = FirebaseFirestore.instance;
    final memberRef = db.collection(Collections.networkMembers).doc(uid);
    final exitRef = db.collection('network_exit_requests_v3').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: memberRef.snapshots(),
      builder: (context, memberSnap) {
        if (memberSnap.hasError) {
          return Center(
            child: Text('Unable to load network.\n${memberSnap.error}'),
          );
        }
        if (!memberSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!memberSnap.data!.exists) {
          return const Center(child: Text('Network membership not found.'));
        }

        final member = memberSnap.data!.data() ?? <String, dynamic>{};
        final status = member['status']?.toString().toLowerCase() ?? 'active';
        final sponsorId = member['sponsorId']?.toString() ?? '';
        final isRoot =
            sponsorId.isEmpty || member['isRootMember'] == true;
        final exited = status == 'exited';

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: exitRef.snapshots(),
          builder: (context, exitSnap) {
            final exitData = exitSnap.data?.data();
            final exitStatus = exitData?['status']?.toString().toLowerCase();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db
                  .collection(Collections.networkMembers)
                  .where('sponsorId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text('Unable to load network.\n${snap.error}'),
                  );
                }

                final docs = snap.data?.docs ?? const [];

                String? bannerText;
                if (exited) {
                  bannerText =
                      'You have exited the KCN Network. Your previous '
                      'orders and rewards remain unchanged.';
                } else if (exitStatus == 'pending') {
                  bannerText =
                      'Exit request is being processed. Your network '
                      'will be adjusted automatically.';
                } else if (exitStatus == 'rejected') {
                  bannerText =
                      'Your exit request could not be completed. '
                      'Please contact Admin.';
                } else if (isRoot) {
                  bannerText = 'Root member cannot exit the network.';
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My Network',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'KCN ID: ${member['kcnId'] ?? '-'}',
                            ),
                            Text(
                              'Direct Members: ${docs.length}',
                            ),
                            if (bannerText != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  ),
                                ),
                                child: Text(bannerText),
                              ),
                            ],
                            if (!exited &&
                                !isRoot &&
                                exitStatus != 'pending' &&
                                exitStatus != 'rejected') ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _submitting
                                      ? null
                                      : () => _requestExit(member),
                                  icon: _submitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.logout),
                                  label: Text(
                                    _submitting
                                        ? 'Submitting...'
                                        : 'Exit Network',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (docs.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('No direct members yet.'),
                        ),
                      )
                    else
                      ...docs.map(
                        (d) {
                          final data = d.data();
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(
                                data['memberName']?.toString() ?? '-',
                              ),
                              subtitle: Text(
                                'KCN: ${data['kcnId']?.toString() ?? '-'}',
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
class FarmerCreditPage extends StatelessWidget {
  const FarmerCreditPage({required this.profile, super.key});
  final Map<String, dynamic>? profile;
  @override
  Widget build(BuildContext context) {
    final score = ((profile?['creditScore'] ?? 650) as num).toInt();
    final due = ((profile?['outstanding'] ?? 0) as num).toDouble();
    return ListView(padding: const EdgeInsets.all(16), children: [const KcnAdBanner(), CreditScoreCard(score: score), const SizedBox(height: 12), Row(children: [Expanded(child: StatCard(label: 'Total Bill', value: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((profile?['totalCredit'] ?? 0) as num).toDouble())}', icon: Icons.credit_card)), const SizedBox(width: 10), Expanded(child: StatCard(label: 'Paid', value: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((profile?['totalPaid'] ?? 0) as num).toDouble())}', icon: Icons.payments_outlined)), const SizedBox(width: 10), Expanded(child: StatCard(label: 'Unpaid Bill', value: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(due)}', icon: Icons.warning_amber_outlined))]), const SizedBox(height: 14), const Text('Detailed credit access is shared only through KCN consent/permission.', style: TextStyle(fontWeight: FontWeight.w600))]);
  }
}

class KendraDashboard extends StatefulWidget {
  const KendraDashboard({super.key});
  @override
  State<KendraDashboard> createState() => _KendraDashboardState();
}

class _KendraDashboardState extends State<KendraDashboard> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const KendraOverview(),
      const FeatureGate(featureKey: 'kendraCreditEnabled', title: 'Credit entry is currently disabled', child: KendraCreditsPage()),
      const FeatureGate(featureKey: 'kendraPaymentEnabled', title: 'Payment entry is currently disabled', child: KendraPaymentHubPage()),
      const FeatureGate(featureKey: 'kendraOutstandingEnabled', title: 'Outstanding is currently disabled', child: KendraOutstandingPage()),
      const FeatureGate(featureKey: 'kendraLedgerEnabled', title: 'Ledger is currently disabled', child: KendraLedgerPage()),
      const FeatureGate(featureKey: 'kendraSearchEnabled', title: 'KCN Search is currently disabled', child: KendraSearchPage()),
    ];
    final destinations = const <NavigationDestination>[
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
      NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Credits'),
      NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Payment'),
      NavigationDestination(icon: Icon(Icons.warning_amber_outlined), label: 'Unpaid Bill'),
      NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Ledger'),
      NavigationDestination(icon: Icon(Icons.search), label: 'KCN Search'),
    ];

    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('KCN Krishi Kendra'),
        actions: [
          const NotificationIcon(),
          IconButton(tooltip: 'Legal & Support', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalSupportPage())), icon: const Icon(Icons.info_outline)),
          const UpdateCheckButton(),
          IconButton(
            tooltip: 'Logout',
            onPressed: AuthService.instance.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: tab,
                  onDestinationSelected: (v) {
                    if (v == tab) return;
                    AdService.instance.onUserNavigation();
                    setState(() => tab = v);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations
                      .map((d) => NavigationRailDestination(
                            icon: d.icon,
                            selectedIcon: d.icon,
                            label: Text(d.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[tab]),
              ],
            )
          : pages[tab],
      floatingActionButton: tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewCreditPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New Credit'),
            )
          : null,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) => setState(() => tab = v),
              destinations: destinations,
            ),
    );
  }
}

class KendraOverview extends StatelessWidget {
  const KendraOverview({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(Collections.credits).where('krishiKendraId', isEqualTo: uid).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        final total = docs.fold<double>(0, (s, d) => s + ((d.data()['amount'] ?? 0) as num).toDouble());
        final due = docs.fold<double>(0, (s, d) => s + ((d.data()['balanceAmount'] ?? 0) as num).toDouble());
        return ListView(padding: const EdgeInsets.all(16), children: [const KcnAdBanner(), Text('KCN Management', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12), const GlobalAdvertisementBanner(), const SizedBox(height: 12), Row(children: [Expanded(child: StatCard(label: 'Farmers/Bills', value: '${docs.length}', icon: Icons.people_outline)), const SizedBox(width: 10), Expanded(child: StatCard(label: 'Total Bill', value: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(total)}', icon: Icons.credit_card)), const SizedBox(width: 10), Expanded(child: StatCard(label: 'Unpaid Bill', value: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(due)}', icon: Icons.warning_amber_outlined))]), const SizedBox(height: 16), const InfoBanner(text: 'KCN Search shows limited risk summary. Detailed credit access requires farmer permission.')]);
      },
    );
  }
}

class KendraCreditsPage extends StatelessWidget {
  const KendraCreditsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(Collections.credits).where('krishiKendraId', isEqualTo: uid).snapshots(),
      builder: (_, snap) {
        if (snap.hasError) return Center(child: Text('Unable to load credits.\n${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No credit entries yet.'));
        return ListView.separated(padding: const EdgeInsets.all(16), itemCount: docs.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, i) { final d = docs[i]; final x = d.data(); return Card(child: ExpansionTile(leading: const Icon(Icons.receipt_long), title: Text('${x['billNo'] ?? '-'} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${x['farmerName'] ?? '-'}'), subtitle: Text('Balance ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((x['balanceAmount'] ?? 0) as num).toDouble())}'), children: [Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: Text('KCN: ${x['kcnId'] ?? '-'}\nTotal: ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((x['amount'] ?? 0) as num).toDouble())}\nPaid: ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((x['paidAmount'] ?? 0) as num).toDouble())}')), FilledButton.tonal(onPressed: ((x['balanceAmount'] ?? 0) as num).toDouble() > 0 ? () => _payment(context, d.id, x) : null, child: const Text('Payment'))]))])); });
      },
    );
  }

  void _payment(BuildContext context, String id, Map<String, dynamic> x) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentPage(creditId: id, farmerId: x['farmerId'].toString(), billNo: x['billNo'].toString(), balance: ((x['balanceAmount'] ?? 0) as num).toDouble())));
  }
}

class KendraPaymentHubPage extends StatelessWidget {
  const KendraPaymentHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Kendra session not found.'));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(Collections.credits)
          .where('krishiKendraId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Unable to load payment list.\n${snap.error}'));
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs.where((d) {
          final b = ((d.data()['balanceAmount'] ?? 0) as num).toDouble();
          return b > 0;
        }).toList();
        docs.sort((a, b) =>
            ((b.data()['balanceAmount'] ?? 0) as num).compareTo(
                (a.data()['balanceAmount'] ?? 0) as num));
        if (docs.isEmpty) return const Center(child: Text('No pending payments.'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final x = doc.data();
            final balance = ((x['balanceAmount'] ?? 0) as num).toDouble();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text('${x['farmerName'] ?? '-'} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${x['billNo'] ?? '-'}'),
                subtitle: Text(
                  'KCN ${x['kcnId'] ?? '-'}\nOutstanding ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(balance)}',
                ),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentPage(
                        creditId: doc.id,
                        farmerId: x['farmerId']?.toString() ?? '',
                        billNo: x['billNo']?.toString() ?? '-',
                        balance: balance,
                      ),
                    ),
                  ),
                  child: const Text('Payment'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class NewCreditPage extends StatefulWidget {
  const NewCreditPage({super.key});
  @override
  State<NewCreditPage> createState() => _NewCreditPageState();
}

class _NewCreditPageState extends State<NewCreditPage> {
  final kcn = TextEditingController();
  final bill = TextEditingController();
  final amount = TextEditingController();
  DateTime due = DateTime.now().add(const Duration(days: 30));
  DateTime entryDate = DateTime.now();
  Map<String, dynamic>? farmer;
  bool loading = false;
  bool allowBackdate = false;
  bool backdateApproved = false;
  int maxBackdateYears = 7;
  bool requestingApproval = false;

  @override
  void initState() {
    super.initState();
    _loadBackdatePolicy();
  }

  Future<void> _loadBackdatePolicy() async {
    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) return;
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection(Collections.settings).doc('network').get(),
        db.collection(Collections.users).doc(uid).get(),
      ]);
      final settings = results[0].data() as Map<String, dynamic>? ?? {};
      final user = results[1].data() as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        allowBackdate = settings['allowBackdatedEntries'] == true;
        final requestedYears = ((settings['maxBackdateYears'] ?? 7) as num).toInt();
        maxBackdateYears = requestedYears < 1 ? 1 : (requestedYears > 20 ? 20 : requestedYears);
        backdateApproved = user['backdateApproved'] == true;
      });
    } catch (_) {}
  }

  Future<void> _requestBackdateApproval() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => requestingApproval = true);
    try {
      await FirebaseFirestore.instance.collection(Collections.backdateRequests).doc(uid).set({
        'kendraId': uid,
        'requestedYears': maxBackdateYears,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Back-date permission request sent to Admin.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => requestingApproval = false);
    }
  }

  @override
  void dispose() { kcn.dispose(); bill.dispose(); amount.dispose(); super.dispose(); }

  Future<void> _find() async {
    final value = kcn.text.trim();
    if (value.isEmpty) return;
    setState(() => loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection(Collections.farmers).where('kcnId', isEqualTo: value).limit(1).get();
      setState(() => farmer = snap.docs.isEmpty ? null : snap.docs.first.data());
      if (farmer == null) _msg('Farmer not found.');
    } catch (e) { _msg(e.toString()); } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _save() async {
    final uid = AuthService.instance.currentUser?.uid;
    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (uid == null) return;
    if (farmer == null) { _msg('Find a farmer first.'); return; }
    if (bill.text.trim().isEmpty || value <= 0) { _msg('Enter bill and amount.'); return; }
    setState(() => loading = true);
    try {
      await CreditService(FirebaseFirestore.instance).createCredit(kendraId: uid, farmerId: farmer!['uid'].toString(), farmerName: farmer!['name'].toString(), kcnId: farmer!['kcnId'].toString(), billNo: bill.text, amount: value, dueDate: due, entryDate: entryDate, allowBackdate: allowBackdate, maxBackdateYears: maxBackdateYears);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credit entry saved.')));
      Navigator.pop(context);
    } catch (e) { _msg(e.toString()); } finally { if (mounted) setState(() => loading = false); }
  }

  void _msg(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.replaceFirst('Exception: ', '')))); }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstEntryDate = (allowBackdate && backdateApproved)
        ? DateTime(today.year - maxBackdateYears, today.month, today.day)
        : today;
    return Scaffold(
      appBar: AppBar(title: const Text('New Credit')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(controller: kcn, decoration: const InputDecoration(labelText: 'Farmer KCN ID', prefixIcon: Icon(Icons.badge_outlined)), onSubmitted: (_) => _find()),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(onPressed: loading ? null : _find, icon: const Icon(Icons.search), label: const Text('Find Farmer')),
          const SizedBox(height: 10),
          if (farmer != null) Card(child: ListTile(leading: const Icon(Icons.person), title: Text(farmer!['name']?.toString() ?? '-'), subtitle: Text('${farmer!['kcnId'] ?? '-'} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${farmer!['mobile'] ?? '-'}'))),
          const SizedBox(height: 10),
          TextField(controller: bill, decoration: const InputDecoration(labelText: 'Bill Number', prefixIcon: Icon(Icons.receipt_long))),
          const SizedBox(height: 10),
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Credit Amount', prefixText: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹ ')),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Entry Date'),
            subtitle: Text(_formatDate(entryDate)),
            trailing: IconButton(
              icon: const Icon(Icons.event),
              onPressed: loading ? null : () async {
                final d = await showDatePicker(context: context, firstDate: firstEntryDate, lastDate: today, initialDate: entryDate.isBefore(firstEntryDate) ? firstEntryDate : entryDate);
                if (d != null) setState(() => entryDate = d);
              },
            ),
          ),
          if (!allowBackdate)
            const Text('Back-dated entry is disabled globally by Admin.', style: TextStyle(fontSize: 12))
          else if (!backdateApproved) ...[
            const Text('Up to 7-year back-date is available only after Admin approval.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            OutlinedButton.icon(onPressed: requestingApproval ? null : _requestBackdateApproval, icon: const Icon(Icons.history_toggle_off), label: Text(requestingApproval ? 'Sending request...' : 'Request Admin Back-Date Permission')),
          ]
          else
            Text('Admin approved back-date window: up to $maxBackdateYears years.', style: const TextStyle(fontSize: 12, color: Colors.green)),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Due Date'),
            subtitle: Text(_formatDate(due)),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: loading ? null : () async {
                final d = await showDatePicker(context: context, firstDate: today, lastDate: today.add(const Duration(days: 3650)), initialDate: due);
                if (d != null) setState(() => due = d);
              },
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: loading ? null : _save, icon: const Icon(Icons.save), label: Text(loading ? 'Saving...' : 'Save Credit')),
        ],
      ),
    );
  }
}

String _formatDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
}

class KendraOutstandingPage extends StatelessWidget {
  const KendraOutstandingPage({super.key});

  Future<void> _sendFollowUp(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final x = doc.data();
    await FirebaseFirestore.instance
        .collection(Collections.paymentFollowups)
        .doc(doc.id)
        .set({
      'creditId': doc.id,
      'kendraId': uid,
      'farmerId': x['farmerId'],
      'farmerName': x['farmerName'],
      'kcnId': x['kcnId'],
      'billNo': x['billNo'],
      'balanceAmount': x['balanceAmount'],
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final callCenters = await FirebaseFirestore.instance
        .collection(Collections.users)
        .where('role', isEqualTo: 'callCenter')
        .get();
    for (final callCenter in callCenters.docs) {
      final centerData = callCenter.data();
      final centerActive = centerData['isActive'] == true
          && ['active', 'approved'].contains(centerData['status']?.toString());
      if (!centerActive) continue;
      await NotificationService.instance.create(
        recipientId: callCenter.id,
        title: 'Payment follow-up request',
        message: 'A Krishi Kendra requested a payment follow-up for ${x['farmerName'] ?? 'Farmer'} (${x['billNo'] ?? '-'}) with outstanding ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((x['balanceAmount'] ?? 0) as num).toDouble())}.',
        type: 'payment_followup',
        payload: {'followupId': doc.id, 'kendraId': uid, 'farmerId': x['farmerId']},
      );
    }

    final farmerId = x['farmerId']?.toString() ?? '';
    if (farmerId.isNotEmpty) {
      await NotificationService.instance.create(
        recipientId: farmerId,
        title: 'Payment follow-up',
        message: 'A payment follow-up has been requested for your KCN bill ${x['billNo'] ?? '-'} with outstanding ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((x['balanceAmount'] ?? 0) as num).toDouble())}.',
        type: 'payment_followup_farmer',
        payload: {'followupId': doc.id, 'kendraId': uid, 'billNo': x['billNo']},
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call Center follow-up request sent.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(Collections.credits)
          .where('krishiKendraId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Unable to load outstanding.\n${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs.where((d) {
          final balance = ((d.data()['balanceAmount'] ?? 0) as num).toDouble();
          return balance > 0;
        }).toList()
          ..sort(
            (a, b) =>
                ((b.data()['balanceAmount'] ?? 0) as num).compareTo(
              (a.data()['balanceAmount'] ?? 0) as num,
            ),
          );

        if (docs.isEmpty) {
          return const Center(child: Text('No outstanding bills.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final x = doc.data();
            final balance = ((x['balanceAmount'] ?? 0) as num).toDouble();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.red),
                title: Text('${x['farmerName'] ?? '-'} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${x['billNo'] ?? '-'}'),
                subtitle: Text(
                  'KCN ${x['kcnId'] ?? '-'}\nBalance ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(balance)}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 2,
                  children: [
                    IconButton(
                      tooltip: 'Payment',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentPage(
                            creditId: doc.id,
                            farmerId: x['farmerId']?.toString() ?? '',
                            billNo: x['billNo']?.toString() ?? '-',
                            balance: balance,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.payments_outlined),
                    ),
                    IconButton(
                      tooltip: 'Call Center Follow-up',
                      onPressed: () => _sendFollowUp(context, doc),
                      icon: const Icon(Icons.phone_in_talk_outlined),
                    ),
                    StatusChip(text: x['status']?.toString() ?? 'UNPAID'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class KendraLedgerPage extends StatelessWidget {
  const KendraLedgerPage({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(Collections.credits).where('krishiKendraId', isEqualTo: uid).snapshots(),
      builder: (_, snap) {
        if (snap.hasError) return Center(child: Text('Unable to load ledger.\n${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = [...snap.data!.docs]..sort((a, b) => _ts(b.data()['createdAt']).compareTo(_ts(a.data()['createdAt'])));
        if (docs.isEmpty) return const Center(child: Text('No ledger entries.'));
        return ListView.separated(padding: const EdgeInsets.all(16), itemCount: docs.length + 1, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, i) => i == 0 ? const KcnAdBanner() : LedgerTile(credit: docs[i - 1]));
      },
    );
  }
}

class LedgerTile extends StatefulWidget {
  const LedgerTile({required this.credit, super.key});
  final QueryDocumentSnapshot<Map<String, dynamic>> credit;
  @override
  State<LedgerTile> createState() => _LedgerTileState();
}

class _LedgerTileState extends State<LedgerTile> {
  @override
  Widget build(BuildContext context) {
    final d = widget.credit.data();
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text('Bill ${d['billNo'] ?? '-'}'),
        subtitle: Text('${d['farmerName'] ?? '-'} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Balance ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((d['balanceAmount'] ?? 0) as num).toDouble())}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total: ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((d['amount'] ?? 0) as num).toDouble())}'), Text('Paid: ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((d['paidAmount'] ?? 0) as num).toDouble())}'), Text('Balance: ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((d['balanceAmount'] ?? 0) as num).toDouble())}'), const Divider(), const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6), PaymentHistory(creditId: widget.credit.id)]),
          ),
        ],
      ),
    );
  }
}

class PaymentHistory extends StatelessWidget {
  const PaymentHistory({required this.creditId, super.key});
  final String creditId;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(Collections.payments).where('creditId', isEqualTo: creditId).snapshots(),
      builder: (_, snap) {
        if (snap.hasError) return Text('Payment history unavailable: ${snap.error}');
        if (!snap.hasData) return const LinearProgressIndicator();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Text('No payment recorded.');
        return Column(children: docs.map((d) { final x = d.data(); return ListTile(dense: true, leading: const Icon(Icons.payments_outlined), title: Text('ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((x['amount'] ?? 0) as num).toDouble())}'), subtitle: Text('${x['mode'] ?? '-'} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${formatTs(x['paymentDate'] ?? x['createdAt'])}')); }).toList());
      },
    );
  }
}

class PaymentPage extends StatefulWidget {
  const PaymentPage({required this.creditId, required this.farmerId, required this.billNo, required this.balance, super.key});
  final String creditId;
  final String farmerId;
  final String billNo;
  final double balance;
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final amount = TextEditingController();
  String mode = 'Cash';
  bool saving = false;
  DateTime entryDate = DateTime.now();
  bool allowBackdate = false;
  bool backdateApproved = false;
  int maxBackdateYears = 7;
  bool requestingApproval = false;
  @override
  void initState() {
    super.initState();
    _loadBackdatePolicy();
  }

  Future<void> _loadBackdatePolicy() async {
    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) return;
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection(Collections.settings).doc('network').get(),
        db.collection(Collections.users).doc(uid).get(),
      ]);
      final settings = results[0].data() as Map<String, dynamic>? ?? {};
      final user = results[1].data() as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        allowBackdate = settings['allowBackdatedEntries'] == true;
        final requestedYears = ((settings['maxBackdateYears'] ?? 7) as num).toInt();
        maxBackdateYears = requestedYears < 1 ? 1 : (requestedYears > 20 ? 20 : requestedYears);
        backdateApproved = user['backdateApproved'] == true;
      });
    } catch (_) {}
  }

  Future<void> _requestBackdateApproval() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => requestingApproval = true);
    try {
      await FirebaseFirestore.instance.collection(Collections.backdateRequests).doc(uid).set({
        'kendraId': uid,
        'requestedYears': maxBackdateYears,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Back-date permission request sent to Admin.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => requestingApproval = false);
    }
  }

  @override
  void dispose() { amount.dispose(); super.dispose(); }
  Future<void> _save() async {
    final uid = AuthService.instance.currentUser?.uid;
    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (uid == null || value <= 0 || value > widget.balance) { _msg('Enter a valid amount.'); return; }
    setState(() => saving = true);
    try {
      await CreditService(FirebaseFirestore.instance).recordPayment(creditId: widget.creditId, farmerId: widget.farmerId, kendraId: uid, amount: value, mode: mode, entryDate: entryDate, allowBackdate: allowBackdate, maxBackdateYears: maxBackdateYears);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded.')));
      Navigator.pop(context);
    } catch (e) { _msg(e.toString()); } finally { if (mounted) setState(() => saving = false); }
  }
  void _msg(String x) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(x.replaceFirst('Exception: ', '')))); }
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstEntryDate = (allowBackdate && backdateApproved)
        ? DateTime(today.year - maxBackdateYears, today.month, today.day)
        : today;
    return Scaffold(
      appBar: AppBar(title: Text('Payment ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${widget.billNo}')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('Outstanding: ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(widget.balance)}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Payment amount', prefixText: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹ ')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: mode, decoration: const InputDecoration(labelText: 'Payment mode'), items: const [DropdownMenuItem(value: 'Cash', child: Text('Cash')), DropdownMenuItem(value: 'UPI', child: Text('UPI')), DropdownMenuItem(value: 'Bank', child: Text('Bank')), DropdownMenuItem(value: 'Other', child: Text('Other'))], onChanged: saving ? null : (v) => setState(() => mode = v ?? 'Cash')),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Payment Date'),
            subtitle: Text(_formatDate(entryDate)),
            trailing: IconButton(
              icon: const Icon(Icons.event),
              onPressed: saving ? null : () async {
                final d = await showDatePicker(context: context, firstDate: firstEntryDate, lastDate: today, initialDate: entryDate.isBefore(firstEntryDate) ? firstEntryDate : entryDate);
                if (d != null) setState(() => entryDate = d);
              },
            ),
          ),
          if (!allowBackdate)
            const Text('Back-dated payment is disabled globally by Admin.', style: TextStyle(fontSize: 12))
          else if (!backdateApproved) ...[
            const Text('Up to 7-year back-date is available only after Admin approval.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            OutlinedButton.icon(onPressed: requestingApproval ? null : _requestBackdateApproval, icon: const Icon(Icons.history_toggle_off), label: Text(requestingApproval ? 'Sending request...' : 'Request Admin Back-Date Permission')),
          ]
          else
            Text('Admin approved back-date window: up to $maxBackdateYears years.', style: const TextStyle(fontSize: 12, color: Colors.green)),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: saving ? null : _save, icon: const Icon(Icons.save), label: Text(saving ? 'Saving...' : 'Record Payment')),
        ],
      ),
    );
  }
}

class KendraSearchPage extends StatefulWidget {
  const KendraSearchPage({super.key});
  @override
  State<KendraSearchPage> createState() => _KendraSearchPageState();
}
class _KendraSearchPageState extends State<KendraSearchPage> {
  final controller = TextEditingController();
  Map<String, dynamic>? result;
  bool loading = false;
  Future<void> _search() async { final q = controller.text.trim(); if (q.isEmpty) return; setState(() => loading = true); try { final snap = await FirebaseFirestore.instance.collection(Collections.creditPublic).where('kcnId', isEqualTo: q).limit(1).get(); setState(() => result = snap.docs.isEmpty ? null : snap.docs.first.data()); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } finally { if (mounted) setState(() => loading = false); } }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  Future<void> _requestDetail() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || result == null) return;
    final farmerId = result!['farmerId'].toString();
    final requestRef = FirebaseFirestore.instance.collection(Collections.accessRequests).doc();
    await requestRef.set({
      'kendraId': uid,
      'farmerId': farmerId,
      'kcnId': result!['kcnId'],
      'farmerName': result!['farmerName'] ?? '-',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await NotificationService.instance.create(
      recipientId: farmerId,
      title: 'Credit access request',
      message: 'A Krishi Kendra has requested detailed access to your KCN credit information.',
      type: 'access_request',
      payload: {
        'requestId': requestRef.id,
        'kendraId': uid,
        'farmerId': farmerId,
        'farmerName': result!['farmerName'] ?? '-',
        'kcnId': result!['kcnId'] ?? '-',
      },
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission request sent to farmer.')),
      );
    }
  }
  @override
  Widget build(BuildContext context) { return ListView(padding: const EdgeInsets.all(16), children: [const KcnAdBanner(), Text('KCN Farmer Search', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12), TextField(controller: controller, decoration: InputDecoration(labelText: 'KCN ID', prefixIcon: const Icon(Icons.badge), suffixIcon: IconButton(onPressed: loading ? null : _search, icon: const Icon(Icons.search))), onSubmitted: (_) => _search()), const SizedBox(height: 14), if (result == null && !loading) const InfoBanner(text: 'Search shows only approved KCN public risk summary.'), if (loading) const Center(child: CircularProgressIndicator()), if (result != null) Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(result!['farmerName']?.toString() ?? '-', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text('KCN ID: ${result!['kcnId'] ?? '-'}'), const SizedBox(height: 12), Row(children: [Expanded(child: StatCard(label: 'Score', value: '${result!['creditScore'] ?? 650}', icon: Icons.speed)), const SizedBox(width: 10), Expanded(child: StatCard(label: 'Unpaid Bill', value: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((result!['outstanding'] ?? 0) as num).toDouble())}', icon: Icons.warning_amber_outlined))]), const SizedBox(height: 10), Text('Active Centers: ${result!['activeCenters'] ?? 0}'), Text('Overdue Centers: ${result!['overdueCenters'] ?? 0}'), const SizedBox(height: 14), FilledButton.icon(onPressed: _requestDetail, icon: const Icon(Icons.lock_open), label: const Text('Request Detailed Access'))])) )]); }
}

class CallCenterDashboard extends StatefulWidget {
  const CallCenterDashboard({super.key});
  @override
  State<CallCenterDashboard> createState() => _CallCenterDashboardState();
}

class _CallCenterDashboardState extends State<CallCenterDashboard> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      CallOverview(onOpenTab: (value) => setState(() => tab = value)),
      const FeatureGate(featureKey: 'callOrdersEnabled', title: 'Network Orders are currently disabled', child: CallOrders()),
      const FeatureGate(featureKey: 'callMembersEnabled', title: 'Network Members are currently disabled', child: CallMembers()),
      const FeatureGate(featureKey: 'callRewardsEnabled', title: 'Rewards are currently disabled', child: CallRewards()),
      const FeatureGate(featureKey: 'callFollowupEnabled', title: 'Payment Follow-up is currently disabled', child: CallPaymentFollowups()),
    ];
    final destinations = const <NavigationDestination>[
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
      NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
      NavigationDestination(icon: Icon(Icons.people_outline), label: 'Members'),
      NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Rewards'),
      NavigationDestination(icon: Icon(Icons.phone_in_talk_outlined), label: 'Follow-up'),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('KCN Call Center'),
        actions: [const NotificationIcon(), const UpdateCheckButton(), IconButton(tooltip: 'Logout', onPressed: AuthService.instance.signOut, icon: const Icon(Icons.logout))],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: tab,
                  onDestinationSelected: (v) => setState(() => tab = v),
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations.map((d) => NavigationRailDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: Text(d.label))).toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[tab]),
              ],
            )
          : pages[tab],
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (v) {
              if (v == tab) return;
              AdService.instance.onUserNavigation();
              setState(() => tab = v);
            },
            destinations: destinations,
          ),
    );
  }
}


class CallOrders extends StatelessWidget {
  const CallOrders({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(Collections.orders)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('Unable to load orders.\n${snap.error}'),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = [...snap.data!.docs]
          ..sort(
            (a, b) => _ts(b.data()['createdAt'])
                .compareTo(_ts(a.data()['createdAt'])),
          );

        if (docs.isEmpty) {
          return const Center(child: Text('No network orders yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data();
            final orderedQty = KcnOrderWorkflow.orderedQuantity(d);
            final status = d['status']?.toString() ?? 'pending';
            final paymentStatus =
                d['paymentStatus']?.toString() ?? 'pending';

            return Card(
              child: ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text(
                  d['productName']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Order: ${doc.id}\n'
                  'Farmer: ${d['farmerName']?.toString() ?? d['farmerId']?.toString() ?? '-'}\n'
                  'Qty: $orderedQty\n'
                  'Amount: Rs ${money(((d['totalAmount'] ?? 0) as num).toDouble())}\n'
                  'Status: ${KcnOrderWorkflow.statusLabel(status)}\n'
                  'Payment: ${KcnOrderWorkflow.paymentStatusLabel(paymentStatus)}',
                ),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: () => KcnOrderWorkflow.open(context, doc),
                  child: const Text('Manage'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class CallMembers extends StatelessWidget {
  const CallMembers({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(Collections.networkMembers)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Unable to load members.\n${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No network members yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final d = docs[index].data();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(d['farmerName']?.toString() ?? d['farmerId']?.toString() ?? '-'),
                subtitle: Text(
                  'Sponsor: ${d['sponsorId']?.toString() ?? '-'}\n'
                  'Level: ${d['level'] ?? 1}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class CallRewards extends StatelessWidget {
  const CallRewards({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(Collections.rewards)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Unable to load rewards.\n${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No network rewards yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final d = docs[index].data();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.stars_outlined),
                title: Text('ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((d['amount'] ?? 0) as num).toDouble())}'),
                subtitle: Text(
                  'Farmer: ${d['farmerId']?.toString() ?? '-'}\n'
                  'Status: ${d['status']?.toString() ?? 'pending'}',
                ),
                isThreeLine: true,
                trailing: StatusChip(text: d['status']?.toString() ?? 'pending'),
              ),
            );
          },
        );
      },
    );
  }
}

class CallPaymentFollowups extends StatelessWidget {
  const CallPaymentFollowups({super.key});

  Future<void> _update(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc, String status) async {
    await doc.reference.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'contacted') 'contactedAt': FieldValue.serverTimestamp(),
    });
    final kendraId = doc.data()['kendraId']?.toString() ?? '';
    if (kendraId.isNotEmpty) {
      await NotificationService.instance.create(
        recipientId: kendraId,
        title: 'Payment follow-up updated',
        message: 'Call Center marked the payment follow-up as $status for ${doc.data()['farmerName'] ?? 'Farmer'}.',
        type: 'payment_followup_result',
        payload: {'followupId': doc.id, 'status': status},
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Follow-up marked $status.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(Collections.paymentFollowups).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Unable to load follow-up requests.\n${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No payment follow-up requests.'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final status = d['status']?.toString() ?? 'pending';
            return Card(
              child: ListTile(
                leading: const Icon(Icons.phone_in_talk_outlined),
                title: Text('${d['farmerName'] ?? '-'} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${d['billNo'] ?? '-'}'),
                subtitle: Text('KCN ${d['kcnId'] ?? '-'}\nOutstanding ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((d['balanceAmount'] ?? 0) as num).toDouble())}\nStatus: $status'),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => _update(context, docs[i], v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'contacted', child: Text('Contacted')),
                    PopupMenuItem(value: 'payment_promised', child: Text('Payment Promised')),
                    PopupMenuItem(value: 'unable_to_contact', child: Text('Unable to Contact')),
                    PopupMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  child: StatusChip(text: status),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class CallOverview extends StatelessWidget {
  const CallOverview({required this.onOpenTab, super.key});
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Network Operations', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const InfoBanner(text: 'Call Center handles network support, customer and order operations. Krishi Kendra credit data remains separate.'),
        const SizedBox(height: 12),
        const GlobalAdvertisementBanner(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _actionCard('Network Orders', Icons.receipt_long, 1, onOpenTab)),
            const SizedBox(width: 10),
            Expanded(child: _actionCard('Network Members', Icons.people_outline, 2, onOpenTab)),
            const SizedBox(width: 10),
            Expanded(child: _actionCard('Rewards', Icons.stars, 3, onOpenTab)),
          ],
        ),
      ],
    );
  }

  Widget _actionCard(String title, IconData icon, int tab, ValueChanged<int> onOpenTab) {
    return Card(
      child: InkWell(
        onTap: () => onOpenTab(tab),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(icon, size: 34),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Open', style: TextStyle(color: Colors.green)),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    _seedDemo();
  }

  Future<void> _seedDemo() async {
    try {
      final db = FirebaseFirestore.instance;
      final settings = db.collection(Collections.settings).doc('network');
      final settingsSnap = await settings.get();
      final existing = settingsSnap.data() ?? <String, dynamic>{};
      final defaults = <String, dynamic>{
        'rewardPoolPercent': 10.0,
        'level1Percent': 50.0,
        'level2Percent': 20.0,
        'level3Percent': 10.0,
        'level4Percent': 0.0,
        'level5Percent': 0.0,
        'level6Percent': 0.0,
        'level7Percent': 0.0,
        'level8Percent': 0.0,
        'level9Percent': 0.0,
        'level10Percent': 0.0,
        'bonusPoolPercent': 20.0,
        'otherExpenseTotal': 0.0,
        'adMobRevenueTotal': 0.0,
        'allowBackdatedEntries': true,
        'maxBackdateYears': 7,
        'backdateApprovalRequired': true,
      };
      final missing = <String, dynamic>{};
      defaults.forEach((k, v) { if (!existing.containsKey(k)) missing[k] = v; });
      if (missing.isNotEmpty) {
        missing['updatedAt'] = FieldValue.serverTimestamp();
        await settings.set(missing, SetOptions(merge: true));
      }

      final featureRef = db.collection(Collections.settings).doc('features');
      final featureSnap = await featureRef.get();
      final featureExisting = featureSnap.data() ?? <String, dynamic>{};
      final featureMissing = <String, dynamic>{};
      FeatureSettings.defaults.forEach((key, value) {
        if (!featureExisting.containsKey(key)) featureMissing[key] = value;
      });
      if (featureMissing.isNotEmpty) {
        featureMissing['updatedAt'] = FieldValue.serverTimestamp();
        await featureRef.set(featureMissing, SetOptions(merge: true));
      }

      final updateRef = db.collection(Collections.settings).doc('app_update');
      final updateSnap = await updateRef.get();
      if (!updateSnap.exists) {
        await updateRef.set({
          'minVersion': '1.0.0',
          'forceUpdate': false,
          'message': 'A new KCN update is available.',
          'androidUrl': 'https://play.google.com/store/apps/details?id=in.thekcn.kcn',
          'webUrl': 'https://thekcn.in',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      AdminOverview(onOpenTab: (v) => setState(() => tab = v)),
      const AdminApprovals(),
      const AdminProducts(),
      const AdminProductGroups(),
      const AdminOrders(),
      const AdminSales(),
      const AdminNetwork(),
      const AdminPayouts(),
      const AdminRules(),
      const AdminBackdateApprovals(),
      const AdminAdvertisements(),
      const AdminUsers(),
      const AdminPaymentCorrections(),
      const AdminUpdateSettings(),
      const AdminNetworkJoinRequests(),
    ];
    final destinations = const <NavigationDestination>[
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
      NavigationDestination(icon: Icon(Icons.verified_user_outlined), label: 'Approvals'),
      NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Products'),
      NavigationDestination(icon: Icon(Icons.category_outlined), label: 'Groups'),
      NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
      NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Sales'),
      NavigationDestination(icon: Icon(Icons.account_tree_outlined), label: 'Network'),
      NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Payouts'),
      NavigationDestination(icon: Icon(Icons.tune), label: 'Rules'),
      NavigationDestination(icon: Icon(Icons.history_toggle_off), label: 'Back-Date'),
      NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'Ads'),
      NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'Users'),
      NavigationDestination(icon: Icon(Icons.rule_folder_outlined), label: 'Payment Fix'),
      NavigationDestination(icon: Icon(Icons.system_update_alt), label: 'App Update'),
      NavigationDestination(icon: Icon(Icons.how_to_reg_outlined), label: 'Network Join'),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('KCN Admin'),
        actions: [
          const NotificationIcon(),
          IconButton(tooltip: 'Legal & Support', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalSupportPage())), icon: const Icon(Icons.info_outline)),
          IconButton(
            tooltip: 'App Feature Settings',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFeatureSettings())),
            icon: const Icon(Icons.settings_outlined),
          ),
          const UpdateCheckButton(),
          IconButton(tooltip: 'Logout', onPressed: AuthService.instance.signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: wide
          ? Row(children: [
              NavigationRail(
                selectedIndex: tab,
                onDestinationSelected: (v) => setState(() => tab = v),
                labelType: NavigationRailLabelType.all,
                destinations: destinations.map((d) => NavigationRailDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: Text(d.label))).toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: pages[tab]),
            ])
          : pages[tab],
      bottomNavigationBar: wide ? null : NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) { if (v == tab) return; AdService.instance.onUserNavigation(); setState(() => tab = v); },
        destinations: destinations,
      ),
    );
  }
}

class AdminOverview extends StatelessWidget {
  const AdminOverview({required this.onOpenTab, super.key});
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Super Admin Dashboard', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const GlobalAdvertisementBanner(),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection(Collections.orders).snapshots(),
          builder: (context, orderSnap) {
            final orders = orderSnap.data?.docs ?? const [];
            final sales = orders.fold<double>(0, (sum, d) => sum + ((d.data()['totalAmount'] ?? 0) as num).toDouble());
            return Row(children: [
              Expanded(child: StatCard(label: 'Network Sales', value: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(sales)}', icon: Icons.sell_outlined)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(label: 'Orders', value: '${orders.length}', icon: Icons.receipt_long_outlined)),
            ]);
          },
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _action('Users', Icons.people_alt_outlined, 11),
          _action('Approvals', Icons.verified_user_outlined, 1),
          _action('Products', Icons.inventory_2_outlined, 2),
          _action('Product Groups', Icons.category_outlined, 3),
          _action('Orders', Icons.receipt_long_outlined, 4),
          _action('Sales / Profit', Icons.bar_chart_outlined, 5),
          _action('Network Tree', Icons.account_tree_outlined, 6),
          _action('Payouts', Icons.payments_outlined, 7),
          _action('Network Rules', Icons.tune, 8),
          _action('Back-Date', Icons.history_toggle_off, 9),
          _action('Advertisements', Icons.campaign_outlined, 10),
          _action('Users', Icons.people_alt_outlined, 11),
          _action('Payment Fix', Icons.rule_folder_outlined, 12),
          _action('App Update', Icons.system_update_alt, 13),
          _action('Network Join Requests', Icons.how_to_reg_outlined, 14),
        ]),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('App Feature Settings'),
            subtitle: const Text('Turn supported Farmer, Krishi Kendra, Call Center and advertising options on or off.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFeatureSettings())),
          ),
        ),
        const SizedBox(height: 16),
        const InfoBanner(text: 'Company cost, network payouts and final company profit are Admin-only. Krishi Kendra does not receive Network Marketing business data.'),
      ],
    );
  }

  Widget _action(String label, IconData icon, int tab) {
    return SizedBox(width: 205, child: Card(child: InkWell(onTap: () => onOpenTab(tab), borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Icon(icon, size: 32), const SizedBox(height: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 5), const Text('Open', style: TextStyle(color: Colors.green))])))));
  }
}

class AdminApprovals extends StatelessWidget {
  const AdminApprovals({super.key});

  Future<void> _approveUser(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final db = FirebaseFirestore.instance;
    final data = doc.data();
    final role = data['role']?.toString() ?? '';

    if (role != 'farmer') {
      await doc.reference.update({
        'status': 'approved',
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final aadhaarHash = data['aadhaarHash']?.toString() ?? '';
    if (aadhaarHash.length != 64 || data['aadhaarConsent'] != true) {
      throw Exception('Farmer has not supplied valid Aadhaar consent information.');
    }

    // Prevent duplicate KCN IDs generated from the same Aadhaar hash.
    final duplicate = await db
        .collection(Collections.users)
        .where('aadhaarHash', isEqualTo: aadhaarHash)
        .limit(2)
        .get();

    for (final other in duplicate.docs) {
      if (other.id != doc.id && other.data()['aadhaarVerified'] == true) {
        throw Exception('This Aadhaar identity is already linked to another KCN account.');
      }
    }

    final kcnId = 'KCN-${aadhaarHash.substring(0, 12).toUpperCase()}';
    final batch = db.batch();

    batch.update(doc.reference, {
      'status': 'approved',
      'isActive': true,
      'aadhaarVerified': true,
      'kcnId': kcnId,
      'referralCode': data['referralCode']?.toString() ?? 'KCN-RF${doc.id.substring(0, 8).toUpperCase()}',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      db.collection(Collections.farmers).doc(doc.id),
      {
        'uid': doc.id,
        'kcnId': kcnId,
        'aadhaarVerified': true,
        'aadhaarLast4': data['aadhaarLast4']?.toString() ?? '',
        'name': data['name']?.toString() ?? '',
        'mobile': data['mobile']?.toString() ?? '',
        'village': data['village']?.toString() ?? '',
        'district': data['district']?.toString() ?? '',
        'state': data['state']?.toString() ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      db.collection(Collections.creditProfiles).doc(doc.id),
      {
        'farmerId': doc.id,
        'kcnId': kcnId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      db.collection(Collections.creditPublic).doc(doc.id),
      {
        'farmerId': doc.id,
        'kcnId': kcnId,
        'farmerName': data['name']?.toString() ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Create the network membership during approval, because the farmer
    // document already exists before approval and therefore would not trigger
    // a create-only Cloud Function.
    final referral = data['referralInput']?.toString().trim() ?? '';
    if (referral.isNotEmpty) {
      final sponsorSnap = await db
          .collection(Collections.farmers)
          .where('referralCode', isEqualTo: referral)
          .limit(1)
          .get();
      if (!sponsorSnap.docs.isEmpty && sponsorSnap.docs.first.id != doc.id) {
        final sponsor = sponsorSnap.docs.first;
        var level = 1;
        final sponsorMember = await db
            .collection(Collections.networkMembers)
            .doc(sponsor.id)
            .get();
        if (sponsorMember.exists) {
          level = ((sponsorMember.data()?['level'] ?? 0) as num).toInt() + 1;
        }
        batch.set(
          db.collection(Collections.networkMembers).doc(doc.id),
          {
            'farmerId': doc.id,
            'memberName': data['name']?.toString() ?? '',
            'kcnId': kcnId,
            'referralCode': data['referralCode']?.toString() ?? '',
            'sponsorId': sponsor.id,
            'sponsorName': sponsor.data()['name']?.toString() ?? '',
            'sponsorKcnId': sponsor.data()['kcnId']?.toString() ?? '',
            'level': level,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    await batch.commit();
    await NotificationService.instance.create(
      recipientId: doc.id,
      title: 'KCN account approved',
      message: 'Your KCN account has been approved. You can now use your KCN dashboard.',
      type: 'account_approval',
      payload: {'kcnId': kcnId, 'role': role},
    );
  }

  Future<void> _rejectUser(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    await doc.reference.update({
      'status': 'rejected',
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await NotificationService.instance.create(
      recipientId: doc.id,
      title: 'KCN account rejected',
      message: 'Your KCN account request was not approved. Please contact KCN support.',
      type: 'account_rejection',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(Collections.users)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(snap.error.toString()));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No pending approvals.'));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final isFarmer = data['role'] == 'farmer';

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.person)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('${data['role'] ?? '-'} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${data['email'] ?? '-'}'),
                          if (isFarmer)
                            Text('Aadhaar: ******${data['aadhaarLast4'] ?? '----'}'),
                        ],
                      ),
                    ),
                    Wrap(
                      children: [
                        IconButton(
                          tooltip: isFarmer ? 'Mark Aadhaar verified & approve' : 'Approve',
                          onPressed: () async {
                            try {
                              await _approveUser(doc);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(isFarmer ? 'Aadhaar marked verified and KCN approved.' : 'Account approved.')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.check, color: Colors.green),
                        ),
                        IconButton(
                          tooltip: 'Reject',
                          onPressed: () async {
                            try {
                              await _rejectUser(doc);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.close, color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AdminNetworkJoinRequests extends StatelessWidget {
  const AdminNetworkJoinRequests({super.key});

  Future<void> _approve(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      final farmerId = doc.id;
      final farmer = doc.data();
      final requestRaw = farmer['networkJoinRequest'];

      if (requestRaw is! Map) {
        throw Exception('Invalid network join request.');
      }

      final request = Map<String, dynamic>.from(requestRaw);
      final sponsorId = request['sponsorId']?.toString().trim() ?? '';

      if (sponsorId.isEmpty) {
        throw Exception('Sponsor information is missing.');
      }

      if (sponsorId == farmerId) {
        throw Exception('Farmer cannot sponsor himself/herself.');
      }

      final sponsorRef = db.collection(Collections.farmers).doc(sponsorId);
      final sponsorSnap = await sponsorRef.get();

      if (!sponsorSnap.exists) {
        throw Exception('Sponsor farmer record was not found.');
      }

      final sponsor = sponsorSnap.data() ?? <String, dynamic>{};

      final existingMember = await db
          .collection(Collections.networkMembers)
          .doc(farmerId)
          .get();

      var level = 1;

      if (existingMember.exists) {
        final existingLevel =
            (existingMember.data()?['level'] as num?)?.toInt() ?? 1;
        level = existingLevel < 1 ? 1 : existingLevel;

      } else {
        final sponsorMember = await db
            .collection(Collections.networkMembers)
            .doc(sponsorId)
            .get();

        if (sponsorMember.exists) {
          final sponsorLevel =
              (sponsorMember.data()?['level'] as num?)?.toInt() ?? 0;
          level = sponsorLevel + 1;
        }
      }

      final memberRef = db
          .collection(Collections.networkMembers)
          .doc(farmerId);

      final approvedRequest = <String, dynamic>{
        ...request,
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': AuthService.instance.currentUser?.uid,
      };

      final batch = db.batch();

      batch.set(
        memberRef,
        {
          'farmerId': farmerId,
          'memberName': farmer['name']?.toString() ?? '',
          'kcnId': farmer['kcnId']?.toString() ?? '',
          'referralCode': farmer['referralCode']?.toString() ?? '',
          'sponsorId': sponsorId,
          'sponsorName':
              sponsor['name']?.toString() ??
              request['sponsorName']?.toString() ??
              '',
          'sponsorKcnId':
              sponsor['kcnId']?.toString() ??
              request['sponsorKcnId']?.toString() ??
              '',
          'level': level,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.update(
        doc.reference,
        {
          'networkJoinRequest': approvedRequest,
        },
      );

      await batch.commit();

      await NotificationService.instance.create(
        recipientId: farmerId,
        title: 'KCN Network Join Approved',
        message:
            'Your KCN Network Join Request has been approved. '
            'You are now an Active Network Member.',
        type: 'network_join_approved',
        payload: {
          'sponsorId': sponsorId,
          'sponsorKcnId':
              sponsor['kcnId']?.toString() ??
              request['sponsorKcnId']?.toString() ??
              '',
          'level': level,
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network Join Request approved successfully.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    }
  }

  Future<void> _reject(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    try {
      final farmerId = doc.id;
      final data = doc.data();
      final requestRaw = data['networkJoinRequest'];

      final request = requestRaw is Map
          ? Map<String, dynamic>.from(requestRaw)
          : <String, dynamic>{};

      final rejectedRequest = <String, dynamic>{
        ...request,
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': AuthService.instance.currentUser?.uid,
      };

      await doc.reference.update({
        'networkJoinRequest': rejectedRequest,
      });

      await NotificationService.instance.create(
        recipientId: farmerId,
        title: 'KCN Network Join Request Rejected',
        message:
            'Your KCN Network Join Request was rejected by Admin.',
        type: 'network_join_rejected',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network Join Request rejected.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(Collections.farmers)
          .where(
            'networkJoinRequest.status',
            isEqualTo: 'pending',
          )
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'Unable to load Network Join Requests.\n${snap.error}',
            ),
          );
        }

        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snap.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Network Join Requests',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),

            Card(
              color: const Color(0xFFEAF7EC),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.how_to_reg_outlined, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pending Requests: ${docs.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (docs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'No pending Network Join Requests.',
                  ),
                ),
              ),

            ...docs.map(
              (doc) {
                final data = doc.data();
                final requestRaw = data['networkJoinRequest'];

                final request = requestRaw is Map
                    ? Map<String, dynamic>.from(requestRaw)
                    : <String, dynamic>{};

                final farmerName =
                    data['name']?.toString() ?? '-';

                final farmerKcnId =
                    data['kcnId']?.toString() ?? '-';

                final sponsorName =
                    request['sponsorName']?.toString() ?? '-';

                final sponsorKcnId =
                    request['sponsorKcnId']?.toString() ?? '-';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    farmerName,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Farmer KCN ID: $farmerKcnId',
                                  ),
                                ],
                              ),
                            ),
                            const Chip(
                              label: Text('PENDING'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 10),

                        const Text(
                          'Sponsor Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 6),
                        Text('Sponsor Name: $sponsorName'),
                        Text('Sponsor KCN ID: $sponsorKcnId'),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _approve(context, doc),
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                ),
                                label: const Text('Approve'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _reject(context, doc),
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                ),
                                label: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
class AdminProducts extends StatefulWidget {
  const AdminProducts({super.key});

  @override
  State<AdminProducts> createState() => _AdminProductsState();
}

class _AdminProductsState extends State<AdminProducts> {
  Future<void> _addProduct() async {
    final name = TextEditingController();
    final cost = TextEditingController();
    final price = TextEditingController();
    final points = TextEditingController();
    final stock = TextEditingController(text: '100');
    final technical = TextEditingController();
    final description = TextEditingController();
    final image = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Product'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Product name')),
                TextField(controller: cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Company cost')),
                TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Farmer sale price')),
                TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Points')),
                TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock')),
                TextField(controller: technical, decoration: const InputDecoration(labelText: 'Technical name')),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: image, decoration: const InputDecoration(labelText: 'Photo URL (optional)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await FirebaseFirestore.instance.collection(Collections.products).add({
                  'name': name.text.trim(),
                  'category': 'General',
                  'costPrice': double.tryParse(cost.text) ?? 0,
                  'farmerPrice': double.tryParse(price.text) ?? 0,
                  'points': int.tryParse(points.text) ?? 0,
                  'stock': int.tryParse(stock.text) ?? 0,
                  'technicalName': technical.text.trim(),
                  'description': description.text.trim(),
                  'imageUrl': image.text.trim(),
                  'active': true,
                  'imageAsset': 'assets/images/thar_sample_product.png',
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    for (final controller in [name, cost, price, points, stock, technical, description, image]) {
      controller.dispose();
    }
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _editProduct(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final name = TextEditingController(text: data['name']?.toString() ?? '');
    final cost = TextEditingController(text: '${data['costPrice'] ?? 0}');
    final price = TextEditingController(text: '${data['farmerPrice'] ?? 0}');
    final points = TextEditingController(text: '${data['points'] ?? 0}');
    final stock = TextEditingController(text: '${data['stock'] ?? 0}');
    final image = TextEditingController(text: data['imageUrl']?.toString() ?? '');
    final technical = TextEditingController(text: data['technicalName']?.toString() ?? '');
    final description = TextEditingController(text: data['description']?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Product'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Product name')),
                TextField(controller: cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Company cost')),
                TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Farmer sale price')),
                TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Points')),
                TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock')),
                TextField(controller: technical, decoration: const InputDecoration(labelText: 'Technical name')),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: image, decoration: const InputDecoration(labelText: 'Photo URL (optional)')),
                TextField(controller: image, decoration: const InputDecoration(labelText: 'Photo URL (optional)')),
                TextField(controller: technical, decoration: const InputDecoration(labelText: 'Technical name')),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await doc.reference.update({
                  'name': name.text.trim(),
                  'costPrice': double.tryParse(cost.text) ?? 0,
                  'farmerPrice': double.tryParse(price.text) ?? 0,
                  'points': int.tryParse(points.text) ?? 0,
                  'stock': int.tryParse(stock.text) ?? 0,
                  'imageUrl': image.text.trim(),
                  'technicalName': technical.text.trim(),
                  'description': description.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    for (final controller in [name, cost, price, points, stock, image, technical, description]) {
      controller.dispose();
    }
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _changeStock(QueryDocumentSnapshot<Map<String, dynamic>> doc, int delta) async {
    final current = ((doc.data()['stock'] ?? 0) as num).toInt();
    final next = delta > 0 ? current + delta : (current + delta).clamp(0, 999999);
    await doc.reference.update({
      'stock': next,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteProduct(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    await doc.reference.delete();
  }

  Future<void> _toggleProduct(QueryDocumentSnapshot<Map<String, dynamic>> doc, bool active) async {
    await doc.reference.update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Text('Products', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection(Collections.products).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text(snap.error.toString()));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('No products.'));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final p = doc.data();
                  final stock = ((p['stock'] ?? 0) as num).toInt();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ProductImage(path: p['imageAsset']?.toString(), url: p['imageUrl']?.toString(), size: 70),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['name']?.toString() ?? '-', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Cost ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((p['costPrice'] ?? 0) as num).toDouble())} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Sale ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((p['farmerPrice'] ?? 0) as num).toDouble())}'),
                                Text('Stock: $stock ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Points: ${p['points'] ?? 0}'),
                                Row(children: [const Text('Active'), Switch(value: p['active'] == true, onChanged: (v) => _toggleProduct(doc, v))]),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(tooltip: 'Stock -', onPressed: stock > 0 ? () => _changeStock(doc, -1) : null, icon: const Icon(Icons.remove_circle_outline)),
                                IconButton(tooltip: 'Stock +', onPressed: () => _changeStock(doc, 1), icon: const Icon(Icons.add_circle_outline)),
                              ]),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(tooltip: 'Edit', onPressed: () => _editProduct(doc), icon: const Icon(Icons.edit_outlined)),
                                IconButton(tooltip: 'Delete', onPressed: () => _deleteProduct(doc), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                              ]),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class AdminOrders extends StatelessWidget {
  const AdminOrders({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(Collections.orders)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('Unable to load orders.\n${snap.error}'),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = [...snap.data!.docs]
          ..sort(
            (a, b) => _ts(b.data()['createdAt'])
                .compareTo(_ts(a.data()['createdAt'])),
          );

        if (docs.isEmpty) {
          return const Center(child: Text('No network orders yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data();
            final orderedQty = KcnOrderWorkflow.orderedQuantity(d);
            final status = d['status']?.toString() ?? 'pending';
            final paymentStatus =
                d['paymentStatus']?.toString() ?? 'pending';

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            d['productName']?.toString() ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        StatusChip(
                          text: KcnOrderWorkflow.statusLabel(status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Order: ${doc.id}'),
                    Text(
                      'Farmer: ${d['farmerName']?.toString() ?? d['farmerId']?.toString() ?? '-'}',
                    ),
                    Text('Ordered Qty: $orderedQty'),
                    Text(
                      'Amount: Rs ${money(((d['totalAmount'] ?? 0) as num).toDouble())}',
                    ),
                    Text(
                      'Payment: ${KcnOrderWorkflow.paymentStatusLabel(paymentStatus)}',
                    ),
                    if (status == 'not_dispatched')
                      Text(
                        'Reason: ${d['notDispatchedReason']?.toString() ?? '-'}',
                      ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () =>
                            KcnOrderWorkflow.open(context, doc),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Manage Order'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AdminBackdateApprovals extends StatefulWidget {
  const AdminBackdateApprovals({super.key});
  @override
  State<AdminBackdateApprovals> createState() => _AdminBackdateApprovalsState();
}

class _AdminBackdateApprovalsState extends State<AdminBackdateApprovals> {
  Future<void> _setApproval(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc, String status) async {
    final data = doc.data();
    final kendraId = data['kendraId']?.toString() ?? doc.id;
    try {
      final db = FirebaseFirestore.instance;
      final approve = status == 'approved';
      final enabled = status != 'disabled' && approve;
      await doc.reference.update({
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      await db.collection(Collections.users).doc(kendraId).update({
        'backdateApproved': enabled,
        'backdateApprovedAt': enabled ? FieldValue.serverTimestamp() : null,
      });
      await NotificationService.instance.create(
        recipientId: kendraId,
        title: status == 'approved' ? 'Back-date approved' : status == 'disabled' ? 'Back-date disabled' : 'Back-date rejected',
        message: status == 'approved'
            ? 'Your back-date entry permission has been approved.'
            : status == 'disabled'
                ? 'Your back-date entry permission has been disabled by Admin.'
                : 'Your back-date entry request was rejected by Admin.',
        type: 'backdate_result',
        payload: {'status': status},
      );
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'approved' ? 'Back-date approved.' : status == 'disabled' ? 'Back-date permission disabled.' : 'Back-date request rejected.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(Collections.backdateRequests).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Unable to load back-date requests.\n${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final all = snap.data!.docs;
        final pending = all.where((d) => d.data()['status'] == 'pending').toList();
        final approved = all.where((d) => d.data()['status'] == 'approved').toList();
        final disabled = all.where((d) => d.data()['status'] == 'disabled' || d.data()['status'] == 'rejected').toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Back-Date Permission', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const InfoBanner(text: 'Back-date is separate from Network Rules. Maximum allowed history is 7 years. Each Krishi Kendra requires Admin approval.'),
            const SizedBox(height: 12),
            _section(context, 'Pending Requests', pending, true),
            const SizedBox(height: 16),
            _section(context, 'Approved Permissions', approved, false),
            const SizedBox(height: 16),
            _section(context, 'Rejected / Disabled', disabled, false),
          ],
        );
      },
    );
  }

  Widget _section(BuildContext context, String title, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, bool pending) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$title (${docs.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (docs.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('No entries.'))),
      ...docs.map((doc) {
        final d = doc.data();
        final kendraId = d['kendraId']?.toString() ?? doc.id;
        final status = d['status']?.toString() ?? 'pending';
        return Card(
          child: ListTile(
            leading: const Icon(Icons.history_toggle_off),
            title: Text('Kendra ID: $kendraId'),
            subtitle: Text('Requested: ${d['requestedYears'] ?? 7} years\nStatus: $status'),
            isThreeLine: true,
            trailing: pending
                ? Wrap(children: [
                    IconButton(tooltip: 'Approve', onPressed: () => _setApproval(context, doc, 'approved'), icon: const Icon(Icons.check_circle, color: Colors.green)),
                    IconButton(tooltip: 'Reject', onPressed: () => _setApproval(context, doc, 'rejected'), icon: const Icon(Icons.cancel, color: Colors.red)),
                  ])
                : status == 'approved'
                    ? OutlinedButton.icon(onPressed: () => _setApproval(context, doc, 'disabled'), icon: const Icon(Icons.block), label: const Text('Disable'))
                    : null,
          ),
        );
      }),
    ]);
  }
}

class AdminAdvertisements extends StatefulWidget {
  const AdminAdvertisements({super.key});
  @override
  State<AdminAdvertisements> createState() => _AdminAdvertisementsState();
}

class _AdminAdvertisementsState extends State<AdminAdvertisements> {
  Future<void> _edit({QueryDocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final data = doc?.data() ?? {};
    final title = TextEditingController(text: data['title']?.toString() ?? '');
    final message = TextEditingController(text: data['message']?.toString() ?? '');
    final imageUrl = TextEditingController(text: data['imageUrl']?.toString() ?? '');
    bool active = data['active'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(doc == null ? 'Create Advertisement' : 'Edit Advertisement'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(controller: message, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Message')),
                const SizedBox(height: 10),
                TextField(controller: imageUrl, decoration: const InputDecoration(labelText: 'Image URL (optional)')),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setLocal(() => active = v), title: const Text('Show to all active users')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () async {
              final t = title.text.trim();
              final m = message.text.trim();
              if (t.isEmpty || m.isEmpty) return;
              final ref = doc?.reference ?? FirebaseFirestore.instance.collection(Collections.advertisements).doc();
              await ref.set({
                'title': t,
                'message': m,
                'imageUrl': imageUrl.text.trim(),
                'active': active,
                'createdAt': doc == null ? FieldValue.serverTimestamp() : data['createdAt'],
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              if (context.mounted) Navigator.pop(context, true);
            }, child: const Text('Save')),
          ],
        ),
      ),
    );
    title.dispose(); message.dispose(); imageUrl.dispose();
    if (ok == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Advertisement saved.')));
  }

  Future<void> _delete(QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.reference.delete();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [Expanded(child: Text('Advertisements', style: Theme.of(context).textTheme.headlineSmall)), FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Create Ad'))]),
        const SizedBox(height: 8),
        const InfoBanner(text: 'Active advertisements are shown to Farmer, Krishi Kendra and Call Center users.'),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection(Collections.advertisements).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('Unable to load advertisements.\n${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = [...snap.data!.docs]..sort((a, b) => _ts(b.data()['createdAt']).compareTo(_ts(a.data()['createdAt'])));
            if (docs.isEmpty) return const Text('No advertisements created yet.');
            return Column(children: docs.map((doc) {
              final d = doc.data();
              return Card(child: ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: Text(d['title']?.toString() ?? '-'),
                subtitle: Text('${d['message'] ?? '-'}\n${d['active'] == true ? 'ACTIVE' : 'INACTIVE'}'),
                isThreeLine: true,
                trailing: Wrap(children: [
                  IconButton(onPressed: () => _edit(doc: doc), icon: const Icon(Icons.edit_outlined)),
                  IconButton(onPressed: () => _delete(doc), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                ]),
              ));
            }).toList());
          },
        ),
      ],
    );
  }
}

class GlobalAdvertisementBanner extends StatelessWidget {
  const GlobalAdvertisementBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      featureKey: 'advertisementsEnabled',
      title: 'KCN advertisements are currently disabled',
      child: Column(
        children: [
          const KcnAdBanner(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(Collections.advertisements)
                .where('active', isEqualTo: true)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }
              final docs = [...snap.data!.docs]
                ..sort((a, b) => _ts(b.data()['createdAt'])
                    .compareTo(_ts(a.data()['createdAt'])));
              final d = docs.first.data();
              final image = d['imageUrl']?.toString() ?? '';
              return Card(
                clipBehavior: Clip.antiAlias,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      image.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.campaign_outlined, size: 34),
                            )
                          : Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  image,
                                  width: 84,
                                  height: 84,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    width: 84,
                                    height: 84,
                                    child: Icon(Icons.campaign_outlined),
                                  ),
                                ),
                              ),
                            ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d['title']?.toString() ?? 'KCN Advertisement',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(d['message']?.toString() ?? ''),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AdminRules extends StatefulWidget {
  const AdminRules({super.key});
  @override
  State<AdminRules> createState() => _AdminRulesState();
}

class _AdminRulesState extends State<AdminRules> {
  final Map<String, TextEditingController> fields = {};
  final labels = const <String, String>{
    'rewardPoolPercent': 'Reward pool %',
    'level1Percent': 'Level 1 %',
    'level2Percent': 'Level 2 %',
    'level3Percent': 'Level 3 %',
    'level4Percent': 'Level 4 %',
    'level5Percent': 'Level 5 %',
    'level6Percent': 'Level 6 %',
    'level7Percent': 'Level 7 %',
    'level8Percent': 'Level 8 %',
    'level9Percent': 'Level 9 %',
    'level10Percent': 'Level 10 %',
    'bonusPoolPercent': 'Bonus pool %',
    'otherExpenseTotal': 'Other expenses (ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹)',
    'adMobRevenueTotal': 'AdMob revenue reported (ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹)',
  };

  @override
  void initState() {
    super.initState();
    for (final key in labels.keys) fields[key] = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in fields.values) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final data = <String, dynamic>{};
    for (final key in labels.keys) data[key] = double.tryParse(fields[key]!.text) ?? 0;
    data['updatedAt'] = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance.collection(Collections.settings).doc('network').set(data, SetOptions(merge: true));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network rules saved.')));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(Collections.settings).doc('network').snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        for (final key in labels.keys) {
          if (fields[key]!.text.isEmpty && data.containsKey(key)) fields[key]!.text = '${data[key]}';
        }
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Network Rules', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const InfoBanner(text: 'Reward rules apply to eligible product sales. Back-Date permissions are managed separately.'),
          const SizedBox(height: 12),
          ...labels.entries.map((entry) => Card(child: Padding(padding: const EdgeInsets.all(12), child: TextField(controller: fields[entry.key], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: entry.value, suffixText: '%'))))),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Save Network Rules')),
        ]);
      },
    );
  }
}


class AdminUsers extends StatefulWidget {
  const AdminUsers({super.key});

  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  final controller = TextEditingController();
  String query = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _setStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) async {
    await doc.reference.update({
      'status': status,
      'isActive': status == 'approved' || status == 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection(Collections.farmers).get(),
      builder: (context, farmerSnap) {
        final farmers = <String, Map<String, dynamic>>{};
        for (final doc in farmerSnap.data?.docs ?? const []) {
          farmers[doc.id] = doc.data();
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection(Collections.users).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Unable to load users.\n${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final q = query.toLowerCase().trim();
            final docs = snap.data!.docs.where((doc) {
              final x = doc.data();
              final farmer = farmers[doc.id] ?? const <String, dynamic>{};
              final searchText = [
                x['name'],
                x['email'],
                x['mobile'],
                x['kcnId'],
                x['referralCode'],
                x['role'],
                farmer['kcnId'],
                farmer['referralCode'],
                farmer['aadhaarLast4'],
              ].map((v) => v?.toString() ?? '').join(' ').toLowerCase();
              return q.isEmpty || searchText.contains(q);
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: TextField(
                    controller: controller,
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      labelText: 'Search Name / Email / Mobile / KCN ID / Referral',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () {
                          controller.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final x = doc.data();
                      final farmer = farmers[doc.id] ?? const <String, dynamic>{};
                      final role = x['role']?.toString() ?? '-';
                      final kcnId = x['kcnId']?.toString().isNotEmpty == true
                          ? x['kcnId'].toString()
                          : farmer['kcnId']?.toString() ?? '-';
                      final referral = x['referralCode']?.toString().isNotEmpty == true
                          ? x['referralCode'].toString()
                          : farmer['referralCode']?.toString() ?? '-';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(role == 'farmer' ? Icons.agriculture : Icons.person),
                          ),
                          title: Text(x['name']?.toString() ?? '-'),
                          subtitle: Text(
                            '$role ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${x['email'] ?? '-'}\n'
                            'KCN: $kcnId ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Referral: $referral\n'
                            'Status: ${x['status'] ?? '-'}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) => _setStatus(doc, v),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'approved', child: Text('Activate')),
                              PopupMenuItem(value: 'suspended', child: Text('Suspend')),
                            ],
                            child: StatusChip(text: x['status']?.toString() ?? '-'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class AdminUpdateSettings extends StatefulWidget {
  const AdminUpdateSettings({super.key});

  @override
  State<AdminUpdateSettings> createState() => _AdminUpdateSettingsState();
}

class _AdminUpdateSettingsState extends State<AdminUpdateSettings> {
  final minVersion = TextEditingController();
  final androidUrl = TextEditingController();
  final webUrl = TextEditingController();
  final message = TextEditingController();
  bool forceUpdate = false;
  bool saving = false;
  bool loaded = false;

  @override
  void dispose() {
    minVersion.dispose();
    androidUrl.dispose();
    webUrl.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance.collection(Collections.settings).doc('app_update').set({
        'minVersion': minVersion.text.trim(),
        'androidUrl': androidUrl.text.trim(),
        'webUrl': webUrl.text.trim(),
        'message': message.text.trim(),
        'forceUpdate': forceUpdate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App update settings saved.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save update settings.\n$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance.collection(Collections.settings).doc('app_update').get();
      final d = doc.data() ?? {};
      if (!mounted) return;
      minVersion.text = d['minVersion']?.toString() ?? '1.0.0';
      androidUrl.text = d['androidUrl']?.toString() ?? 'https://play.google.com/store/apps/details?id=in.thekcn.kcn';
      webUrl.text = d['webUrl']?.toString() ?? 'https://thekcn.in';
      message.text = d['message']?.toString() ?? 'A new KCN update is available.';
      setState(() => forceUpdate = d['forceUpdate'] == true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      loaded = true;
      _load();
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('App Update Control', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const InfoBanner(text: 'Publish a new Play Store version with a higher versionCode/version, then set the minimum version here. Users with an older version will be offered the update link.'),
        const SizedBox(height: 12),
        TextField(controller: minVersion, decoration: const InputDecoration(labelText: 'Minimum app version', hintText: 'Example: 1.0.1')),
        const SizedBox(height: 10),
        TextField(controller: androidUrl, decoration: const InputDecoration(labelText: 'Android Play Store URL')),
        const SizedBox(height: 10),
        TextField(controller: webUrl, decoration: const InputDecoration(labelText: 'Web app URL')),
        const SizedBox(height: 10),
        TextField(controller: message, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Update message')),
        SwitchListTile(value: forceUpdate, onChanged: saving ? null : (v) => setState(() => forceUpdate = v), contentPadding: EdgeInsets.zero, title: const Text('Force update')),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: saving ? null : _save, icon: const Icon(Icons.save), label: Text(saving ? 'Saving...' : 'Save Update Settings')),
      ],
    );
  }
}

class AdminPaymentCorrections extends StatelessWidget {
  const AdminPaymentCorrections({super.key});

  Future<void> _addVerifiedPayment(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final balance = ((data['balanceAmount'] ?? 0) as num).toDouble();
    if (balance <= 0) return;

    final amount = TextEditingController();
    final reason = TextEditingController(text: 'Verified farmer payment not updated by Kendra');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verified Payment Correction'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current outstanding: ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(balance)}'),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Verified payment amount', prefixText: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹ '),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reason,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Reason / verification note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Record Correction')),
        ],
      ),
    );

    final value = double.tryParse(amount.text.trim()) ?? 0;
    final note = reason.text.trim();
    amount.dispose();
    reason.dispose();
    if (ok != true || value <= 0) return;
    if (value > balance) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correction cannot exceed outstanding balance.')));
      }
      return;
    }

    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final db = FirebaseFirestore.instance;
    final creditRef = db.collection(Collections.credits).doc(doc.id);
    final paymentRef = db.collection(Collections.payments).doc();

    try {
      await db.runTransaction((tx) async {
        final fresh = await tx.get(creditRef);
        if (!fresh.exists) throw Exception('Credit not found.');
        final c = fresh.data()!;
        final freshBalance = ((c['balanceAmount'] ?? 0) as num).toDouble();
        if (value > freshBalance) throw Exception('Current outstanding is lower than correction amount.');
        final paid = ((c['paidAmount'] ?? 0) as num).toDouble() + value;
        final newBalance = freshBalance - value;
        tx.set(paymentRef, {
          'paymentId': paymentRef.id,
          'creditId': doc.id,
          'farmerId': c['farmerId'],
          'krishiKendraId': c['krishiKendraId'],
          'amount': value,
          'mode': 'Admin Verified Correction',
          'paymentDate': FieldValue.serverTimestamp(),
          'entryDate': FieldValue.serverTimestamp(),
          'enteredBy': uid,
          'enteredByRole': 'admin',
          'reason': note,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(creditRef, {
          'paidAmount': paid,
          'balanceAmount': newBalance,
          'status': newBalance <= 0 ? 'PAID' : 'PARTIAL',
          'lastPaymentEnteredBy': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verified payment correction recorded.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(Collections.credits).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Unable to load credits.\n${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs.where((d) => (((d.data()['balanceAmount'] ?? 0) as num).toDouble()) > 0).toList();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final x = doc.data();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.rule_folder_outlined),
                title: Text('${x['farmerName'] ?? '-'} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ${x['billNo'] ?? '-'}'),
                subtitle: Text('KCN ${x['kcnId'] ?? '-'}\nOwner Kendra: ${x['krishiKendraId'] ?? '-'}\nOutstanding ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(((x['balanceAmount'] ?? 0) as num).toDouble())}'),
                isThreeLine: true,
                trailing: OutlinedButton(
                  onPressed: () => _addVerifiedPayment(context, doc),
                  child: const Text('Add Verified Payment'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AdminSales extends StatelessWidget {
  const AdminSales({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(Collections.orders).snapshots(),
      builder: (context, orderSnap) {
        if (orderSnap.hasError) return Center(child: Text('Unable to load sales.\n${orderSnap.error}'));
        if (!orderSnap.hasData) return const Center(child: CircularProgressIndicator());
        return FutureBuilder<List<dynamic>>(
          future: Future.wait<dynamic>([
            FirebaseFirestore.instance.collection(Collections.products).get(),
            FirebaseFirestore.instance.collection(Collections.settings).doc('network').get(),
          ]).then((values) => values),
          builder: (context, bundleSnap) {
            final productDocs = bundleSnap.data != null && bundleSnap.data!.isNotEmpty ? (bundleSnap.data![0] as QuerySnapshot<Map<String, dynamic>>).docs : const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final settings = bundleSnap.data != null && bundleSnap.data!.length > 1 ? ((bundleSnap.data![1] as DocumentSnapshot<Map<String, dynamic>>).data() ?? <String, dynamic>{}) : <String, dynamic>{};
            final products = <String, Map<String, dynamic>>{};
            for (final d in productDocs) products[d.id] = d.data();
            final rows = [...orderSnap.data!.docs]
              ..sort((a, b) => _ts(b.data()['createdAt']).compareTo(_ts(a.data()['createdAt'])));
            double sales = 0;
            double cost = 0;
            double reward = 0;
            final byDate = <String, Map<String, double>>{};
            final byProduct = <String, Map<String, double>>{};
            for (final doc in rows) {
              final d = doc.data();
              final status = (d['status']?.toString() ?? 'pending').toLowerCase();
              if (status == 'cancelled') continue;
              final total = ((d['totalAmount'] ?? 0) as num).toDouble();
              double orderCost = 0;
              final productName = d['productName']?.toString() ?? 'Group / Product';
              if (d['orderType'] == 'group' && d['items'] is List) {
                for (final raw in d['items']) {
                  if (raw is Map) {
                    final pid = raw['productId']?.toString() ?? '';
                    final qty = (raw['quantity'] as num?)?.toInt() ?? 0;
                    orderCost += ((products[pid]?['costPrice'] ?? 0) as num).toDouble() * qty;
                  }
                }
              } else {
                orderCost = ((products[d['productId']?.toString()]?['costPrice'] ?? 0) as num).toDouble() * ((d['quantity'] ?? 0) as num).toInt();
              }
              final rewardValue = ((d['rewardPool'] ?? 0) as num).toDouble();
              sales += total;
              cost += orderCost;
              reward += rewardValue;
              final day = formatTs(d['createdAt']);
              final dayRow = byDate.putIfAbsent(day, () => {'sales': 0, 'cost': 0, 'reward': 0});
              dayRow['sales'] = dayRow['sales']! + total;
              dayRow['cost'] = dayRow['cost']! + orderCost;
              dayRow['reward'] = dayRow['reward']! + rewardValue;
              final productRow = byProduct.putIfAbsent(productName, () => {'sales': 0, 'cost': 0, 'reward': 0});
              productRow['sales'] = productRow['sales']! + total;
              productRow['cost'] = productRow['cost']! + orderCost;
              productRow['reward'] = productRow['reward']! + rewardValue;
            }
            final otherExpense = ((settings['otherExpenseTotal'] ?? 0) as num).toDouble();
            final adRevenue = ((settings['adMobRevenueTotal'] ?? 0) as num).toDouble();
            final net = sales - cost - reward - otherExpense + adRevenue;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Sales & Company Profit', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(width: 220, child: StatCard(label: 'Total Sales', value: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(sales)}', icon: Icons.sell_outlined)),
                    SizedBox(width: 220, child: StatCard(label: 'Product Cost', value: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(cost)}', icon: Icons.inventory_2_outlined)),
                    SizedBox(width: 220, child: StatCard(label: 'Network Rewards', value: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(reward)}', icon: Icons.stars_outlined)),
                    SizedBox(width: 220, child: StatCard(label: 'Other Expenses', value: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(otherExpense)}', icon: Icons.money_off_outlined)),
                    SizedBox(width: 220, child: StatCard(label: 'AdMob Revenue', value: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(adRevenue)}', icon: Icons.ads_click_outlined)),
                    SizedBox(width: 220, child: StatCard(label: 'Final Net Profit', value: 'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(net)}', icon: Icons.account_balance_outlined)),
                  ],
                ),
                const SizedBox(height: 14),
                const InfoBanner(text: 'Company cost, reward distribution, other expenses and reported AdMob revenue are Admin-only. AdMob revenue must be entered from trusted AdMob reporting; it is not inferred from impressions in the app.'),
                const SizedBox(height: 16),
                const Text('Date-wise Sales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (byDate.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('No sales yet.'))),
                ...byDate.entries.map((e) {
                  final x = e.value;
                  return Card(
                    child: ListTile(
                      title: Text(e.key),
                      subtitle: Text('Sales ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(x['sales']!)} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Cost ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(x['cost']!)} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Rewards ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(x['reward']!)}'),
                      trailing: Text('Margin\nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(x['sales']! - x['cost']! - x['reward']!)}', textAlign: TextAlign.right),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                const Text('Product-wise Sales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...byProduct.entries.map((e) {
                  final x = e.value;
                  return Card(
                    child: ListTile(
                      title: Text(e.key),
                      subtitle: Text('Sales ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(x['sales']!)} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Cost ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(x['cost']!)} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Rewards ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(x['reward']!)}'),
                      trailing: Text('Margin\nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(x['sales']! - x['cost']! - x['reward']!)}', textAlign: TextAlign.right),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}

class AdminNetwork extends StatelessWidget {
  const AdminNetwork({super.key});

  Future<void> _makeFirstRootMember(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    try {
      final db = FirebaseFirestore.instance;

      final allMembers = await db
          .collection(Collections.networkMembers)
          .get();

      final activeMembers = allMembers.docs.where(
        (d) => (d.data()['status']?.toString() ?? '') == 'active',
      ).toList();

      if (activeMembers.length > 1 ||
          (activeMembers.isNotEmpty &&
              activeMembers.first.id != doc.id)) {
        throw Exception(
          'Network already has an active root/member structure.',
        );
      }

      final data = doc.data();

      await doc.reference.set(
        {
          'farmerId': data['farmerId']?.toString() ?? doc.id,
          'memberName': data['memberName']?.toString() ?? '',
          'kcnId': data['kcnId']?.toString() ?? '',
          'referralCode': data['referralCode']?.toString() ?? '',

          // Root member has no farmer sponsor.
          'sponsorId': '',
          'sponsorName': 'KCN Network',
          'sponsorKcnId': 'KCN-ROOT',

          'level': 1,
          'status': 'active',
          'isRootMember': true,
          'joinedByAdmin': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final farmerId =
          data['farmerId']?.toString() ?? doc.id;

      await db
          .collection(Collections.farmers)
          .doc(farmerId)
          .set(
        {
          'networkJoinRequest': {
            'status': 'approved',
            'adminAdded': true,
            'isRootMember': true,
            'approvedBy':
                AuthService.instance.currentUser?.uid,
            'approvedAt':
                FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'First Network Member is now the Root Member.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    }
  }

  Future<void> _addRootTree(BuildContext context) async {
    final kcnController = TextEditingController();

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Add Root Tree'),
            content: TextField(
              controller: kcnController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Farmer KCN ID',
                hintText: 'KCN-XXXXXXXXXXXX',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  kcnController.text.trim(),
                ),
                child: const Text('Create Root'),
              ),
            ],
          );
        },
      );

      if (result == null || result.trim().isEmpty) {
        return;
      }

      final kcnId = result.trim().toUpperCase();
      final db = FirebaseFirestore.instance;

      // Find the Farmer using the limited public identity collection.
      final farmerQuery = await db
          .collection(Collections.creditPublic)
          .where('kcnId', isEqualTo: kcnId)
          .limit(1)
          .get();

      if (farmerQuery.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Farmer KCN ID not found.'),
            ),
          );
        }
        return;
      }

      final farmer = farmerQuery.docs.first.data();
      final farmerId = farmer['farmerId']?.toString() ?? '';

      if (farmerId.isEmpty) {
        throw Exception('Farmer ID is missing.');
      }

      // A Farmer/KCN ID can belong to only one Network tree.
      final existing = await db
          .collection(Collections.networkMembers)
          .doc(farmerId)
          .get();

      if (existing.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This Farmer is already a Network member.',
              ),
            ),
          );
        }
        return;
      }

      final treeId =
          'TREE-';

      await db
          .collection(Collections.networkMembers)
          .doc(farmerId)
          .set(
        {
          'farmerId': farmerId,
          'memberName':
              farmer['farmerName']?.toString() ?? '',
          'kcnId':
              farmer['kcnId']?.toString() ?? kcnId,
          'referralCode': '',

          // Independent Root Tree
          'treeId': treeId,
          'isRootMember': true,
          'joinedByAdmin': true,

          // Root has no Farmer sponsor.
          'sponsorId': '',
          'sponsorName': 'KCN Network',
          'sponsorKcnId': 'KCN-ROOT',

          'level': 1,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await db
          .collection(Collections.farmers)
          .doc(farmerId)
          .set(
        {
          'networkJoinRequest': {
            'status': 'approved',
            'approvedBy':
                AuthService.instance.currentUser?.uid,
            'approvedAt':
                FieldValue.serverTimestamp(),
            'adminAdded': true,
            'isRootMember': true,
            'treeId': treeId,
          },
        },
        SetOptions(merge: true),
      );

      await NotificationService.instance.create(
        recipientId: farmerId,
        title: 'KCN Network Tree Created',
        message:
            'Admin has added you as the Root Member of a new KCN Network Tree.',
        type: 'network_root_member',
        payload: {
          'kcnId': kcnId,
          'treeId': treeId,
          'level': 1,
          'isRootMember': true,
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'New Root Tree created successfully: ',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    } finally {
      kcnController.dispose();
    }
  }
  Future<void> _addFirstMember(BuildContext context) async {
    final kcnController = TextEditingController();

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Add First Network Member'),
            content: TextField(
              controller: kcnController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Farmer KCN ID',
                hintText: 'KCN-XXXXXXXXXXXX',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              onSubmitted: (value) {
                Navigator.pop(dialogContext, value.trim());
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  kcnController.text.trim(),
                ),
                child: const Text('Add Member'),
              ),
            ],
          );
        },
      );

      if (result == null || result.trim().isEmpty) {
        return;
      }

      final kcnId = result.trim().toUpperCase();
      final db = FirebaseFirestore.instance;

      final existing = await db
          .collection(Collections.networkMembers)
          .limit(1)
          .get();

      final activeExisting = existing.docs.any(
        (d) => (d.data()['status']?.toString() ?? '') == 'active',
      );

      if (activeExisting) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Network already has an active first member.',
              ),
            ),
          );
        }
        return;
      }

      final farmerQuery = await db
          .collection(Collections.creditPublic)
          .where('kcnId', isEqualTo: kcnId)
          .limit(1)
          .get();

      if (farmerQuery.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Farmer KCN ID not found.'),
            ),
          );
        }
        return;
      }

      final farmer = farmerQuery.docs.first.data();
      final farmerId = farmer['farmerId']?.toString() ?? '';

      if (farmerId.isEmpty) {
        throw Exception('Farmer ID is missing.');
      }

      final memberRef = db
          .collection(Collections.networkMembers)
          .doc(farmerId);

      final memberSnap = await memberRef.get();

      if (memberSnap.exists &&
          (memberSnap.data()?['status']?.toString() ?? '') == 'active') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This Farmer is already in the Network.'),
            ),
          );
        }
        return;
      }

      await memberRef.set(
        {
          'farmerId': farmerId,
          'memberName':
              farmer['farmerName']?.toString() ?? '',
          'kcnId':
              farmer['kcnId']?.toString() ?? kcnId,
          'referralCode': '',
          'sponsorId': '',
          'sponsorName': 'KCN Network',
          'sponsorKcnId': 'KCN-ROOT',
          'level': 1,
          'status': 'active',
          'isRootMember': true,
          'joinedByAdmin': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await db
          .collection(Collections.farmers)
          .doc(farmerId)
          .set(
        {
          'networkJoinRequest': {
            'status': 'approved',
            'approvedBy':
                AuthService.instance.currentUser?.uid,
            'approvedAt':
                FieldValue.serverTimestamp(),
            'adminAdded': true,
            'isRootMember': true,
          },
        },
        SetOptions(merge: true),
      );

      await NotificationService.instance.create(
        recipientId: farmerId,
        title: 'KCN Network Started',
        message:
            'You have been added as the first active member '
            'of the KCN Network by Admin.',
        type: 'network_root_member',
        payload: {
          'kcnId': kcnId,
          'level': 1,
          'isRootMember': true,
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'First Network Member added successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    } finally {
      kcnController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(Collections.networkMembers).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Unable to load network.\n${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final members = snap.data!.docs
            .where((d) => d.data()['status']?.toString() != 'exited')
            .toList();
        final children = <String, List<QueryDocumentSnapshot<Map<String,dynamic>>>>{};
        for (final d in members) {
          final sponsor = d.data()['sponsorId']?.toString() ?? '';
          children.putIfAbsent(sponsor, () => []).add(d);
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection(Collections.rewards).snapshots(),
          builder: (context, rewardSnap) {
            double pending=0, paid=0;
            final earnedBy = <String,double>{};
            for (final d in rewardSnap.data?.docs ?? const []) {
              final x=d.data(); final a=((x['amount']??0) as num).toDouble(); final id=x['farmerId']?.toString()??''; earnedBy[id]=(earnedBy[id]??0)+a;
              if ((x['status']?.toString()??'pending')=='paid') paid += a; else pending += a;
            }
            return ListView(padding:const EdgeInsets.all(16),children:[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Network Tree & Earnings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _addRootTree(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Root Tree'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children:[Expanded(child:StatCard(label:'Members',value:'${members.length}',icon:Icons.people_alt_outlined)),const SizedBox(width:8),Expanded(child:StatCard(label:'Pending Rewards',value:'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(pending)}',icon:Icons.hourglass_top)),const SizedBox(width:8),Expanded(child:StatCard(label:'Paid Rewards',value:'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(paid)}',icon:Icons.paid_outlined))]), const SizedBox(height:14),
              const InfoBanner(text:'Tree rewards are created from eligible product sales. This view is Admin-only.'), const SizedBox(height:12),
              ..._roots(children,members).map((root)=>_treeTile(context,root,children,earnedBy,0)),
              if (members.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(14),child:Text('No network members yet.'))),
            ]);
          },
        );
      },
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _roots(
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> children,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> members,
  ) {
    final roots = children[''] ?? const [];

    if (roots.isNotEmpty) {
      return roots;
    }

    // If there is exactly one active member and no root exists yet,
    // expose that member as the first Root Member candidate.
    final activeMembers = members.where(
      (d) => (d.data()['status']?.toString() ?? '') == 'active',
    ).toList();

    if (activeMembers.length == 1) {
      return activeMembers;
    }

    return const [];
  }

  Widget _treeTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> children,
    Map<String, double> earnedBy,
    int level,
  ) {
    final d = doc.data();
    final id = doc.id;
    final kids = children[id] ?? const [];

    final isRoot = d['isRootMember'] == true;
    final sponsorId = d['sponsorId']?.toString().trim() ?? '';
    final canMakeRoot = !isRoot && (level == 0 || sponsorId.isEmpty);

    return Padding(
      padding: EdgeInsets.only(
        left: level * 22.0,
        bottom: 8,
      ),
      child: Card(
        child: ExpansionTile(
          title: Text(
            '${d['memberName'] ?? '-'} â€¢ ${d['kcnId'] ?? '-'}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            'Level ${d['level'] ?? 1} â€¢ '
            'Earned â‚¹${money(earnedBy[id] ?? 0)} â€¢ '
            'Direct ${kids.length}',
          ),
          children: [
            if (canMakeRoot)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  12,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _makeFirstRootMember(
                      context,
                      doc,
                    ),
                    icon: const Icon(
                      Icons.account_tree_outlined,
                    ),
                    label: const Text(
                      'Make Root Member',
                    ),
                  ),
                ),
              ),

            if (kids.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  14,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No direct members.',
                  ),
                ),
              )
            else
              ...kids.map(
                (x) => _treeTile(
                  context,
                  x,
                  children,
                  earnedBy,
                  level + 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
class AdminPayouts extends StatelessWidget {
  const AdminPayouts({super.key});

  Future<void> _pay(BuildContext context, String farmerId, double amount) async {
    if (amount <= 0) return;
    final db = FirebaseFirestore.instance;
    final rewardSnap = await db.collection(Collections.rewards).where('farmerId', isEqualTo: farmerId).get();
    final batch = db.batch();
    var remaining = amount;
    for (final doc in rewardSnap.docs) {
      final d=doc.data();
      if ((d['status']?.toString()??'pending')!='paid' && remaining>0) {
        final a=((d['amount']??0) as num).toDouble();
        final use=a<=remaining?a:remaining;
        if (use>=a) batch.update(doc.reference, {'status':'paid','paidAt':FieldValue.serverTimestamp()});
        remaining -= use;
      }
    }
    final paymentRef=db.collection(Collections.networkPayments).doc();
    batch.set(paymentRef, {'farmerId':farmerId,'amount':amount,'type':'reward_payout','status':'paid','createdAt':FieldValue.serverTimestamp()});
    await batch.commit();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Payout recorded.')));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:FirebaseFirestore.instance.collection(Collections.rewards).snapshots(),
      builder:(context,snap){
        if(snap.hasError)return Center(child:Text('Unable to load payouts.\n${snap.error}'));
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        final grouped=<String,double>{};
        for(final d in snap.data!.docs){ final x=d.data(); if((x['status']?.toString()??'pending')!='paid'){final id=x['farmerId']?.toString()??''; grouped[id]=(grouped[id]??0)+((x['amount']??0) as num).toDouble();}}
        if(grouped.isEmpty)return const Center(child:Text('No pending payouts.'));
        return ListView.separated(padding:const EdgeInsets.all(16),itemCount:grouped.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,index){final id=grouped.keys.elementAt(index);final amount=grouped[id]!;return Card(child:ListTile(leading:const Icon(Icons.payments_outlined),title:Text('Farmer: $id'),subtitle:Text('Pending payout ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(amount)}'),trailing:FilledButton(onPressed:()=>_pay(context,id,amount),child:const Text('Pay'))));});
      },
    );
  }
}

class AdminProductGroups extends StatefulWidget {
  const AdminProductGroups({super.key});

  @override
  State<AdminProductGroups> createState() => _AdminProductGroupsState();
}

class _AdminProductGroupsState extends State<AdminProductGroups> {
  Future<void> _edit([QueryDocumentSnapshot<Map<String, dynamic>>? doc]) async {
    final db = FirebaseFirestore.instance;
    final old = doc?.data() ?? <String, dynamic>{};
    final name = TextEditingController(text: old['name']?.toString() ?? '');
    final desc = TextEditingController(text: old['description']?.toString() ?? '');
    final price = TextEditingController(text: '${old['groupPrice'] ?? 0}');
    final snap = await db.collection(Collections.products).where('active', isEqualTo: true).get();
    final selected = <String, int>{};

    final oldItems = old['items'];
    if (oldItems is List) {
      for (final raw in oldItems) {
        if (raw is Map) {
          final id = raw['productId']?.toString() ?? '';
          if (id.isNotEmpty) {
            selected[id] = (raw['quantity'] as num?)?.toInt() ?? 1;
          }
        }
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(doc == null ? 'Create Product Group' : 'Edit Product Group'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(controller: name, decoration: const InputDecoration(labelText: 'Group name')),
                      TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Group description')),
                      TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Group price')),
                      const SizedBox(height: 10),
                      ...snap.docs.map((productDoc) {
                        final product = productDoc.data();
                        final id = productDoc.id;
                        final checked = selected.containsKey(id);
                        return Row(
                          children: [
                            Expanded(child: Text(product['name']?.toString() ?? '-')),
                            IconButton(
                              tooltip: 'Decrease quantity',
                              onPressed: checked
                                  ? () {
                                      final current = selected[id] ?? 1;
                                      if (current <= 1) {
                                        setLocal(() => selected.remove(id));
                                      } else {
                                        setLocal(() => selected[id] = current - 1);
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('${selected[id] ?? 0}'),
                            IconButton(
                              tooltip: 'Increase quantity',
                              onPressed: () => setLocal(() => selected[id] = (selected[id] ?? 0) + 1),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                            Checkbox(
                              value: checked,
                              onChanged: (value) => setLocal(() {
                                if (value == true) {
                                  selected[id] = 1;
                                } else {
                                  selected.remove(id);
                                }
                              }),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (ok != true) {
      name.dispose();
      desc.dispose();
      price.dispose();
      return;
    }

    final items = <Map<String, dynamic>>[];
    double normal = 0;
    for (final entry in selected.entries) {
      if (entry.value <= 0) continue;
      final productDoc = snap.docs.firstWhere((x) => x.id == entry.key);
      final product = productDoc.data();
      items.add({'productId': productDoc.id, 'quantity': entry.value});
      normal += ((product['farmerPrice'] ?? 0) as num).toDouble() * entry.value;
    }

    final data = <String, dynamic>{
      'name': name.text.trim(),
      'description': desc.text.trim(),
      'groupPrice': double.tryParse(price.text) ?? 0,
      'normalTotal': normal,
      'items': items,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (doc == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await db.collection(Collections.productGroups).add(data);
    } else {
      await doc.reference.update(data);
    }

    name.dispose();
    desc.dispose();
    price.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Text('Product Groups', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Create Group')),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection(Collections.productGroups).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Unable to load groups.\n${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('No product groups created.'));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final d = docs[index].data();
                  final groupPrice = ((d['groupPrice'] ?? 0) as num).toDouble();
                  final normal = ((d['normalTotal'] ?? 0) as num).toDouble();
                  return Card(
                    child: ListTile(
                      title: Text(d['name']?.toString() ?? '-'),
                      subtitle: Text('Group ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(groupPrice)} ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Normal ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢Ã¢â€šÂ¹Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹${money(normal)}\n${d['description'] ?? ''}'),
                      isThreeLine: true,
                      trailing: Wrap(
                        children: [
                          IconButton(onPressed: () => _edit(docs[index]), icon: const Icon(Icons.edit_outlined)),
                          Switch(
                            value: d['active'] == true,
                            onChanged: (v) => docs[index].reference.update({'active': v, 'updatedAt': FieldValue.serverTimestamp()}),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({required this.label, required this.value, required this.icon, super.key});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) { return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [Icon(icon, size: 28), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]))); }
}

class FeatureTile extends StatelessWidget {
  const FeatureTile({
    required this.icon,
    required this.title,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({required this.text, super.key});
  final String text;
  @override
  Widget build(BuildContext context) { return Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline), const SizedBox(width:10), Expanded(child: Text(text))]))); }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.text, super.key});
  final String text;
  @override
  Widget build(BuildContext context) { final t=text.toLowerCase(); final color=t.contains('complete')||t=='paid'||t=='approved'?Colors.green:t.contains('cancel')||t=='rejected'?Colors.red:Colors.orange; return Chip(label:Text(text), side:BorderSide.none, backgroundColor:color.withOpacity(.12)); }
}

class CreditScoreCard extends StatelessWidget {
  const CreditScoreCard({required this.score, super.key});
  final int score;
  @override
  Widget build(BuildContext context) { return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('KCN Rating'), const SizedBox(height:8), Text('$score / 900',style:const TextStyle(fontSize:32,fontWeight:FontWeight.bold)), const SizedBox(height:10), LinearProgressIndicator(value:(score/900).clamp(0,1))]))); }
}

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, this.path, this.url, required this.size, this.fit = BoxFit.cover});
  final String? path;
  final String? url;
  final double size;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) { Widget child; if (url != null && url!.isNotEmpty) { child=Image.network(url!,width:size,height:size,fit:fit,errorBuilder:(_,__,___)=>_fallback()); } else if (path != null && path!.isNotEmpty) { child=Image.asset(path!,width:size,height:size,fit:fit,errorBuilder:(_,__,___)=>_fallback()); } else { child=_fallback(); } return ClipRRect(borderRadius:BorderRadius.circular(14),child:child); }
  Widget _fallback()=>Container(width:size,height:size,color:Colors.grey.shade200,child:const Icon(Icons.inventory_2_outlined,size:42));
}

String money(num n) => n.toStringAsFixed(2);
DateTime _ts(dynamic value) { if (value is Timestamp) return value.toDate(); return DateTime.fromMillisecondsSinceEpoch(0); }
String formatTs(dynamic value) { final d=_ts(value); if (d.year==1970) return '-'; return '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}'; }





