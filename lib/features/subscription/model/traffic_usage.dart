/// Сколько трафика человек израсходовал и сколько ему положено по тарифу.
///
/// 🔴 Три поля приезжают парой источников — `GET /auth/me` и
/// `GET /subscriptions/active`. Разбор один на оба: какой из ответов их
/// принесёт первым, экрану всё равно, а два одинаковых парсера разъехались бы
/// при первой же правке имён полей.
class TrafficUsage {
  const TrafficUsage({
    required this.used,
    required this.limit,
    required this.exceeded,
  });

  /// Байты, потраченные за текущий период.
  final int used;

  /// Лимит тарифа в байтах. `null` или 0 — безлимит.
  final int? limit;

  /// Считает бэкенд: у него свои правила округления и момент сброса счётчика,
  /// и сравнивать used с limit на клиенте — значит их дублировать.
  final bool exceeded;

  bool get isUnlimited => limit == null || limit! <= 0;

  /// Заполненность полосы, 0..1. `null` — рисовать нечего (безлимит).
  double? get ratio {
    if (isUnlimited) return null;
    return (used / limit!).clamp(0.0, 1.0);
  }

  /// Осталось байт; 0, если лимит выбран.
  int get remaining {
    if (isUnlimited) return 0;
    final left = limit! - used;
    return left.isNegative ? 0 : left;
  }

  /// «Использовано: 1.18 ГБ / 1.00 ГБ» — или без второй половины на безлимите.
  String get label => isUnlimited
      ? 'Использовано: ${formatTrafficBytes(used)}'
      : 'Использовано: ${formatTrafficBytes(used)} / ${formatTrafficBytes(limit!)}';

  /// `null`, если в ответе нет ни одного из полей: старый бэкенд ничего о
  /// трафике не знает, и рисовать пустую полосу с нулями — врать человеку,
  /// будто лимит есть и он не тронут.
  static TrafficUsage? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final hasAnyField = json.containsKey('traffic_used') ||
        json.containsKey('traffic_limit') ||
        json.containsKey('traffic_exceeded');
    if (!hasAnyField) return null;

    return TrafficUsage(
      used: (json['traffic_used'] as num?)?.toInt() ?? 0,
      limit: (json['traffic_limit'] as num?)?.toInt(),
      exceeded: json['traffic_exceeded'] == true,
    );
  }
}

/// Байты человеческим языком: КБ / МБ / ГБ, делитель двоичный — так же
/// считает панель, по которой человек будет сверять цифру.
String formatTrafficBytes(int bytes) {
  if (bytes <= 0) return '0 МБ';
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;

  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} ГБ';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} МБ';
  return '${(bytes / kb).toStringAsFixed(0)} КБ';
}
