import 'dart:io';

import 'package:flutterveil/src/event_queue.dart';
import 'package:flutterveil/src/models.dart';
import 'package:flutterveil/src/session_tracker.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late EventQueue queue;
  late SessionTracker tracker;

  setUp(() async {
    SessionTracker.resetForTesting();
    tempDir =
        await Directory.systemTemp.createTemp('flutterveil_session_test_');
    queue = EventQueue(directoryProvider: () async => tempDir);
    tracker = SessionTracker(queue: queue);
  });

  tearDown(() async {
    SessionTracker.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('start returns a valid UUID v4', () async {
    final sessionId = await tracker.start();

    expect(
      sessionId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );

    final events = await queue.drain();
    final startEvent = SessionEvent.fromJson(events.single);

    expect(startEvent.sessionId, sessionId);
    expect(startEvent.type, 'session_start');
    expect(startEvent.crashed, isFalse);
  });

  test('calling start twice returns the same session ID', () async {
    final first = await tracker.start();
    final second = await tracker.start();

    expect(second, first);
    expect(await queue.length(), 1);
  });

  test('markCrashed and end produce a crashed end SessionEvent', () async {
    final sessionId = await tracker.start();

    tracker.markCrashed();
    await tracker.end();

    final events = await queue.drain();
    final endEvent = SessionEvent.fromJson(events.last);

    expect(endEvent.sessionId, sessionId);
    expect(endEvent.type, 'session_end');
    expect(endEvent.crashed, isTrue);
  });
}
