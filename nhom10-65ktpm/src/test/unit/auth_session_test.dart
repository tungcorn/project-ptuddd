import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:singlearn/core/storage/local_store.dart';
import 'package:singlearn/features/auth/data/auth_repository.dart';
import 'package:singlearn/features/auth/domain/app_user.dart';

import '../helpers.dart';

void main() {
  late LocalStore store;
  late LocalAuthRepository auth;

  setUp(() async {
    store = await openTestStore();
    auth = LocalAuthRepository(store);
  });

  tearDown(() => closeTestStore(store));

  group('M4 - Authentication, Session & Access Control', () {
    test('validator catches invalid email, weak password, short/long display name', () {
      expect(AuthValidators.email(''), 'Vui lòng nhập email');
      expect(AuthValidators.email('notanemail'), 'Email không hợp lệ');
      expect(AuthValidators.email('test@example.com'), isNull);

      expect(AuthValidators.password(''), 'Vui lòng nhập mật khẩu');
      expect(AuthValidators.password('123'), 'Mật khẩu tối thiểu 6 ký tự');
      expect(AuthValidators.password('123456'), isNull);

      expect(AuthValidators.displayName('a'), 'Tên tối thiểu 2 ký tự');
      expect(
        AuthValidators.displayName('a' * 41),
        'Tên tối đa 40 ký tự',
      );
      expect(AuthValidators.displayName('Phạm Ngọc Bách'), isNull);
    });

    test('sign up hashes password with salt and sets admin for first local account', () async {
      final user = await auth.signUp(
        email: 'bach@example.com',
        password: 'password123',
        displayName: 'Ngọc Bách',
      );

      expect(user.email, 'bach@example.com');
      expect(user.displayName, 'Ngọc Bách');
      expect(user.isAdmin, isTrue, reason: 'First local account is granted admin');
      expect(auth.current, equals(user));

      // Mật khẩu không bao giờ được lưu plain text
      final rawAccount = await store.get(LocalAuthRepository.accountsBox, 'bach@example.com');
      expect(rawAccount, isNotNull);
      expect(rawAccount!['hash'], isNot('password123'));
      expect(rawAccount['salt'], isNotEmpty);
    });

    test('session persistence: restore() recovers session across app restarts with store closed', () async {
      final dir = await Directory.systemTemp.createTemp('singlearn_auth_restart_');
      Hive.init(dir.path);
      var restartStore = LocalStore();
      var restartAuth = LocalAuthRepository(restartStore);

      await restartAuth.signUp(
        email: 'persist@example.com',
        password: 'password123',
        displayName: 'Persist User',
      );

      // Mô phỏng đóng app hoàn toàn: đóng toàn bộ Hive boxes
      await restartStore.close();
      await Hive.close();

      // Mở lại app từ cùng thư mục lưu trữ
      Hive.init(dir.path);
      restartStore = LocalStore();
      restartAuth = LocalAuthRepository(restartStore);
      expect(restartAuth.current, isNull, reason: 'Before restore() state is uninitialized');

      await restartAuth.restore();
      expect(restartAuth.current, isNotNull);
      expect(restartAuth.current!.email, 'persist@example.com');
      expect(restartAuth.current!.displayName, 'Persist User');

      await closeTestStore(restartStore);
    });

    test('guest mode and sign out clears current session', () async {
      final guest = await auth.continueAsGuest();
      expect(guest.isGuest, isTrue);
      expect(guest.uid, 'guest');
      expect(auth.current?.isGuest, isTrue);

      await auth.signOut();
      expect(auth.current, isNull);

      // Kiểm tra restore() sau sign out vẫn không có session cũ
      await auth.restore();
      expect(auth.current, isNull);
    });

    test('switching accounts (A -> sign out -> B) isolates sessions and roles', () async {
      // Đăng ký user A
      final userA = await auth.signUp(
        email: 'userA@example.com',
        password: 'password123',
        displayName: 'User A',
      );
      expect(userA.isAdmin, isTrue);
      expect(auth.current?.email, 'usera@example.com');

      // Đăng xuất A -> current về null
      await auth.signOut();
      expect(auth.current, isNull);

      // Đăng ký user B
      final userB = await auth.signUp(
        email: 'userB@example.com',
        password: 'password456',
        displayName: 'User B',
      );
      expect(userB.isAdmin, isFalse, reason: 'Subsequent accounts are not admin');
      expect(auth.current?.email, 'userb@example.com');
      expect(auth.current?.displayName, 'User B');

      // Đăng nhập lại user A
      final signedInA = await auth.signIn(
        email: 'usera@example.com',
        password: 'password123',
      );
      expect(signedInA.email, 'usera@example.com');
      expect(signedInA.isAdmin, isTrue);
      expect(auth.current?.email, 'usera@example.com');
    });

    test('demo mode password reset throws AuthFailure and indicates cloud requirement', () async {
      expect(auth.supportsPasswordReset, isFalse);
      expect(
        auth.sendPasswordReset('user@example.com'),
        throwsA(isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          contains('cấu hình Firebase'),
        )),
      );
    });

    test('sign in with wrong password or non-existent email throws AuthFailure', () async {
      await auth.signUp(
        email: 'real@example.com',
        password: 'correctpassword',
        displayName: 'Real User',
      );

      expect(
        auth.signIn(email: 'real@example.com', password: 'wrongpassword'),
        throwsA(isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          'Email hoặc mật khẩu không đúng',
        )),
      );

      expect(
        auth.signIn(email: 'ghost@example.com', password: 'password123'),
        throwsA(isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          'Email hoặc mật khẩu không đúng',
        )),
      );
    });
  });
}
