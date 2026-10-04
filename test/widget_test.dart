import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/main.dart';
import 'package:heritage_walk/shared/widgets/heritage_bottom_navigation.dart';
import 'package:heritage_walk/shared/widgets/heritage_text_field.dart';

void main() {
  testWidgets('Preview loads logo and stays within small phone layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [const Size(320, 568), const Size(412, 915)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const HeritageWalkApp(initialRoute: '/'));
      await tester.pumpAndSettle();
      expect(find.text('HeritageWalk'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<HeritageBottomNavigation>(
              find.byType(HeritageBottomNavigation),
            )
            .selectedIndex,
        1,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Password visibility and form validation work', (tester) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: HeritageTextField(
              label: 'Password',
              isPassword: true,
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
          ),
        ),
      ),
    );
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isFalse,
    );
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
  });
}
