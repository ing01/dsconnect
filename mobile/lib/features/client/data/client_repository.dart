import 'package:dio/dio.dart';

import '../models/chat_message.dart';
import '../models/client_notification.dart';
import '../models/client_ticket.dart';
import '../models/client_ticket_detail.dart';
import '../models/ticket_category.dart';

// Rotas fora de /accounts/:id - a conta do cliente vem do proprio token, nunca
// da URL (ver Api::V1::Client::BaseController no servidor).
class ClientRepository {
  ClientRepository(this._dio);

  final Dio _dio;

  Future<List<ClientTicket>> fetchTickets() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/client/tickets');
    return (response.data?['payload'] as List<dynamic>? ?? const [])
        .map((entry) => ClientTicket.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<ClientTicketDetail> fetchTicketDetail(int ticketId) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/client/tickets/$ticketId');
    return ClientTicketDetail.fromJson(response.data!);
  }

  Future<List<TicketCategory>> fetchCategories() async {
    final response = await _dio.get<List<dynamic>>('/api/v1/client/categories');
    return (response.data ?? const [])
        .map((entry) => TicketCategory.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<ClientTicketDetail> createTicket({
    required int categoryId,
    required String title,
    required String description,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/client/tickets',
      data: {'ticket_category_id': categoryId, 'title': title, 'description': description},
    );
    return ClientTicketDetail.fromJson(response.data!);
  }

  Future<void> replyToTicket(int ticketId, String body) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/client/tickets/$ticketId/communications',
      data: {'body': body},
    );
  }

  // Se nenhuma IA estiver configurada na conta (Hook OpenAI ou
  // InstallationConfig), a tela de abertura nem mostra a opcao - evita
  // oferecer algo que vai falhar.
  Future<bool> isAiDraftEnabled() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/client/ticket_drafts/enabled');
    return (response.data?['enabled'] as bool?) ?? false;
  }

  // Devolve categoria/titulo/descricao sugeridos - nunca cria o ticket
  // sozinho, so preenche o formulario pra revisao.
  Future<TicketDraft> generateDraft(String text) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/client/ticket_drafts',
      data: {'text': text},
    );
    return TicketDraft.fromJson(response.data!);
  }

  Future<ChatSession> fetchChat() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/client/chat');
    return ChatSession.fromJson(response.data!);
  }

  Future<ChatMessage> sendChatMessage(String content) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/client/chat/messages',
      data: {'content': content},
    );
    return ChatMessage.fromJson(response.data!);
  }

  Future<List<ClientNotification>> fetchNotifications() async {
    final response = await _dio.get<List<dynamic>>('/api/v1/client/notifications');
    return (response.data ?? const [])
        .map((entry) => ClientNotification.fromJson(entry as Map<String, dynamic>))
        .toList();
  }
}

class TicketDraft {
  const TicketDraft({this.categoryId, required this.title, required this.description});

  final int? categoryId;
  final String title;
  final String description;

  factory TicketDraft.fromJson(Map<String, dynamic> json) => TicketDraft(
        categoryId: json['ticket_category_id'] as int?,
        title: (json['title'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
      );
}
