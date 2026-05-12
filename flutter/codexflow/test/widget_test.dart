import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:codexflow_flutter/main.dart';

void main() {
  testWidgets('renders CodexFlow shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(CodexFlowApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('会话'), findsWidgets);
    expect(find.byIcon(Icons.checklist_rounded), findsNothing);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('changes primary chrome when language is switched', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'codexflow.languageCode': 'en',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(CodexFlowApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('Sessions'), findsWidgets);
    expect(find.byIcon(Icons.checklist_rounded), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
  });
}
