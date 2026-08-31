import 'dart:async';

/// Tracks which foreground-task instance currently owns the native manager.
///
/// Android may deliver the old task's `service_stopped` message after a
/// replacement task has already started. Retired instance IDs make that late
/// message harmless without suppressing a genuine stop from the replacement.
class ForegroundServiceInstanceTracker {
  String? _activeInstanceId;
  final Set<String> _retiredInstanceIds = <String>{};

  String? get activeInstanceId => _activeInstanceId;

  void beginRestart() {
    final activeInstanceId = _activeInstanceId;
    if (activeInstanceId != null) {
      _retiredInstanceIds.add(activeInstanceId);
      _activeInstanceId = null;
    }
  }

  void markReady(String instanceId) {
    final activeInstanceId = _activeInstanceId;
    if (activeInstanceId != null && activeInstanceId != instanceId) {
      _retiredInstanceIds.add(activeInstanceId);
    }
    _activeInstanceId = instanceId;
  }

  /// Returns whether a message from [instanceId] belongs to the live or
  /// not-yet-identified replacement task.
  bool acceptsMessage(String? instanceId) {
    if (instanceId == null || instanceId.isEmpty) {
      return false;
    }
    if (_retiredInstanceIds.contains(instanceId)) {
      return false;
    }
    final activeInstanceId = _activeInstanceId;
    return activeInstanceId == null || activeInstanceId == instanceId;
  }

  /// Returns true only when the stop belongs to the current task.
  bool acceptStopped(String? instanceId) {
    if (!acceptsMessage(instanceId)) {
      return false;
    }

    _activeInstanceId = null;
    return true;
  }

  /// Retires the current task before an intentional stop so a delayed stop
  /// notification cannot invalidate a service started immediately afterward.
  void retireCurrent() {
    beginRestart();
  }
}

typedef CancelDelayedAction = void Function();
typedef DelayedActionScheduler = CancelDelayedAction Function(
  Duration delay,
  void Function() callback,
);

CancelDelayedAction _scheduleTimer(Duration delay, void Function() callback) {
  final timer = Timer(delay, callback);
  return timer.cancel;
}

/// Owns a delayed service-stop request and invalidates it when work changes.
///
/// The generation is checked again after the delay, allowing callers to queue
/// the final stop behind torrent commands without an old callback stopping a
/// newly started transfer.
class DelayedServiceStopController {
  DelayedServiceStopController({DelayedActionScheduler? scheduler})
    : _scheduler = scheduler ?? _scheduleTimer;

  final DelayedActionScheduler _scheduler;
  CancelDelayedAction? _cancel;
  int _generation = 0;
  bool _scheduled = false;

  bool get isScheduled => _scheduled;

  void schedule({
    required Duration delay,
    required void Function(int generation) onElapsed,
  }) {
    if (_scheduled) {
      return;
    }

    _scheduled = true;
    final generation = _generation;
    _cancel = _scheduler(delay, () {
      _cancel = null;
      if (isCurrent(generation)) {
        onElapsed(generation);
      }
    });
  }

  bool isCurrent(int generation) => _scheduled && generation == _generation;

  void invalidate() {
    _generation++;
    _cancel?.call();
    _cancel = null;
    _scheduled = false;
  }

  void dispose() {
    invalidate();
  }
}
