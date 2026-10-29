import 'package:dio/dio.dart';

// Contato bloqueado nao usa o chat com a equipe: o servidor responde 403 com
// `code: chat_blocked` e o aviso (com o telefone) em `error`. Devolve esse
// aviso quando e' o caso; null para qualquer outro erro (rede, 500...).
String? chatBlockedMessage(Object error) {
  if (error is! DioException) return null;
  if (error.response?.statusCode != 403) return null;

  final data = error.response?.data;
  if (data is! Map || data['code'] != 'chat_blocked') return null;

  final message = data['error'];
  return message is String && message.isNotEmpty
      ? message
      : 'Você não tem permissão para acessar o suporte via chat, ligue no telefone (18) 3916-7600.';
}
