import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/auth/widget/sms_code_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class PhoneAuthPage extends ConsumerStatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  ConsumerState<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends ConsumerState<PhoneAuthPage> {
  final _phone = TextEditingController();
  final _focusNode = FocusNode();
  String? _validationError;
  bool _isValid = false;

  final _mask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'\d')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
    super.initState();
    _phone.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phone.removeListener(_onPhoneChanged);
    _phone.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final raw = _phone.text;

    // Auto-replace leading 8 → +7
    if (raw == '8') {
      _mask.clear();
      _phone.value = _mask.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '+7'),
      );
      return;
    }

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final valid = digits.length == 11 && (digits.startsWith('7') || digits.startsWith('8'));

    setState(() {
      _isValid = valid;
      _validationError = null;
    });
  }

  String _rawPhone() {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8') && digits.length == 11) {
      return '+7${digits.substring(1)}';
    }
    return '+$digits';
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
      if (next.status == AuthStatus.error && mounted) {
        setState(() => _validationError = next.errorMessage);
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
                    inputFormatters: [_mask],
                    decoration: InputDecoration(
                      labelText: 'Номер телефона',
                      hintText: '+7 (999) 123-45-67',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      errorText: _validationError,
                      errorStyle: const TextStyle(color: Colors.red),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _isValid ? _send() : null,
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: .2),
                  const Gap(8),
                  Text(
                    'Один номер — один аккаунт',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const Gap(24),
                  FilledButton.icon(
                    onPressed: (!isLoading && _isValid) ? _send : null,
                    icon: isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: Text(isLoading ? 'Отправляем...' : 'Получить код'),
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
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) {
      setState(() => _validationError = 'Введите корректный номер (+7 или 8)');
      return;
    }
    setState(() => _validationError = null);
    ref.read(authNotifierProvider.notifier).sendSmsCode(_rawPhone());
  }
}
