import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../bin/upload_symbols.dart' as cli;

void main() {
  test('endpoint validation requires HTTPS except localhost', () {
    expect(cli.normalizeEndpoint('https://example.com/api'),
        'https://example.com/api');
    expect(cli.normalizeEndpoint('http://localhost:8080'),
        'http://localhost:8080');
    expect(cli.normalizeEndpoint('http://127.0.0.1:8080/'),
        'http://127.0.0.1:8080');

    expect(
      () => cli.normalizeEndpoint('http://example.com'),
      throwsA(isA<FormatException>()),
    );
  });

  test('uploads android mapping as multipart symbol file', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('flutterveil_symbols_cli_');
    final mapping = File('${tempDir.path}/mapping.txt');
    await mapping.writeAsString('com.example.MainActivity -> a.a:\n');

    final received = Completer<_ReceivedRequest>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.first.then((request) async {
        final body = await utf8.decodeStream(request);
        received.complete(
          _ReceivedRequest(
            method: request.method,
            path: request.uri.path,
            authorization:
                request.headers.value(HttpHeaders.authorizationHeader),
            contentType: request.headers.contentType?.mimeType,
            body: body,
          ),
        );
        request.response.statusCode = HttpStatus.created;
        request.response.write('{"id":"symbol-file-1"}');
        await request.response.close();
      }),
    );

    final exitCode = await cli.runUploadSymbols([
      '--path',
      tempDir.path,
      '--api-key',
      'test-api-key',
      '--app-version',
      '1.2.3',
      '--platform',
      'android',
      '--endpoint',
      'http://127.0.0.1:${server.port}',
    ]);

    final request = await received.future;
    await server.close(force: true);
    await tempDir.delete(recursive: true);

    expect(exitCode, 0);
    expect(request.method, 'POST');
    expect(request.path, '/v1/symbol-files');
    expect(request.authorization, 'Bearer test-api-key');
    expect(request.contentType, 'multipart/form-data');
    expect(request.body, contains('name="app_version"'));
    expect(request.body, contains('1.2.3'));
    expect(request.body, contains('name="platform"'));
    expect(request.body, contains('android'));
    expect(request.body, contains('filename="mapping.txt"'));
    expect(request.body, contains('com.example.MainActivity -> a.a:'));
  });
}

class _ReceivedRequest {
  const _ReceivedRequest({
    required this.method,
    required this.path,
    required this.authorization,
    required this.contentType,
    required this.body,
  });

  final String method;
  final String path;
  final String? authorization;
  final String? contentType;
  final String body;
}
