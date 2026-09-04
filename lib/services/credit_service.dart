import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/collections.dart';

class CreditService {
  CreditService(this.db);
  final FirebaseFirestore db;

  Future<void> _validateEntryDate({
    required DateTime entryDate,
    required bool allowBackdate,
    required int maxBackdateYears,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(entryDate.year, entryDate.month, entryDate.day);
    if (selected.isAfter(today)) throw Exception('Future-dated entries are not allowed.');
    if (selected.isBefore(today)) {
      if (!allowBackdate) throw Exception('Back-dated entry is disabled by Admin.');
      final earliest = DateTime(today.year - maxBackdateYears, today.month, today.day);
      if (selected.isBefore(earliest)) throw Exception('Back-date limit is $maxBackdateYears years.');
    }
  }

  Future<bool> _isBackdateApproved(String kendraId) async {
    final snap = await db.collection(Collections.users).doc(kendraId).get();
    return snap.data()?['backdateApproved'] == true;
  }

  Future<void> _validatePolicy({required String kendraId, required DateTime entryDate, required int maxBackdateYears}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!DateTime(entryDate.year, entryDate.month, entryDate.day).isBefore(today)) return;
    final settings = await db.collection(Collections.settings).doc('network').get();
    final s = settings.data() ?? {};
    final globallyAllowed = s['allowBackdatedEntries'] == true;
    if (!globallyAllowed) throw Exception('Back-dated entry is disabled by Admin.');
    final approved = await _isBackdateApproved(kendraId);
    if (!approved) throw Exception('Admin back-date approval is required for this Krishi Kendra.');
    final years = ((s['maxBackdateYears'] ?? maxBackdateYears) as num).toInt().clamp(1, 20);
    await _validateEntryDate(entryDate: entryDate, allowBackdate: true, maxBackdateYears: years);
  }

  Future<void> createCredit({
    required String kendraId,
    required String farmerId,
    required String farmerName,
    required String kcnId,
    required String billNo,
    required double amount,
    DateTime? dueDate,
    DateTime? entryDate,
    bool allowBackdate = false,
    int maxBackdateYears = 7,
  }) async {
    if (amount <= 0) throw Exception('Amount must be greater than zero.');
    if (billNo.trim().isEmpty) throw Exception('Bill number is required.');
    final selected = entryDate ?? DateTime.now();
    await _validatePolicy(kendraId: kendraId, entryDate: selected, maxBackdateYears: maxBackdateYears);
    final ref = db.collection(Collections.credits).doc();
    await db.runTransaction((tx) async {
      tx.set(ref, {
        'creditId': ref.id, 'farmerId': farmerId, 'farmerName': farmerName, 'kcnId': kcnId,
        'krishiKendraId': kendraId, 'billNo': billNo.trim(), 'amount': amount, 'paidAmount': 0.0,
        'balanceAmount': amount, 'status': 'UNPAID', 'dueDate': Timestamp.fromDate(dueDate ?? DateTime.now()),
        'entryDate': Timestamp.fromDate(selected),
        'isBackdated': DateTime(selected.year, selected.month, selected.day).isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)),
        'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> recordPayment({
    required String creditId, required String farmerId, required String kendraId, required double amount, required String mode,
    DateTime? entryDate, bool allowBackdate = false, int maxBackdateYears = 7,
  }) async {
    if (amount <= 0) throw Exception('Payment must be greater than zero.');
    final selected = entryDate ?? DateTime.now();
    await _validatePolicy(kendraId: kendraId, entryDate: selected, maxBackdateYears: maxBackdateYears);
    final creditRef = db.collection(Collections.credits).doc(creditId);
    final paymentRef = db.collection(Collections.payments).doc();
    await db.runTransaction((tx) async {
      final creditSnap = await tx.get(creditRef);
      if (!creditSnap.exists) throw Exception('Credit not found.');
      final c = creditSnap.data()!;
      if ((c['krishiKendraId'] ?? '') != kendraId) throw Exception('Only the owning Krishi Kendra can record this payment.');
      if ((c['farmerId'] ?? '') != farmerId) throw Exception('Farmer mismatch.');
      final balance = ((c['balanceAmount'] ?? 0) as num).toDouble();
      if (amount > balance) throw Exception('Payment exceeds outstanding balance.');
      final paid = ((c['paidAmount'] ?? 0) as num).toDouble() + amount;
      final newBalance = balance - amount;
      tx.set(paymentRef, {
        'paymentId': paymentRef.id, 'creditId': creditId, 'farmerId': farmerId, 'krishiKendraId': kendraId,
        'amount': amount, 'mode': mode, 'paymentDate': Timestamp.fromDate(selected), 'entryDate': Timestamp.fromDate(selected),
        'isBackdated': DateTime(selected.year, selected.month, selected.day).isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)),
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(creditRef, {'paidAmount': paid, 'balanceAmount': newBalance, 'status': newBalance <= 0 ? 'PAID' : 'PARTIAL', 'updatedAt': FieldValue.serverTimestamp()});
    });
  }
}
