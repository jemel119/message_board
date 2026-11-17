import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_board/main.dart';

void main() {
  testWidgets('shows the vault splash and loading indicator', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VaultSplash()));

    expect(find.text('Message Board Vault'), findsOneWidget);
    expect(find.text('Opening your message board…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
