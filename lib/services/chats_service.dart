import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';

class ChatsService {
  final CollectionReference chats = FirebaseFirestore.instance.collection('chats');

  String buildChatId({
    required String toolId,
    required String userA,
    required String userB,
  }) {
    final pair = [userA, userB]..sort();
    return '${toolId}__${pair[0]}__${pair[1]}';
  }

  Stream<List<ChatMessage>> streamMessages(String chatId) {
    return chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => ChatMessage.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> sendMessage({
    required String chatId,
    required String toolId,
    required String toolTitle,
    required String senderId,
    required String senderName,
    required String receiverId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final chatRef = chats.doc(chatId);
    await chatRef.set({
      'toolId': toolId,
      'toolTitle': toolTitle,
      'participants': [senderId, receiverId],
      'lastMessage': trimmed,
      'lastSenderId': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await chatRef.collection('messages').add({
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}