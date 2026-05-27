import 'dart:async';
import 'dart:io';

import 'error_hooks_stub.dart' if (dart.library.ui) 'error_hooks_flutter.dart';
import 'event_queue.dart';
import 'models.dart';
import 'session_tracker.dart';
import 'uploader.dart';

class FlutterVeil {
  FlutterVeil._();

  static String? _apiKey;
  static String _endpoint = 'http://localhost:8080';
  static String _appVersion = 'unknown';
  static String _buildNumber = 'unknown';
  static bool _hooksRegistered = false;

  static EventQueue _queue = EventQueue();
  static SessionTracker _sessionTracker = SessionTracker(queue: _queue);
  static Uploader _uploader = Uploader(queue: _queue);

  static Future<void> init({
    required String apiKey,
    String endpoint = 'http://localhost:8080',
    String appVersion = 'unknown',
    String buildNumber = 'unknown',
  }) async {
    _apiKey = apiKey;
    _endpoint = endpoint;
    _appVersion = appVersion;
    _buildNumber = buildNumber;

    await _sessionTracker.start();
    unawaited(upload());

    if (!_hooksRegistered) {
      registerFlutterVeilErrorHooks(_handleUncaughtError);
      _hooksRegistered = true;
    }
  }

  static Future<void> capture(Object error, StackTrace stack) async {
    final sessionId =
        _sessionTracker.sessionId ?? await _sessionTracker.start();

    await _queue.enqueue(
      CrashEvent(
        sessionId: sessionId,
        exceptionType: error.runtimeType.toString(),
        rawStackTrace: stack.toString(),
        deviceInfo: _deviceInfo(),
        appVersion: _appVersion,
        flutterVersion: const String.fromEnvironment(
          'FLUTTER_VERSION',
          defaultValue: 'unknown',
        ),
        timestamp: DateTime.now().toUtc(),
      ).toJson(),
    );

    unawaited(upload());
  }

  static Future<void> upload() async {
    final apiKey = _apiKey;
    if (apiKey == null) {
      return;
    }

    await _uploader.upload(endpoint: _endpoint, apiKey: apiKey);
  }

  static Future<void> dispose() async {
    await _sessionTracker.end();
    await upload();
  }

  static void configureForTesting({
    EventQueue? queue,
    SessionTracker? sessionTracker,
    Uploader? uploader,
  }) {
    if (queue != null) {
      _queue = queue;
    }

    _sessionTracker = sessionTracker ?? SessionTracker(queue: _queue);
    _uploader = uploader ?? Uploader(queue: _queue);
  }

  static void resetForTesting() {
    _apiKey = null;
    _endpoint = 'http://localhost:8080';
    _appVersion = 'unknown';
    _buildNumber = 'unknown';
    _hooksRegistered = false;
    _queue = EventQueue();
    _sessionTracker = SessionTracker(queue: _queue);
    _uploader = Uploader(queue: _queue);
    SessionTracker.resetForTesting();
  }

  static void _handleUncaughtError(Object error, StackTrace stack) {
    unawaited(capture(error, stack));
    _sessionTracker.markCrashed();
  }

  static Map<String, String> _deviceInfo() {
    return {
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'build_number': _buildNumber,
    };
  }
}
