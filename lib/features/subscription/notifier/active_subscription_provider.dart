import 'package:devomnix/core/preferences/general_preferences.dart';
import 'package:devomnix/features/auth/notifier/subscription_guard.dart';
import 'package:devomnix/features/backend/backend_api_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

/// Действующая подписка человека — тариф, срок и признак бессрочной.
///
/// 🔴 Заводится отдельно от `/auth/me`: там есть только `has_active_sub`,
/// булево. Из-за этого экраны могли сказать «Подписка активна» и не более
/// того — ни какой тариф, ни до какого числа. Человек не знал, что у него
/// пробный день, и не понимал, почему доступ кончился завтра.
class ActiveSubscription {
  const ActiveSubscription({
    required this.plan,
    required this.planName,
    required this.status,
    required this.expiresAt,
    required this.isPermanent,
    this.months = 1,
    this.pricePaid = 0,
  });

  final String plan;
  final String planName;
  final String status;
  final DateTime? expiresAt;
  final bool isPermanent;
  final int months;
  final double pricePaid;

  /// Пробный день, который бэкенд выдаёт сам при первом входе с устройства.
  bool get isDeviceTrial => plan == 'device_trial';

  /// Промо за полные данные (имя + Telegram + телефон).
  bool get isWelcomePromo => plan == 'promo';

  /// Бесплатный доступ любого рода — за него не начисляется реферальный бонус
  /// и его не продлевают деньгами, поэтому кнопка предлагает не «Продлить»,
  /// а «Выбрать тариф».
  bool get isFree => pricePaid == 0;

  Duration? get remaining {
    if (isPermanent || expiresAt == null) return null;
    final left = expiresAt!.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Короткая строка для шапки и главной: «Премиум · до 20.09.2026».
  String get shortLabel {
    if (isPermanent) return '$planName · бессрочно';
    if (isDeviceTrial) return 'Пробный день нового пользователя';
    if (expiresAt == null) return planName;
    return '$planName · до ${DateFormat('dd.MM.yyyy').format(expiresAt!.toLocal())}';
  }

  /// Сколько осталось, человеческим языком. `null`, если считать нечего.
  String? get remainingLabel {
    final left = remaining;
    if (left == null) return null;
    if (left == Duration.zero) return 'срок истёк';
    if (left.inDays >= 1) return 'осталось ${left.inDays} дн.';
    if (left.inHours >= 1) return 'осталось ${left.inHours} ч.';
    return 'осталось меньше часа';
  }

  factory ActiveSubscription.fromJson(Map<String, dynamic> json) {
    final raw = json['expires_at'];
    return ActiveSubscription(
      plan: json['plan'] as String? ?? '',
      // plan_name считает бэкенд по PLANS — дублировать таблицу тарифов
      // в приложении нельзя, иначе она разъедется при первой же правке цен.
      planName: json['plan_name'] as String? ?? json['plan'] as String? ?? 'Подписка',
      status: json['status'] as String? ?? '',
      expiresAt: raw is String ? DateTime.tryParse(raw) : null,
      isPermanent: json['is_permanent'] == true,
      months: (json['months'] as num?)?.toInt() ?? 1,
      pricePaid: (json['price_paid'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// `GET /subscriptions/active` → `null`, если активной подписки нет.
///
/// Подписан на те же ключи, что и `accountInfoProvider`: смена JWT и
/// [accountRevisionProvider] перечитывают и его — иначе после оплаты или
/// активации промокода шапка показывала бы прежний тариф до перезахода.
final activeSubscriptionProvider =
    FutureProvider.autoDispose<ActiveSubscription?>((ref) async {
  ref.watch(Preferences.jwtToken);
  ref.watch(accountRevisionProvider);

  final dio = ref.watch(backendDioProvider);
  final response = await dio.get<dynamic>('/subscriptions/active');
  final data = response.data;
  // Ручка отдаёт null, когда активной подписки нет — это не ошибка.
  if (data is! Map) return null;
  return ActiveSubscription.fromJson(Map<String, dynamic>.from(data));
});
