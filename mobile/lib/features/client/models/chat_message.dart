// Um anexo de uma mensagem do chat (foto ou audio) - ver
// `Attachment#push_event_data` no servidor, que e' quem decide o
// `file_type` e monta a `data_url` (CDN/S3 ou rota local, tanto faz pro
// app: e' so uma URL pra tocar/mostrar).
class ChatAttachment {
  const ChatAttachment({required this.fileType, required this.dataUrl});

  final String fileType;
  final String dataUrl;

  bool get isImage => fileType == 'image';
  bool get isAudio => fileType == 'audio';

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
        fileType: (json['file_type'] as String?) ?? 'file',
        dataUrl: (json['data_url'] as String?) ?? '',
      );
}

// Uma mensagem do chat do Portal com a equipe (ver api/v1/client/chats).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.content,
    required this.fromMe,
    this.authorName,
    required this.createdAt,
    this.attachments = const [],
  });

  final int id;
  final String content;
  final bool fromMe;
  final String? authorName;
  final DateTime createdAt;
  final List<ChatAttachment> attachments;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int,
        content: (json['content'] as String?) ?? '',
        fromMe: (json['from_you'] as bool?) ?? false,
        authorName: json['author_name'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(((json['created_at'] as int?) ?? 0) * 1000),
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .map((entry) => ChatAttachment.fromJson(entry as Map<String, dynamic>))
            .toList(),
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
