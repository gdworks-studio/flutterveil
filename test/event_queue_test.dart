import 'dart:convert';
import 'dart:io';

import 'package:flutterveil/src/event_queue.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late EventQueue queue;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('flutterveil_queue_test_');
    queue = EventQueue(directoryProvider: () async => tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('enqueue, length, and drain preserve events and clear the queue',
      () async {
    final first = {'type': 'start', 'session_id': 'a'};
    final second = {'exception_type': 'StateError', 'session_id': 'a'};

    await queue.enqueue(first);
    await queue.enqueue(second);

    expect(await queue.length(), 2);
    expect(await queue.drain(), [first, second]);
    expect(await queue.length(), 0);
  });

  test('drain on an empty queue returns an empty list', () async {
    expect(await queue.drain(), isEmpty);
  });

  test('atomic write leaves a valid queue file and no tmp file', () async {
    final event = {'type': 'start', 'session_id': 'atomic'};
    final queueFile = File('${tempDir.path}/flutterveil_queue.json');
    final tmpFile = File('${queueFile.path}.tmp');

    await queue.enqueue(event);

    expect(await queueFile.exists(), isTrue);
    expect(await tmpFile.exists(), isFalse);
    expect(jsonDecode(await queueFile.readAsString()), [event]);
  });
}
