import 'dart:async';

import 'package:devomnix/core/model/constants.dart';
import 'package:devomnix/core/preferences/general_preferences.dart';
import 'package:devomnix/features/backend/backend_api_provider.dart';
import 'package:devomnix/features/backend/backend_error.dart';
import 'package:devomnix/features/connection/notifier/connection_notifier.dart';
import 'package:devomnix/features/profile/notifier/active_profile_notifier.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Ответ на вопрос «есть ли подписка».
///
/// 🔴 Третье значение обязательно. Пока их было два, «сервер не ответил»
/// сливалось с «сервер ответил, подписки нет» — и любой обрыв связи выглядел
/// как отобранная подписка: кнопка отказывалась подключать, профиль писал
/// «нет активной подписки», а на сервере подписка всё это время была.
enum SubscriptionCheck {
  /// Сервер ответил: подписка активна.
  active,

  /// Сервер ответил: подписки нет. Единственный случай, когда доступ
  /// действительно закрывают.
  inactive,

  /// Сервер не ответил. Права не меняем — работаем по последнему известному.
  unknown;

  bool get isKnown => this != SubscriptionCheck.unknown;
}

/// Снимок `GET /auth/me` с моментом получения.
class AccountSnapshot {
  const AccountSnapshot({required this.me, required this.fetchedAt});

  final Map<String, dynamic> me;
  final DateTime fetchedAt;

  bool get hasActiveSub => me['has_active_sub'] == true;
}

/// Проверка подписки в трёх точках (Авторизация.md) и единственный владелец
/// запроса `GET /auth/me`.
///
///   1. при запуске приложения;
///   2. при нажатии «Подключиться» — с кешем на 5 минут;
///   3. раз в час, пока VPN активен → отключить, если подписки уже нет.
///
/// Закрывает три случая, в которых доступ обязан прекратиться, а сам по себе
/// не прекращается: возврат звёзд, истечение срока и отключение админом.
///
/// 🔴 Сюда же стянут сам запрос `/auth/me`. Раньше его дублировали четверо —
/// `subscriptionStatusProvider`, шапка Профиля, экран «Мой аккаунт» и этот
/// guard, — и открытие Профиля отправляло три одинаковых запроса подряд.
/// На канале, который и так еле отвечает, это превращалось в «всё грузится
/// вечно»: запросы душили друг друга.
class SubscriptionGuard extends Notifier<bool> {
  static const _cacheTtl = Duration(minutes: 5);
  static const _pollInterval = Duration(hours: 1);

  /// Потолок ожидания для проверок, за которыми стоит живой человек и палец
  /// на кнопке. Дольше — кнопка выглядит сломанной, а ответа всё равно нет.
  static const _interactiveTimeout = Duration(seconds: 5);

  AccountSnapshot? _snapshot;
  Future<AccountSnapshot>? _inFlight;
  Object? _lastError;
  Timer? _timer;

  /// Причина, по которой последний запрос не удался. Экраны показывают её
  /// текстом вместо «что-то пошло не так».
  Object? get lastError => _lastError;

