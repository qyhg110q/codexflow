import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'package:codexflow_flutter/widgets/common.dart';

void main() {
  testWidgets('renders latex blocks and inline formulas as math widgets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownBodyBlock(
            raw:
                'Inline formula \\(a^2+b^2=c^2\\)\n\n'
                'Block formula:\n'
                '\\[\n'
                '\\zeta(s)=\\sum_{n=1}^{\\infty}\\frac{1}{n^s}\n'
                '\\]',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Math), findsNWidgets(2));
    expect(find.textContaining(r'\zeta'), findsNothing);
    expect(find.textContaining(r'\('), findsNothing);
    expect(find.textContaining(r'\['), findsNothing);
  });
}
