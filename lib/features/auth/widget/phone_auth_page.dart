import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/auth/widget/sms_code_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PhoneAuthPage extends ConsumerStatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  ConsumerState<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends ConsumerState<PhoneAuthPage> {
  final _phone = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _phone.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.smsPending;

    ref.listen(authNotifierProvider, (_, next) {
      if (next.status == AuthStatus.smsVerifying && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SmsCodePage()),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Подтверждение номера'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.phone_android_rounded, size: 40, color: theme.colorScheme.primary),
                  ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(.6, .6)),
                  const Gap(24),
                  Text(
                    'Получи 5 дней бесплатно',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ).animate().fadeIn(delay: 100.ms),
                  const Gap(8),
                  Text(
                    'Введи номер телефона — пришлём\nСМС с кодом подтверждения.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ).animate().fadeIn(delay: 150.ms),
                  const Gap(36),
                  TextField(
                    controller: _phone,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\+\-\(\) ]'))],
                    decoration: InputDecoration(
                      labelText: 'Номер телефона',
                      hintText: '+7 999 123-45-67',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      errorText: authState.errorMessage,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _send(),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: .2),
                  const Gap(8),
                  Text(
                    'Один номер — один аккаунт',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const Gap(24),
                  FilledButton.icon(
                    onPressed: isLoading ? null : _send,
                    icon: isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: Text(isLoading ? 'Отправляем...' : 'Отправить код'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ).animate().fadeIn(delay: 280.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _send() {
    final phone = _phone.text.trim();
    if (phone.isEmpty) return;
    ref.read(authNotifierProvider.notifier).sendSmsCode(phone);
  }
}
