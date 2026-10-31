import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final state = AppState();
  try {
    await state.init();
  } catch (error, stack) {
    debugPrint('Falha ao iniciar o estado do app: $error\n$stack');
  }

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const NovaTvApp(),
    ),
  );
}
