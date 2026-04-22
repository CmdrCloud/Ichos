import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_end/main.dart';

void main() {
  testWidgets('renders the playlist screen and reacts to taps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const IxosApp());

    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('FOCUS'), findsOneWidget);
    expect(find.text('Beats para Codear'), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);

    await tester.tap(find.text('FELIZ'));
    await tester.pumpAndSettle();

    expect(find.text('Brillo de Manana'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });
}
