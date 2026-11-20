import 'package:flutter/material.dart';
import 'package:flutter_hbb/desktop/widgets/session_toolbar_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Start X session toolbar names each stock button',
      (tester) async {
    const labels = {
      'Control Actions': 'Ações',
      'Display Settings': 'Tela',
      'Transfer file': 'Arquivos',
      'Chat': 'Chat',
      'Start session recording': 'Gravar',
      'Stop session recording': 'Gravando',
      'Close': 'Encerrar',
    };
    for (final e in labels.entries) {
      final label = SessionToolbarLabel.of(e.key, 'assets/close.svg');
      expect(label, isNotNull, reason: e.key);
      await tester.pumpWidget(MaterialApp(home: Center(child: label)));
      expect(find.text(e.value), findsOneWidget, reason: e.key);
    }
    // Only Encerrar drops the stock filled square for its red outline.
    expect(SessionToolbarLabel.of('Close', 'assets/close.svg')!.fill(false),
        Colors.transparent);
    expect(SessionToolbarLabel.of('Chat', 'assets/chat.svg')!.fill(false),
        isNull);
    // Buttons without a label, like the pin, keep the stock icon.
    expect(SessionToolbarLabel.of('Pin Toolbar', 'assets/pin.svg'), isNull);
  });
}
