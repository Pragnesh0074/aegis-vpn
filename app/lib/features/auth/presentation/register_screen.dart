import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/detail_row.dart';
import 'auth_controller.dart';
import 'widgets/auth_form_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
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
    await ref.read(authControllerProvider.notifier).register(
          email: _email.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        showMessage(context, describeError(error), isError: true);
      }
    });

    return AuthFormScaffold(
      title: 'Create an account',
      subtitle: 'Registering signs you straight in.',
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
                validator: Validators.newPassword,
                onSubmitted: _submit,
              ),
              Gap.sm,
              Text(
                'At least ${Validators.passwordMinLength} characters. '
                'No other rules — length is what matters.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
              : const Text('Create account'),
        ),
        Gap.sm,
        TextButton(
          onPressed: state.isLoading ? null : () => context.go(AppRoutes.login),
          child: const Text('I already have an account'),
        ),
      ],
    );
  }
}
