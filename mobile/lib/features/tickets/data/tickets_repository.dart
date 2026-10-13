import 'package:dio/dio.dart';

import '../models/team.dart';
import '../models/ticket_column.dart';
import '../models/ticket_detail.dart';
import '../models/ticket_summary.dart';

// So' os dois endpoints que a Fase 2 (lista "Meus tickets" + filtro por
// Mesa) precisa - mover Estagio, mudar status etc. entram junto da tela de
// detalhe, numa proxima etapa.
class TicketsRepository {
  TicketsRepository(this._dio);

  final Dio _dio;

  Future<List<Team>> fetchTeams(int accountId) async {
    final response = await _dio.get<List<dynamic>>('/api/v1/accounts/$accountId/teams');
    return (response.data ?? const [])
        .map((entry) => Team.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<List<TicketColumn>> fetchColumns(int accountId, int teamId) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/accounts/$accountId/teams/$teamId/ticket_columns',
    );
    return (response.data ?? const [])
        .map((entry) => TicketColumn.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<TicketDetail> fetchDetail(int accountId, int ticketId) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/accounts/$accountId/tickets/$ticketId');
    return TicketDetail.fromJson(response.data!);
  }

  Future<TicketDetail> moveToColumn(int accountId, int ticketId, int columnId) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/accounts/$accountId/tickets/$ticketId/move',
      data: {'ticket_column_id': columnId},
    );
    return TicketDetail.fromJson(response.data!);
  }

  // `resolve`/`reopen`/`close`/`cancel` sao a mesma forma: PATCH sem corpo
  // (so' `cancel` aceita um motivo opcional), devolvendo o ticket atualizado.
  Future<TicketDetail> changeStatus(int accountId, int ticketId, String action, {String? reason}) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/accounts/$accountId/tickets/$ticketId/$action',
      data: reason != null ? {'reason': reason} : null,
    );
    return TicketDetail.fromJson(response.data!);
  }

  // `mine=true` e' sempre mandado - a Fase 2 so' mostra os tickets do proprio
  // colaborador logado, igual o painel web faz por padrao em "Meus
  // tickets". `teamId` nulo busca em todas as Mesas que o colaborador
  // participa.
  Future<TicketPage> fetchMine({
    required int accountId,
    int? teamId,
    int page = 1,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/accounts/$accountId/tickets',
      queryParameters: {
        'mine': true,
        // Esse lint so vale pra elemento de lista/set; nao existe um
        // `?chave: valor` equivalente pra entrada de mapa.
        // ignore: use_null_aware_elements
        if (teamId != null) 'team_id': teamId,
        'page': page,
      },
    );

    final payload = (response.data?['payload'] as List<dynamic>? ?? const [])
        .map((entry) => TicketSummary.fromJson(entry as Map<String, dynamic>))
        .toList();
    final meta = response.data?['meta'] as Map<String, dynamic>? ?? const {};

    return TicketPage(
      tickets: payload,
      totalCount: (meta['count'] as int?) ?? payload.length,
      currentPage: (meta['current_page'] as int?) ?? page,
    );
  }
}

class TicketPage {
  const TicketPage({required this.tickets, required this.totalCount, required this.currentPage});

  final List<TicketSummary> tickets;
  final int totalCount;
  final int currentPage;
}
