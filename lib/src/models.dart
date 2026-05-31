/// A single crash report captured on-device and sent to the ingestion endpoint.
///
/// Produced internally by [FlutterVeil.capture] — you normally never construct
/// one yourself. It is exported so backends and tests can work with the exact
/// wire format the SDK uploads.
class CrashEvent {
  /// Creates a crash event. Every field is required and maps 1:1 to the JSON
  /// the ingestion endpoint expects (see [toJson]).
  const CrashEvent({
    required this.sessionId,
    required this.exceptionType,
    required this.rawStackTrace,
    required this.deviceInfo,
    required this.appVersion,
    required this.flutterVersion,
    required this.timestamp,
  });

  /// Identifier of the session this crash occurred in.
  final String sessionId;

  /// The runtime type of the thrown error, e.g. `StateError`.
  final String exceptionType;

  /// The unsymbolicated stack trace as captured on-device.
  final String rawStackTrace;

  /// Device and OS metadata (`os`, `os_version`, `build_number`).
  final Map<String, String> deviceInfo;

  /// The host app's version string, e.g. `1.0.0`.
  final String appVersion;

  /// The Flutter framework version the app was built against.
  final String flutterVersion;

  /// When the crash occurred. Serialized as a UTC ISO-8601 string.
  final DateTime timestamp;

  /// Serializes this event to the JSON map the ingestion endpoint expects.
  Map<String, dynamic> toJson() {
    return {
      'type': 'crash',
      'session_id': sessionId,
      'exception_type': exceptionType,
      'raw_stack_trace': rawStackTrace,
      'device_info': deviceInfo,
      'app_version': appVersion,
      'flutter_version': flutterVersion,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  /// Reconstructs a [CrashEvent] from its [toJson] representation.
  factory CrashEvent.fromJson(Map<String, dynamic> json) {
    return CrashEvent(
      sessionId: json['session_id'] as String,
      exceptionType: json['exception_type'] as String,
      rawStackTrace: json['raw_stack_trace'] as String,
      deviceInfo: Map<String, String>.from(
        (json['device_info'] as Map).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      ),
      appVersion: json['app_version'] as String,
      flutterVersion: json['flutter_version'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// A session lifecycle event — `session_start` or `session_end` — used by the
/// backend to compute crash-free session rates.
class SessionEvent {
  /// Creates a session event.
  const SessionEvent({
    required this.sessionId,
    required this.type,
    required this.crashed,
    required this.timestamp,
  });

  /// Identifier of the session.
  final String sessionId;

  /// The event kind: `session_start` or `session_end`.
  final String type;

  /// Whether the session ended in a crash.
  final bool crashed;

  /// When the event occurred. Serialized as a UTC ISO-8601 string.
  final DateTime timestamp;

  /// Serializes this event to its JSON map.
  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'type': type,
      'crashed': crashed,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  /// Reconstructs a [SessionEvent] from its [toJson] representation.
  factory SessionEvent.fromJson(Map<String, dynamic> json) {
    return SessionEvent(
      sessionId: json['session_id'] as String,
      type: json['type'] as String,
      crashed: json['crashed'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
