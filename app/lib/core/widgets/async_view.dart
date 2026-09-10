import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/app_exception.dart';
import '../theme/app_theme.dart';

/// Renders an [AsyncValue] with a consistent loading and error treatment.
///
/// Every screen in the app funnels through this, so an error from the API looks
/// the same whether it came from `/nodes` or `/devices`, and always offers a retry.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      // `skipLoadingOnRefresh` keeps the current list on screen during a pull to
      // refresh instead of flashing a spinner over content the user is reading.
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AppErrorView(error: error, onRetry: onRetry),
      data: data,
    );
  }
}

/// A failure, phrased for a person.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40.r, color: theme.colorScheme.error),
            Gap.md,
            Text(
              describeError(error),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              Gap.md,
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Turns anything thrown into a sentence.
///
/// A 400 from the backend carries an array of class-validator messages; joining
/// them is what makes "password must be at least 10 characters" reach the user
/// instead of a generic "Bad Request".
String describeError(Object error) {
  return switch (error) {
    ApiException e when e.isValidation && e.messages.isNotEmpty => e.messages.join('\n'),
    ApiException e when e.isRateLimited =>
      'Too many attempts. Wait a minute and try again.',
    ApiException e when e.statusCode >= 500 =>
      'The server had a problem. Please try again shortly.',
    AppException e => e.message,
    _ => 'Something went wrong.',
  };
}
