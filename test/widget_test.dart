import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_messenger/app.dart';

void main() {
  testWidgets('App loads chat screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BluetoothMessengerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BT Messenger'), findsOneWidget);
  });
}
