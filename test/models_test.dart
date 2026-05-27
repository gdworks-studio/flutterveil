import 'package:flutterveil/src/models.dart';
import 'package:test/test.dart';

void main() {
  group('CrashEvent', () {
    test('round-trips through toJson and fromJson', () {
      final event = CrashEvent(
        sessionId: 'session-1',
        exceptionType: 'StateError',
        rawStackTrace: '#0 main',
        deviceInfo: const {
          'os': 'macos',
          'os_version': 'Version 1',
        },
        appVersion: '1.0.0',
        flutterVersion: '3.41.9',
        timestamp: DateTime.utc(2026, 5, 27, 10, 30),
      );

      final decoded = CrashEvent.fromJson(event.toJson());

      expect(decoded.sessionId, event.sessionId);
      expect(decoded.exceptionType, event.exceptionType);
      expect(decoded.rawStackTrace, event.rawStackTrace);
      expect(decoded.deviceInfo, event.deviceInfo);
      expect(decoded.appVersion, event.appVersion);
      expect(decoded.flutterVersion, event.flutterVersion);
      expect(decoded.timestamp, event.timestamp);
    });
  });

  group('SessionEvent', () {
    test('round-trips through toJson and fromJson', () {
      final event = SessionEvent(
        sessionId: 'session-1',
        type: 'end',
        crashed: true,
        timestamp: DateTime.utc(2026, 5, 27, 10, 31),
      );

      final decoded = SessionEvent.fromJson(event.toJson());

      expect(decoded.sessionId, event.sessionId);
      expect(decoded.type, event.type);
      expect(decoded.crashed, event.crashed);
      expect(decoded.timestamp, event.timestamp);
    });
  });
}
