import 'dart:math';

import 'event_queue.dart';
import 'models.dart';

class SessionTracker {
  SessionTracker({
    EventQueue? queue,
  }) : _queue = queue ?? EventQueue();

  static final Random _random = Random.secure();
  static String? _sessionId;
  static bool _crashed = false;

  final EventQueue _queue;

  String? get sessionId => _sessionId;

  Future<String> start() async {
    if (_sessionId != null) {
      return _sessionId!;
    }

    _sessionId = _uuidV4();
    _crashed = false;

    await _queue.enqueue(
      SessionEvent(
        sessionId: _sessionId!,
        type: 'session_start',
        crashed: false,
        timestamp: DateTime.now().toUtc(),
      ).toJson(),
    );

    return _sessionId!;
  }

  void markCrashed() {
    _crashed = true;
  }

  Future<void> end() async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }

    await _queue.enqueue(
      SessionEvent(
        sessionId: sessionId,
        type: 'session_end',
        crashed: _crashed,
        timestamp: DateTime.now().toUtc(),
      ).toJson(),
    );
  }

  static void resetForTesting() {
    _sessionId = null;
    _crashed = false;
  }

  static String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int start, int length) {
      return bytes
          .sublist(start, start + length)
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
    }

    return '${hex(0, 4)}-${hex(4, 2)}-${hex(6, 2)}-'
        '${hex(8, 2)}-${hex(10, 6)}';
  }
}
