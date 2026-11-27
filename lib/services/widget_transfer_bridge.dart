import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Called only by the foreground service's engine. The native widget owns the
/// queue of launcher taps and resolves the current episode and folder on read.
class WidgetTransferBridge {
  WidgetTransferBridge({this._clock = DateTime.now});

  static const _channel = MethodChannel('tamashii/widget');
  final DateTime Function() _clock;
  final _last = <String, ({String status, int? percent, DateTime sent})>{};

  Future<List<Map<String, dynamic>>> pendingDownloads() async {
    final requests = await _channel.invokeListMethod<Object?>(
      'pendingDownloads',
    );
    return [
      for (final item in requests ?? [])
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<void> publish(
    String key,
    String status, {
    double? fraction,
    bool force = false,
  }) async {
    final percent = fraction != null && fraction.isFinite
        ? (fraction.clamp(0.0, 1.0) * 100).floor()
        : null;
    final now = _clock();
    final last = _last[key];
    if (!force &&
        last != null &&
        last.status == status &&
        (last.percent == percent ||
            now.difference(last.sent) < const Duration(seconds: 5))) {
      return;
    }
    final current = (status: status, percent: percent, sent: now);
    _last[key] = current;
    try {
      await _channel.invokeMethod<void>('transferState', {
        'torrentKey': key,
        'status': status,
        'progress': percent,
      });
    } catch (error) {
      if (_last[key] == current) _last.remove(key);
      debugPrint('Could not update the widget for $key: $error');
    }
  }

  Future<void> serviceStopped() async {
    _last.clear();
    try {
      await _channel.invokeMethod<void>('serviceStopped');
    } catch (error) {
      debugPrint('Could not notify the widget of service shutdown: $error');
    }
  }
}
