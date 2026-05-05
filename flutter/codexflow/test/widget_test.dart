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
    expect(find.text('审批'), findsWidgets);
    expect(find.text('设置'), findsOneWidget);
  });
}
