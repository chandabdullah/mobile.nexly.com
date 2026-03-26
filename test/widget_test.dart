import 'package:flutter_test/flutter_test.dart';

import 'package:video_downloader/main.dart';

void main() {
  testWidgets('Nexly home renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(initialRoute: '/home'));
    await tester.pumpAndSettle();

    expect(find.text('Nexly'), findsOneWidget);
    expect(find.text('Paste your video link'), findsOneWidget);
  });
}
