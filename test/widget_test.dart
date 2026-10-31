import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novatv/core/theme.dart';

void main() {
  testWidgets('o tema carrega em modo escuro', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: Text('Nova TV')),
      ),
    );

    expect(find.text('Nova TV'), findsOneWidget);
  });
}
