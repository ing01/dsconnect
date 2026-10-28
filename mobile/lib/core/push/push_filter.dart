import 'dart:convert';

// O push do cliente leva a marca do tipo em `data.payload` (JSON): o aviso de
// conversa do Portal usa a tag `client_chat_<id>` e o de ticket usa
// `client_ticket_communication_<id>` (ver Client::ChatPushNotificationService e
// Client::TicketCommunicationPushNotificationService, no servidor).
const _chatTagPrefix = 'client_chat_';

// E' aviso de conversa do Portal? Qualquer coisa que nao seja reconhecivel
// (sem payload, JSON quebrado, aviso do colaborador) NAO e': na duvida o aviso
// aparece, em vez de sumir.
bool isClientChatPush(Map<String, dynamic> data) {
  final raw = data['payload'];
  if (raw is! String) return false;

  try {
    final payload = jsonDecode(raw);
    if (payload is! Map) return false;
    final tag = payload['tag'];
    return tag is String && tag.startsWith(_chatTagPrefix);
  } catch (_) {
    return false;
  }
}

// Com o app ABERTO o sistema nao mostra o aviso sozinho - quem decide e' o app.
// Dentro da aba do Chat a conversa ja esta na tela, entao o aviso de conversa
// nao aparece; o de ticket aparece sempre. Com o app fechado ou em segundo
// plano isto nem roda: o proprio sistema mostra os dois.
bool shouldShowForegroundPush(Map<String, dynamic> data, {required bool chatTabOpen}) {
  return !(chatTabOpen && isClientChatPush(data));
}
