import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:devomnix/features/auth/notifier/auth_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SmsCodePage extends ConsumerStatefulWidget {
  const SmsCodePage({super.key});

  @override
  ConsumerState<SmsCodePage> createState() => _SmsCodePageState();
}

class _SmsCodePageState extends ConsumerState<SmsCodePage> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focuses = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focuses) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.smsPending;
    final phone = authState.phone ?? '';

    ref.listen(authNotifierProvider, (_, next) {
      if (next.status == AuthStatus.success && mounted) {
        // Pop back to home — router will handle redirect
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Введи код из СМС'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(authNotifierProvider.notifier).backToPhoneEntry();
            Navigator.of(context).pop();
          },
        ),
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
                  Icon(Icons.sms_outlined, size: 64, color: theme.colorScheme.primary)
                      .animate()
                      .fadeIn()
                      .scale(begin: const Offset(.6, .6)),
                  const Gap(20),
                  Text(
                    'Код отправлен на',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    phone,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Gap(36),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) => _CodeBox(
                      controller: _controllers[i],
                      focusNode: _focuses[i],
                      onChanged: (v) => _onDigit(v, i),
                      hasError: authState.errorMessage != null,
                    )),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: .2),
                  if (authState.errorMessage != null) ...[
                    const Gap(12),
                    Text(
                      authState.errorMessage!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                  const Gap(32),
                  FilledButton(
                    onPressed: isLoading ? null : _verify,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Подтвердить'),
                  ).animate().fadeIn(delay: 200.ms),
                  const Gap(16),
                  TextButton(
                    onPressed: isLoading ? null : () {
                      ref.read(authNotifierProvider.notifier).backToPhoneEntry();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Изменить номер'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onDigit(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focuses[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focuses[index - 1].requestFocus();
    }
    // Auto-submit when all 6 filled
    if (_controllers.every((c) => c.text.length == 1)) {
      _verify();
    }
  }

  void _verify() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) return;
    ref.read(authNotifierProvider.notifier).verifySmsCode(code);
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hasError,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = hasError ? theme.colorScheme.error : theme.colorScheme.outline;
    return Container(
      width: 44,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
          filled: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
