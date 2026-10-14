import 'package:dio/dio.dart';

// Mensagem com o que o servidor respondeu de verdade - mesma ideia do
// `_describeError` do login (ver auth_repository.dart), pra qualquer tela
// que precise mostrar um erro real em vez de um genérico demais pra agir.
String describeApiError(Object error) {
  if (error is! DioException) return error.toString();

  final status = error.response?.statusCode;
  if (status == null) return 'Não foi possível conectar ao servidor (${error.message}).';

  final body = error.response?.data;
  final message = body is Map ? (body['error'] ?? body) : body;
  return 'O servidor respondeu com erro $status: $message';
}
