import 'chat_message.dart';

class ChatHistorySession {
  const ChatHistorySession({
    required this.id,
    required this.createdAt,
    required this.resolvedAt,
    required this.preview,
  });

  final int id;
  final DateTime createdAt;
  final DateTime resolvedAt;
  final String preview;

  factory ChatHistorySession.fromJson(Map<String, dynamic> json) =>
      ChatHistorySession(
        id: json['id'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            ((json['created_at'] as int?) ?? 0) * 1000),
        resolvedAt: DateTime.fromMillisecondsSinceEpoch(
            ((json['resolved_at'] as int?) ?? 0) * 1000),
        preview: (json['preview'] as String?) ?? '',
      );
}

class ChatHistoryDetail {
  const ChatHistoryDetail({
    required this.id,
    required this.createdAt,
    required this.resolvedAt,
    required this.messages,
  });

  final int id;
  final DateTime createdAt;
  final DateTime resolvedAt;
  final List<ChatMessage> messages;

  factory ChatHistoryDetail.fromJson(Map<String, dynamic> json) =>
      ChatHistoryDetail(
        id: json['id'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            ((json['created_at'] as int?) ?? 0) * 1000),
        resolvedAt: DateTime.fromMillisecondsSinceEpoch(
            ((json['resolved_at'] as int?) ?? 0) * 1000),
        messages: (json['messages'] as List<dynamic>? ?? const [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
