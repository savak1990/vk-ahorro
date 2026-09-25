import 'package:ahorro_ui/src/screens/templates/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

AppShellTab _tab(String label) => AppShellTab(
  label: label,
  icon: const Icon(Icons.circle_outlined),
  builder: (_) => Text('$label body'),
);

void main() {
  testWidgets('the floating action button runs its callback', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      PlatformProvider(
        initialPlatform: TargetPlatform.android,
        builder: (_) => MaterialApp(
          home: AppShell(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            tabData: [_tab('Home'), _tab('Activity'), _tab('Account')],
            floatingButtonAction: ActionData(
              label: 'Add',
              icon: Icons.add,
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home body'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(taps, 1);
  });
}
