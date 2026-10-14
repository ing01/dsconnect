import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/push/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (error) {
    // Sem google-services.json valido (ex.: build de desenvolvimento sem
    // Firebase configurado) o app continua funcionando normalmente, so sem
    // notificacao push.
    debugPrint('Firebase nao inicializou: $error');
  }

  runApp(const ProviderScope(child: DuedeskApp()));
}
