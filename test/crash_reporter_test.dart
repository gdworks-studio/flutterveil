import 'dart:io';

import 'package:flutterveil/flutterveil.dart';
import 'package:flutterveil/src/event_queue.dart';
import 'package:flutterveil/src/session_tracker.dart';
import 'package:flutterveil/src/uploader.dart';
import 'package:test/test.dart';

class NoopUploader extends Uploader {
  NoopUploader({required EventQueue queue})
      : super(queue: queue, retryDelay: Duration.zero);

  @override
  Future<void> upload({
    required String endpoint,
    required String apiKey,
  }) async {}
}

class RecordingUploader extends Uploader {
  RecordingUploader({required EventQueue queue})
      : super(queue: queue, retryDelay: Duration.zero);

  int uploadCount = 0;

  @override
  Future<void> upload({
    required String endpoint,
    required String apiKey,
  }) async {
    uploadCount += 1;
  }
}

void main() {
  late Directory tempDir;
  late EventQueue queue;

  setUp(() async {
    FlutterVeil.resetForTesting();
    SessionTracker.resetForTesting();
    tempDir =
        await Directory.systemTemp.createTemp('flutterveil_reporter_test_');
    queue = EventQueue(directoryProvider: () async => tempDir);
    FlutterVeil.configureForTesting(
      queue: queue,
      uploader: NoopUploader(queue: queue),
    );
  });

  tearDown(() async {
    FlutterVeil.resetForTesting();
    SessionTracker.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('init completes without error', () async {
    await FlutterVeil.init(apiKey: 'test-key');

    expect(await queue.length(), 1);
  });

  test('capture results in a crash event in the queue', () async {
    await FlutterVeil.init(apiKey: 'test-key', appVersion: '1.2.3');

    await FlutterVeil.capture(StateError('boom'), StackTrace.current);

    final events = await queue.drain();
    final crash = events
        .where((event) => event.containsKey('exception_type'))
        .map(CrashEvent.fromJson)
        .first;

    expect(crash.appVersion, '1.2.3');
    expect(crash.exceptionType, 'StateError');
    expect(crash.rawStackTrace, isNotEmpty);
    expect(crash.deviceInfo['os'], isNotEmpty);
  });

  test('init disables uploads for a non-HTTPS, non-localhost endpoint', () async {
    final recording = RecordingUploader(queue: queue);
    FlutterVeil.configureForTesting(queue: queue, uploader: recording);

    await FlutterVeil.init(
      apiKey: 'test-key',
      endpoint: 'http://insecure.example.com',
    );
    await FlutterVeil.upload();

    expect(recording.uploadCount, 0);
  });

  test('init allows uploads for an HTTPS endpoint', () async {
    final recording = RecordingUploader(queue: queue);
    FlutterVeil.configureForTesting(queue: queue, uploader: recording);

    await FlutterVeil.init(
      apiKey: 'test-key',
      endpoint: 'https://secure.example.com',
    );
    await FlutterVeil.upload();

    expect(recording.uploadCount, greaterThan(0));
  });

  test('dispose ends the session', () async {
    await FlutterVeil.init(apiKey: 'test-key');

    await FlutterVeil.dispose();

    final events = await queue.drain();
    final sessionEvents = events
        .where((event) => event.containsKey('type'))
        .map(SessionEvent.fromJson)
        .toList();

    expect(sessionEvents.map((event) => event.type), contains('session_end'));
  });
}
