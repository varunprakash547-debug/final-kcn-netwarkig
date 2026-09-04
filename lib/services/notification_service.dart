import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/collections.dart';
import 'auth_service.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> create({
    required String recipientId,
    required String title,
    required String message,
    String type = 'general',
    Map<String, dynamic>? payload,
  }) async {
    final senderId = AuthService.instance.currentUser?.uid;
    if (senderId == null || recipientId.trim().isEmpty) return;

    await _db.collection(Collections.notifications).add({
      'recipientId': recipientId,
      'senderId': senderId,
      'title': title,
      'message': message,
      'type': type,
      'payload': payload ?? <String, dynamic>{},
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markRead(String notificationId) async {
    await _db.collection(Collections.notifications).doc(notificationId).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }
}
