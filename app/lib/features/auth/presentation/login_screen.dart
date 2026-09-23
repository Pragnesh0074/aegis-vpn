import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/detail_row.dart';
import 'controller/auth_controller.dart';
import 'widgets/auth_form_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authControllerProvider.notifier)
        .login(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    // Errors are shown as a snack bar rather than replacing the form: the user
    // needs their typed credentials to still be there.
    ref.listen(authControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        showMessage(context, describeError(error), isError: true);
      }
    });

    return AuthFormScaffold(
      title: 'Sign in',
      subtitle: 'Your own WireGuard network.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              Gap.md,
              PasswordField(
                controller: _password,
                label: 'Password',
                validator: Validators.requiredPassword,
                onSubmitted: _submit,
              ),
            ],
          ),
        ),
        Gap.lg,
        FilledButton(
          onPressed: state.isLoading ? null : _submit,
          child: state.isLoading
              ? SizedBox.square(
                  dimension: 20.r,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign in'),
        ),
        Gap.sm,
        TextButton(
          onPressed: state.isLoading
              ? null
              : () => context.go(AppRoutes.register),
          child: const Text('Create an account'),
        ),
      ],
    );
  }
}
