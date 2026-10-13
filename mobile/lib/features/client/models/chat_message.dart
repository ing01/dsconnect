// Uma mensagem do chat do Portal com a equipe (ver api/v1/client/chats).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.content,
    required this.fromMe,
    this.authorName,
    required this.createdAt,
  });

  final int id;
  final String content;
  final bool fromMe;
  final String? authorName;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int,
        content: (json['content'] as String?) ?? '',
        fromMe: (json['from_you'] as bool?) ?? false,
        authorName: json['author_name'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(((json['created_at'] as int?) ?? 0) * 1000),
      );
}

class ChatSession {
  const ChatSession({required this.pubsubToken, required this.conversationId, required this.messages});

  final String pubsubToken;
  final int conversationId;
  final List<ChatMessage> messages;

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        pubsubToken: (json['pubsub_token'] as String?) ?? '',
        conversationId: json['conversation_id'] as int,
        messages: (json['messages'] as List<dynamic>? ?? const [])
            .map((entry) => ChatMessage.fromJson(entry as Map<String, dynamic>))
            .toList(),
      );
}