  /// Последний удачный ответ `/auth/me`, если он был.
  Map<String, dynamic>? get cachedMe => _snapshot?.me;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());

    // Часовой опрос включается вместе с VPN и гаснет вместе с ним: проверять
    // подписку у отключённого клиента незачем, а забытый таймер жёг бы батарею.
    ref.listen(connectionNotifierProvider, (_, next) {
      final connected = next.valueOrNull?.isConnected ?? false;
      if (!connected) {
        stopPolling();
        return;
      }
      // 🔴 Сторожим только СВОЙ сервер. Человек, подключившийся своей
      // vless-строкой, платит за тот сервер сам; отключать его по нашей
      // подписке — значит рвать соединение, к которому мы не имеем отношения.
      // Отметить устройство живым всё равно полезно: это его аккаунт.
      unawaited(_markConnected());
      if (_isOurServerActive) startPolling();
    });

    // Стартовое значение — из прошлого запуска, чтобы UI не мигал «нет подписки»
    // до первого ответа бэкенда.
    return ref.read(Preferences.hasActiveSub);
  }

  /// Активен ли сейчас профиль, который мы выдали сами (а не свой сервер
  /// пользователя). Подписка сторожит только его.
  bool get _isOurServerActive =>
      ref.read(activeProfileProvider).valueOrNull?.name == Constants.autoProfileName;

  /// Точка 1: старт приложения.
  Future<SubscriptionCheck> checkOnStartup() => _check(force: true);

  /// Точка 2: перед подключением. Свежий ответ моложе 5 минут переиспользуем —
  /// иначе каждое нажатие кнопки ждало бы сеть.
  ///
  /// [patient] — у человека нет локального конфига, и без ответа сервера
  /// подключаться всё равно нечем: тут ожидание оправдано, отказ через пять
  /// секунд просто заставил бы жать кнопку второй раз.
  Future<SubscriptionCheck> ensureActiveBeforeConnect({bool patient = false}) =>
      _check(timeout: patient ? const Duration(seconds: 12) : _interactiveTimeout);

  /// Принудительно перечитать статус, не заставляя вызывающего ждать.
  Future<SubscriptionCheck> refresh() => _check(force: true);

  /// Отмечает устройство живым сразу после того, как туннель встал.
  ///
  /// 🔴 Здесь именно повторный вход `/auth/device`, а не `/auth/me`.
  /// `last_seen` и `is_active` в `device_sessions` обновляет только вход
  /// (`auth.py`), а `/auth/me` их не трогает. Без этого вызова устройство
  /// в «Моём аккаунте» и у поддержки выглядит заброшенным ровно в тот момент,
  /// когда VPN работает, — и подключение неоткуда подтвердить, кроме 3X-UI.
  Future<void> _markConnected() async {
    // Даём маршрутам встать: запрос, ушедший в первую секунду после
    // Connected, обычно теряется на перестройке таблицы маршрутизации.
    await Future<void>.delayed(const Duration(seconds: 2));
    await ref.read(backendSessionProvider).login(attempts: 1);
    await refresh();
  }

  /// Точка 3: пока VPN активен — проверяем раз в час.
  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) async {
      final result = await _check(force: true);
      // 🔴 Рвём соединение ТОЛЬКО на явном отказе сервера. На `unknown`
      // (сеть недоступна) — никогда: раньше здесь хватало любого обрыва,
      // чтобы отключить VPN у честно оплатившего, причём именно в момент,
      // когда связь и так плохая.
      if (result == SubscriptionCheck.inactive) {
        await ref.read(connectionNotifierProvider.notifier).abortConnection();
        stopPolling();
      }
    });
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// Сбрасывает кеш — после оплаты или промокода статус нужен свежий,
  /// без ожидания 5 минут.
  ///
  /// Заодно будит экраны: сбросить кеш и не сказать об этом никому значило бы,
  /// что только что активированный промокод виден лишь после ухода с экрана
  /// и возврата на него.
  void invalidateCache() {
    _snapshot = null;
    ref.read(accountRevisionProvider.notifier).state++;
  }

  /// Ответ `/auth/me`: из кеша, если он моложе 5 минут, иначе из сети.
  ///
  /// [timeout] ограничивает ожидание вызывающего, но не отменяет сам запрос:
  /// он дойдёт до конца и наполнит кеш, просто ответ достанется следующему.
  Future<AccountSnapshot> fetchMe({bool force = false, Duration? timeout}) {
    final cached = _snapshot;
    if (!force && cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return Future.value(cached);
    }

    var future = _inFlight;
    if (future == null) {
      future = _load();
      _inFlight = future;
      final started = future;
      started.whenComplete(() {
        if (identical(_inFlight, started)) _inFlight = null;
      });
      // Отдельная подписка на отказ: если единственный ждавший ушёл по
      // таймауту, ошибка иначе всплыла бы как unhandled и уронила зону.
      unawaited(started.then((_) {}, onError: (Object _) {}));
    }

    return timeout == null ? future : future.timeout(timeout);
  }

  Future<SubscriptionCheck> _check({bool force = false, Duration? timeout}) async {
    try {
      final snapshot = await fetchMe(force: force, timeout: timeout);
      return snapshot.hasActiveSub
          ? SubscriptionCheck.active
          : SubscriptionCheck.inactive;
    } catch (_) {
      // Причина уже сохранена в [lastError] и напечатана в лог — здесь
      // важно лишь не выдать молчание сети за ответ «подписки нет».
      return SubscriptionCheck.unknown;
    }
  }

  Future<AccountSnapshot> _load() async {
    try {
      // Без токена запрос уйдёт без Authorization, получит 401 и только потом
      // пойдёт логиниться — лишний круг по сети там, где её и так мало.
      await ref.read(backendSessionProvider).ensureToken();

      final response = await ref.read(backendDioProvider).get('/auth/me');
      final me = Map<String, dynamic>.from(response.data as Map);
      final snapshot = AccountSnapshot(me: me, fetchedAt: DateTime.now());

      _snapshot = snapshot;
      _lastError = null;
      state = snapshot.hasActiveSub;
      await ref.read(Preferences.hasActiveSub.notifier).update(snapshot.hasActiveSub);

      final publicId = me['public_id'];
      if (publicId != null) {
        await ref.read(Preferences.publicId.notifier).update('$publicId');
      }
      ref.read(accountRevisionProvider.notifier).state++;
      return snapshot;
    } catch (e) {
      _lastError = e;
      debugPrint('[sub] GET /auth/me не удался: ${describeBackendError(e)}');
      rethrow;
    }
  }
}

final subscriptionGuardProvider =
    NotifierProvider<SubscriptionGuard, bool>(SubscriptionGuard.new);

/// Счётчик удачных ответов `/auth/me`.
///
/// Экраны ограничивают своё ожидание секундами, а запрос после этого живёт
/// дальше и всё-таки доходит. Без этого счётчика опоздавший ответ пропадал
/// впустую: экран так и оставался с ошибкой, пока человек не уйдёт с него
/// и не вернётся. Подписавшись сюда, он перерисовывается сам.
final accountRevisionProvider = StateProvider<int>((ref) => 0);
