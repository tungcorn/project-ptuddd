import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

/// Shared frame for auth pages: logo, title, scrollable form.
class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.title, required this.children, this.showBack = false});

  final String title;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!showBack) ...[
                    Icon(Icons.music_note_rounded, size: 64, color: t.colorScheme.primary),
                    const SizedBox(height: 8),
                    Text('SingLearn',
                        textAlign: TextAlign.center,
                        style: t.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800, color: t.colorScheme.primary)),
                    Text('Học tiếng Anh qua bài hát',
                        textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
                    const SizedBox(height: 24),
                  ],
                  Text(title, style: t.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

mixin _Busy<T extends StatefulWidget> on State<T> {
  bool busy = false;

  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } on AuthFailure catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage('Lỗi: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with _Busy {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authRepositoryProvider);
    return _AuthFrame(
      title: 'Đăng nhập',
      children: [
        if (!AppConfig.isFirebaseConfigured)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chế độ demo: tài khoản và dữ liệu lưu trên máy này. '
                    'Cấu hình Firebase để đồng bộ đám mây.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(children: [
              TextFormField(
                key: const Key('login-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: AuthValidators.email,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('login-password'),
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: AuthValidators.password,
                onFieldSubmitted: (_) => _submit(),
              ),
            ]),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push(Routes.forgot),
            child: const Text('Quên mật khẩu?'),
          ),
        ),
        FilledButton(
          key: const Key('login-submit'),
          onPressed: busy ? null : _submit,
          child: busy
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Đăng nhập'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy || !auth.supportsGoogle
              ? null
              : () => run(() async => auth.signInWithGoogle()),
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: Text(auth.supportsGoogle
              ? 'Đăng nhập bằng Google'
              : 'Google (cần cấu hình Firebase)'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.push(Routes.register),
          child: const Text('Chưa có tài khoản? Đăng ký'),
        ),
        const Divider(height: 32),
        TextButton.icon(
          key: const Key('guest-button'),
          onPressed: busy ? null : () => run(() async => auth.continueAsGuest()),
          icon: const Icon(Icons.explore_outlined),
          label: const Text('Dùng thử không cần tài khoản (khách)'),
        ),
        Text(
          'Khách: nghe thử, học, dữ liệu chỉ lưu trên máy; không có bạn bè, '
          'thử thách, bảng xếp hạng.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await run(() async {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _email.text, password: _password.text);
    });
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> with _Busy {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: 'Tạo tài khoản',
      showBack: true,
      children: [
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(
              key: const Key('reg-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Tên hiển thị', prefixIcon: Icon(Icons.person_outline)),
              validator: AuthValidators.displayName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('reg-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('reg-password'),
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Mật khẩu (≥ 6 ký tự)', prefixIcon: Icon(Icons.lock_outline)),
              validator: AuthValidators.password,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('reg-confirm'),
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Nhập lại mật khẩu', prefixIcon: Icon(Icons.lock_reset)),
              validator: (v) => v != _password.text ? 'Mật khẩu nhập lại không khớp' : null,
            ),
          ]),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('reg-submit'),
          onPressed: busy ? null : _submit,
          child: const Text('Đăng ký'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await run(() async {
      await ref.read(authRepositoryProvider).signUp(
            email: _email.text,
            password: _password.text,
            displayName: _name.text,
          );
    });
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> with _Busy {
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authRepositoryProvider);
    return _AuthFrame(
      title: 'Quên mật khẩu',
      showBack: true,
      children: [
        if (!auth.supportsPasswordReset)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Chế độ demo không gửi được email đặt lại mật khẩu. Chức năng '
                'này hoạt động khi ứng dụng được cấu hình Firebase.',
              ),
            ),
          ),
        if (_sent)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Đã gửi email đặt lại mật khẩu. Hãy kiểm tra hộp thư.'),
            ),
          ),
        const SizedBox(height: 12),
        Form(
          key: _form,
          child: TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            validator: AuthValidators.email,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy || !auth.supportsPasswordReset
              ? null
              : () {
                  if (!_form.currentState!.validate()) return;
                  run(() async {
                    await auth.sendPasswordReset(_email.text);
                    if (mounted) setState(() => _sent = true);
                  });
                },
          child: const Text('Gửi email đặt lại'),
        ),
      ],
    );
  }
}

extension AppUserLabel on AppUser {
  String get roleLabel => isGuest ? 'Khách' : (isAdmin ? 'Quản trị viên nội dung' : 'Người học');
}
