import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/tool_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/chats_service.dart';

class ChatScreen extends StatefulWidget {
  final Tool tool;
  final AppUser owner;

  const ChatScreen({
    super.key,
    required this.tool,
    required this.owner,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatsService _chatsService = ChatsService();
  final TextEditingController _messageCtrl = TextEditingController();

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final profile = auth.profile;
    if (user == null || profile == null) return;

    // Clear optimistically before the async call
    _messageCtrl.clear();

    final chatId = _chatsService.buildChatId(
      toolId: widget.tool.id,
      userA: user.uid,
      userB: widget.owner.id,
    );

    try {
      await _chatsService.sendMessage(
        chatId: chatId,
        toolId: widget.tool.id,
        toolTitle: widget.tool.title,
        senderId: user.uid,
        senderName: profile.username ?? profile.email,
        receiverId: widget.owner.id,
        text: text,
      );
    } catch (e) {
      if (!mounted) return;
      // Restore text so user doesn't lose their message
      _messageCtrl.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final profile = auth.profile;
    if (user == null || profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final chatId = _chatsService.buildChatId(
      toolId: widget.tool.id,
      userA: user.uid,
      userB: widget.owner.id,
    );
    final isSelfChat = user.uid == widget.owner.id;
    final displayName = isSelfChat
        ? 'Yourself'
        : (widget.owner.username ?? widget.owner.email);
    final roleLabel = widget.owner.role.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$displayName ($roleLabel)'),
            Text(
              widget.tool.title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatsService.streamMessages(chatId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snap.data ?? [];
                if (messages.isEmpty) {
                  return const Center(child: Text('Start the conversation'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderId == user.uid;
                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMine)
                              Text(
                                message.senderName,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            Text(
                              message.text,
                              style: TextStyle(
                                color: isMine ? Colors.white : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(message.createdAt),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isMine ? Colors.white70 : null,
                                  ),
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return 'Sending...';
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}