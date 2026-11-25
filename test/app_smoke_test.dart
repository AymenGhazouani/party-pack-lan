import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:party_pack_lan/main.dart';
import 'package:party_pack_lan/state/app_controller.dart';

void main() {
  testWidgets('app boots to title and navigates to host/join menu',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController();
    await app.init();

    await tester.pumpWidget(PartyPackApp(app: app));
    await tester.pumpAndSettle();

    expect(find.text('START'), findsOneWidget);
    expect(find.text('PARTY\nPACK'), findsOneWidget);

    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();

    expect(find.text('HOST GAME'), findsOneWidget);
    expect(find.text('JOIN GAME'), findsOneWidget);
  });
}
