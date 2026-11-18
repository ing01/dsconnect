import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:duedesk_mobile/core/push/push_filter.dart';

Map<String, dynamic> push(Map<String, dynamic> payload) => {'payload': jsonEncode(payload)};

void main() {
  group('parsePushTarget', () {
    test('o aviso de resposta no chamado leva ao chamado, pela tag', () {
      final target = parsePushTarget(push({
        'tag': 'client_ticket_communication_49371',
        'url': '/app/client/tickets/49371',
      }));

      expect(target, isA<TicketPushTarget>());
      expect((target! as TicketPushTarget).ticketId, 49371);
    });

    test('sem a tag, usa o numero na url', () {
      final target = parsePushTarget(push({'url': '/app/client/tickets/812'}));

      expect((target! as TicketPushTarget).ticketId, 812);
    });

    test('o aviso do chat leva ao Chat', () {
      final target = parsePushTarget(push({'tag': 'client_chat_7'}));

      expect(target, isA<ChatPushTarget>());
    });

    test('o que nao e reconhecivel nao leva a lugar nenhum', () {
      expect(parsePushTarget({}), isNull);
      expect(parsePushTarget({'payload': 'nao e json'}), isNull);
      expect(parsePushTarget({'payload': '[1,2]'}), isNull);
      expect(parsePushTarget(push({'tag': 'outra_coisa', 'url': '/app/accounts/1/inbox'})), isNull);
    });
  });
}
