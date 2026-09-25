import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yfc_app/main.dart';
import 'package:yfc_app/providers/app_state.dart';

void main() {
  testWidgets('YFC App renders SplashScreen correctly', (WidgetTester tester) async {
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const YfcApp(),
      ),
    );

    expect(find.textContaining('YOUTH FOR CHRIST'), findsOneWidget);

    // Advance time past SplashScreen navigation timer
    await tester.pump(const Duration(seconds: 3));

    appState.dispose();
  });
}
