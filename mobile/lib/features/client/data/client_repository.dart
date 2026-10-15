import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_message.dart';
import '../models/client_notification.dart';
import '../models/client_ticket.dart';
import '../models/client_ticket_detail.dart';
import '../models/company.dart';
import '../models/filter_option.dart';
import '../models/ticket_category.dart';

// Rotas fora de /accounts/:id - a conta do cliente vem do proprio token, nunca
// da URL (ver Api::V1::Client::BaseController no servidor).
class ClientRepository {
  ClientRepository(this._dio);

  final Dio _dio;

  Future<ClientTicketsResult> fetchTickets({
    int? companyId,
    String? query,
    int? teamId,
    int? ticketColumnId,
    int? assigneeId,
    String? createdAfter,
    String? createdBefore,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/client/tickets',
      queryParameters: {
        // ignore: use_null_aware_elements
        if (companyId != null) 'company_id': companyId,
        // ignore: use_null_aware_elements
        if (query != null && query.isNotEmpty) 'q': query,
        // ignore: use_null_aware_elements
        if (teamId != null) 'team_id': teamId,
        // ignore: use_null_aware_elements
        if (ticketColumnId != null) 'ticket_column_id': ticketColumnId,
        // ignore: use_null_aware_elements
        if (assigneeId != null) 'assignee_id': assigneeId,
        // ignore: use_null_aware_elements
        if (createdAfter != null) 'created_after': createdAfter,
        // ignore: use_null_aware_elements
        if (createdBefore != null) 'created_before': createdBefore,
      },
    );
    // O servidor devolve {"companies": [...], "teams": [...],
    // "ticket_columns": [...], "assignees": [...], "tickets": [...]} - ver
    // api/v1/client/tickets/index.json.jbuilder.
    final tickets = (response.data?['tickets'] as List<dynamic>? ?? const [])
        .map((entry) => ClientTicket.fromJson(entry as Map<String, dynamic>))
        .toList();
    final companies = (response.data?['companies'] as List<dynamic>? ?? const [])
        .map((entry) => Company.fromJson(entry as Map<String, dynamic>))
        .toList();
    final teams = (response.data?['teams'] as List<dynamic>? ?? const [])
        .map((entry) => FilterOption.fromJson(entry as Map<String, dynamic>))
        .toList();
    final ticketColumns = (response.data?['ticket_columns'] as List<dynamic>? ?? const [])
        .map((entry) => FilterOption.fromJson(entry as Map<String, dynamic>))
        .toList();
    final assignees = (response.data?['assignees'] as List<dynamic>? ?? const [])
        .map((entry) => FilterOption.fromJson(entry as Map<String, dynamic>))
        .toList();
    return ClientTicketsResult(
      tickets: tickets,
      companies: companies,
      teams: teams,
      ticketColumns: ticketColumns,
      assignees: assignees,
    );
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
    List<XFile> attachments = const [],
  }) async {
    final data = FormData.fromMap({
      'ticket_category_id': categoryId,
      'title': title,
      'description': description,
    });
    await _appendAttachments(data, attachments);

    final response = await _dio.post<Map<String, dynamic>>('/api/v1/client/tickets', data: data);
    return ClientTicketDetail.fromJson(response.data!);
  }

  Future<void> replyToTicket(int ticketId, String body, {List<XFile> attachments = const []}) async {
    final data = FormData.fromMap({'body': body});
    await _appendAttachments(data, attachments);

    await _dio.post<Map<String, dynamic>>('/api/v1/client/tickets/$ticketId/communications', data: data);
  }

  // `attachments[]` repetido - o servidor le com `Array(params[:attachments])`
  // dos dois lados (abertura e resposta), igual o formulario web manda.
  Future<void> _appendAttachments(FormData data, List<XFile> attachments) async {
    for (final file in attachments) {
      data.files.add(MapEntry('attachments[]', await MultipartFile.fromFile(file.path, filename: file.name)));
    }
  }

  // Se nenhuma IA estiver configurada na conta (Hook OpenAI ou
  // InstallationConfig), a tela de abertura nem mostra a opcao - evita
  // oferecer algo que vai falhar.
  Future<bool> isAiDraftEnabled() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/client/ticket_drafts/enabled');
    return (response.data?['enabled'] as bool?) ?? false;
  }

  // Devolve categoria/titulo/descricao sugeridos - nunca cria o ticket
  // sozinho, so preenche o formulario pra revisao. Texto digitado tem
  // prioridade; sem ele, manda o audio gravado pra transcricao no servidor
  // (mesma regra de `Api::V1::Client::TicketDraftsController#resolved_text`).
  Future<TicketDraft> generateDraft({String? text, XFile? audio}) async {
    final Object data;
    if (text != null && text.isNotEmpty) {
      data = {'text': text};
    } else if (audio != null) {
      final formData = FormData();
      formData.files.add(MapEntry('audio', await MultipartFile.fromFile(audio.path, filename: audio.name)));
      data = formData;
    } else {
      data = {};
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/client/ticket_drafts',
      data: data,
    );
    return TicketDraft.fromJson(response.data!);
  }

  Future<ChatSession> fetchChat() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/client/chat');
    return ChatSession.fromJson(response.data!);
  }

  Future<ChatMessage> sendChatMessage(
    String content, {
    List<XFile> attachments = const [],
    bool isVoiceMessage = false,
  }) async {
    final data = FormData.fromMap({
      if (content.isNotEmpty) 'content': content,
      if (isVoiceMessage) 'is_voice_message': true,
    });
    await _appendAttachments(data, attachments);

    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/client/chat/messages',
      data: data,
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

class ClientTicketsResult {
  const ClientTicketsResult({
    required this.tickets,
    required this.companies,
    this.teams = const [],
    this.ticketColumns = const [],
    this.assignees = const [],
  });

  final List<ClientTicket> tickets;
  final List<Company> companies;
  final List<FilterOption> teams;
  final List<FilterOption> ticketColumns;
  final List<FilterOption> assignees;
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
