import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/features/auth/presentation/auth_screens.dart';
import 'package:singlearn/features/profile/presentation/profile_screen.dart';

import 'harness.dart';

void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() => app.dispose());

  testWidgets('ProfileScreen isolates user data and roles between accounts and guest', (tester) async {
    // 1. User A (First account -> Admin)
    await app.auth.signUp(
      email: 'usera@test.vn',
      password: 'secret1',
      displayName: 'Nguyễn Văn A',
    );
    await app.auth.updateProfile(level: 'B1');

    await app.pumpScreen(tester, const ProfileScreen());
    await settleIo(tester);

    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('usera@test.vn'), findsOneWidget);
    expect(find.textContaining('Quản trị viên nội dung'), findsOneWidget);
    expect(find.byKey(const Key('admin-entry')), findsOneWidget);
    expect(find.textContaining('Mã kết bạn:'), findsOneWidget);

    // 2. User B (Second account -> Learner, non-admin)
    await app.auth.signOut();
    final userB = await app.auth.signUp(
      email: 'userb@test.vn',
      password: 'secret2',
      displayName: 'Trần Thị B',
    );
    await app.auth.updateProfile(level: 'A2');

    await app.pumpScreen(tester, const ProfileScreen());
    await settleIo(tester);

    // User A data must NOT be present
    expect(find.text('Nguyễn Văn A'), findsNothing);
    expect(find.text('usera@test.vn'), findsNothing);
    expect(find.byKey(const Key('admin-entry')), findsNothing);

    // User B data is displayed
    expect(find.text('Trần Thị B'), findsOneWidget);
    expect(find.text('userb@test.vn'), findsOneWidget);
    expect(find.textContaining('Người học'), findsOneWidget);
    expect(userB.isAdmin, isFalse);

    // 3. Guest Mode
    await app.auth.signOut();
    await app.auth.continueAsGuest();

    await app.pumpScreen(tester, const ProfileScreen());
    await settleIo(tester);

    expect(find.text('Khách'), findsWidgets);
    expect(find.textContaining('Mã kết bạn:'), findsNothing);
    expect(
      find.text('Đăng ký tài khoản để sử dụng (khách chỉ học trên máy).'),
      findsOneWidget,
    );
    expect(find.text('Thoát chế độ khách'), findsOneWidget);
  });

  testWidgets('ForgotPasswordScreen clearly shows demo mode cloud requirement', (tester) async {
    await app.pumpScreen(tester, const ForgotPasswordScreen());
    await settleIo(tester);

    expect(find.text('Quên mật khẩu'), findsOneWidget);
    expect(
      find.textContaining('Chế độ demo không gửi được email đặt lại mật khẩu'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Chức năng này hoạt động khi ứng dụng được cấu hình Firebase.'),
      findsOneWidget,
    );

    // Button is disabled in demo mode
    final submitButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Gửi email đặt lại'),
    );
    expect(submitButton.onPressed, isNull);
  });
}
