import 'package:dio/dio.dart';

import '../auth/session_storage.dart';
import '../config.dart';
import 'auth_interceptor.dart';

// Um único cliente HTTP pro app inteiro, com o header certo já injetado em
// toda chamada (ver AuthInterceptor) - nenhuma tela precisa saber como
// autenticar, só chamar `dio.get(...)`/`dio.post(...)` normalmente.
class ApiClient {
  ApiClient(SessionStorage sessionStorage) {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));
    dio.interceptors.add(AuthInterceptor(sessionStorage));
  }

  late final Dio dio;
}
