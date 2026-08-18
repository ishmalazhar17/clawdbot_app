// =====================================================================
// widget_test.dart — a basic "smoke test" that just confirms the app
// launches without crashing. Not required for your FYP demo, but
// good to keep working/error-free rather than deleting it outright.
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clawdbot_app/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // Builds the actual app (ClawdBotApp, our real root widget) and
    // lets Flutter's testing framework render one frame of it.
    await tester.pumpWidget(const ClawdBotApp());

    // If we get here with no exception thrown, the app built
    // successfully — that's the whole point of this basic check.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}