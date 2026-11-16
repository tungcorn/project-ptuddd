import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/app/app.dart';

void main() {
  testWidgets('shows the SingLearn project and its initial status', (
    tester,
  ) async {
    await tester.pumpWidget(const SingLearnApp());

    expect(find.text('SingLearn'), findsOneWidget);
    expect(find.text('Học tiếng Anh qua bài hát'), findsOneWidget);
    expect(find.text('Nhóm 10 · 65KTPM'), findsOneWidget);
    expect(find.textContaining('chưa được triển khai'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a small Android screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SingLearnApp());

    expect(find.text('Học tiếng Anh qua bài hát'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
