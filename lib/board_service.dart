import 'package:cloud_firestore/cloud_firestore.dart';

class BoardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// CREATE — uid-owned, server-timestamped
  Future<void> postMessage({
    required String authorUid,
    required String authorName,
    required String text,
  }) async {
    await _db.collection('messages').add({
      'authorUid': authorUid,
      'authorName': authorName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// READ (live) — the board renders from this stream
  Stream<QuerySnapshot<Map<String, dynamic>>> messageBoard() {
    return _db.collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  /// UPDATE — own message only (rules enforce it)
  Future<void> editMessage({
    required String messageId,
    required String newText,
  }) async {
    await _db.collection('messages').doc(messageId).update({
      'text': newText,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// DELETE — own message only (rules enforce it)
  Future<void> deleteMessage({required String messageId}) async {
    await _db.collection('messages').doc(messageId).delete();
  }
}