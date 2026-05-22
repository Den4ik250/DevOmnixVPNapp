import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthPage extends ConsumerWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (_, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: () => ref.read(authNotifierProvider.notifier).reset(),
            ),
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Assets.images.logo
                      .svg(
                        height: 80,
                        colorFilter: ColorFilter.mode(
                          theme.colorScheme.primary,
                          BlendMode.srcIn,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(.7, .7)),
                  const Gap(24),
                  Text(
                    Constants.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const Gap(8),
                  Text(
                    'Безопасный VPN с авторизацией через Telegram',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const Gap(56),
                  if (authState.status == AuthStatus.waitingForBot)
                    _WaitingWidget(botUrl: authState.botUrl)
                        .animate()
                        .fadeIn(duration: 400.ms)
                  else
                    _LoginButton(
                      isLoading: authState.status == AuthStatus.loading,
                      onTap: () => ref.read(authNotifierProvider.notifier).startLogin(),
                    ).animate().fadeIn(delay: 450.ms).slideY(begin: .2, curve: Curves.easeOut),
                  if (authState.status == AuthStatus.error) ...[
                    const Gap(16),
                    TextButton(
                      onPressed: () => ref.read(authNotifierProvider.notifier).reset(),
                      child: const Text('Попробовать снова'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.telegram),
      label: Text(isLoading ? 'Подготовка...' : 'Войти через Telegram'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _WaitingWidget extends StatelessWidget {
  const _WaitingWidget({this.botUrl});

  final String? botUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1800.ms, color: theme.colorScheme.primaryContainer),
        ),
        const Gap(28),
        Text(
          'Ожидание подтверждения\nв Telegram',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const Gap(8),
        Text(
          'Откройте бота и нажмите «Старт».\nОкно закрывать не нужно.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(32),
        if (botUrl != null)
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(botUrl!),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Открыть Telegram-бота'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
      ],
    );
  }
}
