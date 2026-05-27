import 'dart:convert';
import 'dart:io';

import 'package:flutterveil/src/event_queue.dart';
import 'package:flutterveil/src/uploader.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {
  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return super.noSuchMethod(
      Invocation.method(
        #post,
        [url],
        {
          #headers: headers,
          #body: body,
          #encoding: encoding,
        },
      ),
      returnValue: Future.value(http.Response('', 500)),
      returnValueForMissingStub: Future.value(http.Response('', 500)),
    ) as Future<http.Response>;
  }
}

void main() {
  late Directory tempDir;
  late EventQueue queue;
  late MockHttpClient client;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('flutterveil_uploader_test_');
    queue = EventQueue(directoryProvider: () async => tempDir);
    client = MockHttpClient();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('HTTP 200 uploads drained events without re-enqueueing', () async {
    String? requestBody;
    await queue.enqueue({'exception_type': 'StateError', 'session_id': 'ok'});
    when(
      client.post(
        Uri.parse('http://localhost:8080/events'),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        encoding: anyNamed('encoding'),
      ),
    ).thenAnswer((invocation) async {
      requestBody = invocation.namedArguments[#body] as String;
      return http.Response('', 200);
    });

    final uploader = Uploader(
      queue: queue,
      httpClient: client,
      retryDelay: Duration.zero,
    );

    await uploader.upload(
      endpoint: 'http://localhost:8080',
      apiKey: 'test-key',
    );

    expect(await queue.length(), 0);
    expect(jsonDecode(requestBody!), {
      'events': [
        {'exception_type': 'StateError', 'session_id': 'ok'},
      ],
    });
  });

  test('network errors are re-enqueued after three attempts', () async {
    final event = {'exception_type': 'StateError', 'session_id': 'offline'};
    await queue.enqueue(event);
    when(
      client.post(
        Uri.parse('http://localhost:8080/events'),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        encoding: anyNamed('encoding'),
      ),
    ).thenThrow(const SocketException('offline'));

    final uploader = Uploader(
      queue: queue,
      httpClient: client,
      retryDelay: Duration.zero,
    );

    await uploader.upload(
      endpoint: 'http://localhost:8080',
      apiKey: 'test-key',
    );

    expect(await queue.drain(), [event]);
    verify(
      client.post(
        Uri.parse('http://localhost:8080/events'),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        encoding: anyNamed('encoding'),
      ),
    ).called(3);
  });

  test('HTTP 429 is not re-enqueued', () async {
    await queue
        .enqueue({'exception_type': 'StateError', 'session_id': 'limit'});
    when(
      client.post(
        Uri.parse('http://localhost:8080/events'),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        encoding: anyNamed('encoding'),
      ),
    ).thenAnswer((_) async => http.Response('', 429));

    final uploader = Uploader(
      queue: queue,
      httpClient: client,
      retryDelay: Duration.zero,
    );

    await uploader.upload(
      endpoint: 'http://localhost:8080',
      apiKey: 'test-key',
    );

    expect(await queue.length(), 0);
  });
}
