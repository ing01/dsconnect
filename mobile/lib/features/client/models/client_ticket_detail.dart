import 'client_ticket.dart';
import 'ticket_communication.dart';

class ClientTicketDetail {
  const ClientTicketDetail({required this.ticket, required this.communications});

  final ClientTicket ticket;
  final List<TicketCommunication> communications;

  factory ClientTicketDetail.fromJson(Map<String, dynamic> json) => ClientTicketDetail(
        ticket: ClientTicket.fromJson(json),
        communications: (json['communications'] as List<dynamic>? ?? const [])
            .map((entry) => TicketCommunication.fromJson(entry as Map<String, dynamic>))
            .toList(),
      );
}
