import 'package:flutter/material.dart';
import 'package:devomnix/features/connection/model/connection_status.dart';

/// UI-level 8-state connection status.
/// Maps from the core [ConnectionStatus] but adds intermediate phases
/// managed by the app layer (config fetch, auth check, handshake, etc.)
enum ExtendedConnectionStatus {
  /// VPN is off, nothing happening
  disconnected,

  /// Checking network availability before connecting
  waitingForNetwork,

  /// Fetching VLESS config from backend
  fetchingConfig,

  /// Authenticating with backend (verifying token)
  authenticating,

  /// Core is establishing tunnel
  connecting,

  /// TLS handshake / securing the channel
  handshaking,

  /// Tunnel is active and traffic is flowing
  connected,

  /// Tearing down the tunnel
  disconnecting;

  static ExtendedConnectionStatus fromCoreStatus(ConnectionStatus status) => switch (status) {
    Disconnected() => ExtendedConnectionStatus.disconnected,
    Connecting() => ExtendedConnectionStatus.connecting,
    Connected() => ExtendedConnectionStatus.connected,
    Disconnecting() => ExtendedConnectionStatus.disconnecting,
  };

  String get label => switch (this) {
    disconnected => 'Нажмите для подключения',
    waitingForNetwork => 'Ожидание сети...',
    fetchingConfig => 'Загрузка конфига...',
    authenticating => 'Аутентификация...',
    connecting => 'Подключение...',
    handshaking => 'Защита соединения...',
    connected => 'Подключено',
    disconnecting => 'Отключение...',
  };

  bool get isActive => switch (this) {
    connecting || handshaking || fetchingConfig || authenticating || waitingForNetwork || disconnecting => true,
    _ => false,
  };

  bool get isConnected => this == ExtendedConnectionStatus.connected;

  Color color(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (this) {
      disconnected => cs.primary,
      connected => const Color(0xFF1DB954),
      connecting || handshaking || fetchingConfig || authenticating || waitingForNetwork =>
        const Color(0xFFFFA726),
      disconnecting => cs.error,
    };
  }
}
