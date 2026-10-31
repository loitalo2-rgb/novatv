import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'ui/app_shell.dart';

class NovaTvApp extends StatelessWidget {
  const NovaTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova TV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const AppShell(),
    );
  }
}
