enum BackendUpdateStatus { initial, checking, upToDate, softUpdate, forceUpdate, error }

class BackendUpdateState {
  const BackendUpdateState({
    this.status = BackendUpdateStatus.initial,
    this.latestVersion = '',
    this.whatsNew = '',
    this.downloadUrl = '',
  });

  final BackendUpdateStatus status;
  final String latestVersion;
  final String whatsNew;
  final String downloadUrl;
}
