class CrashEvent {
  const CrashEvent({
    required this.sessionId,
    required this.exceptionType,
    required this.rawStackTrace,
    required this.deviceInfo,
    required this.appVersion,
    required this.flutterVersion,
    required this.timestamp,
  });

  final String sessionId;
  final String exceptionType;
  final String rawStackTrace;
  final Map<String, String> deviceInfo;
  final String appVersion;
  final String flutterVersion;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'exception_type': exceptionType,
      'raw_stack_trace': rawStackTrace,
      'device_info': deviceInfo,
      'app_version': appVersion,
      'flutter_version': flutterVersion,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

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

class SessionEvent {
  const SessionEvent({
    required this.sessionId,
    required this.type,
    required this.crashed,
    required this.timestamp,
  });

  final String sessionId;
  final String type;
  final bool crashed;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'type': type,
      'crashed': crashed,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  factory SessionEvent.fromJson(Map<String, dynamic> json) {
    return SessionEvent(
      sessionId: json['session_id'] as String,
      type: json['type'] as String,
      crashed: json['crashed'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
