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
    expect(
      () => cli.normalizeEndpoint('https://user:pass@example.com'),
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
        final bytes = await request.fold<List<int>>(
          <int>[],
          (previous, element) => previous..addAll(element),
        );
        final body = latin1.decode(bytes);
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
      '--app-version',
      '1.2.3',
      '--build-number',
      '42',
      '--platform',
      'android',
      '--endpoint',
      'http://127.0.0.1:${server.port}',
    ], environment: {
      'FLUTTERVEIL_UPLOAD_KEY': 'test-upload-key',
    });

    final request = await received.future;
    await server.close(force: true);
    await tempDir.delete(recursive: true);

    expect(exitCode, 0);
    expect(request.method, 'POST');
    expect(request.path, '/v1/symbol-files');
    expect(request.authorization, 'Bearer test-upload-key');
    expect(request.contentType, 'multipart/form-data');
    expect(request.body, contains('name="app_version"'));
    expect(request.body, contains('1.2.3'));
    expect(request.body, contains('name="build_number"'));
    expect(request.body, contains('42'));
    expect(request.body, contains('name="platform"'));
    expect(request.body, contains('android'));
    expect(request.body, contains('filename="mapping.txt"'));
    expect(request.body, contains('com.example.MainActivity -> a.a:'));
  });

  test('can read upload key from stdin', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('flutterveil_symbols_cli_');
    final mapping = File('${tempDir.path}/mapping.txt');
    await mapping.writeAsString('com.example.MainActivity -> a.a:\n');

    final received = Completer<_ReceivedRequest>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.first.then((request) async {
        final bytes = await request.fold<List<int>>(
          <int>[],
          (previous, element) => previous..addAll(element),
        );
        final body = latin1.decode(bytes);
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
        await request.response.close();
      }),
    );

    final exitCode = await cli.runUploadSymbols([
      '--path',
      tempDir.path,
      '--app-version',
      '1.2.3',
      '--platform',
      'android',
      '--endpoint',
      'http://127.0.0.1:${server.port}',
      '--upload-key-stdin',
    ], environment: {}, readStdinLine: () async => 'stdin-upload-key');

    final request = await received.future;
    await server.close(force: true);
    await tempDir.delete(recursive: true);

    expect(exitCode, 0);
    expect(request.authorization, 'Bearer stdin-upload-key');
  });

  test('rejects removed api-key flag and invalid flags', () async {
    expect(
      await cli.runUploadSymbols([
        '--api-key',
        'old-key',
        '--path',
        'symbols',
      ], environment: {}),
      cli.usageExitCode,
    );
    expect(
      await cli.runUploadSymbols(['--unknown', 'value'], environment: {}),
      cli.usageExitCode,
    );
    expect(
      await cli.runUploadSymbols([
        '--path',
        'one',
        '--path',
        'two',
      ], environment: {}),
      cli.usageExitCode,
    );
  });

  test('normalizes trailing slash dSYM path before zipping', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('flutterveil_symbols_cli_');
    final dsym = Directory('${tempDir.path}/Runner.app.dSYM');
    final dwarf = Directory('${dsym.path}/Contents/Resources/DWARF');
    await dwarf.create(recursive: true);
    await File('${dwarf.path}/Runner').writeAsString('symbol data');

    final received = Completer<_ReceivedRequest>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.first.then((request) async {
        final bytes = await request.fold<List<int>>(
          <int>[],
          (previous, element) => previous..addAll(element),
        );
        final body = latin1.decode(bytes);
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
        await request.response.close();
      }),
    );

    final exitCode = await cli.runUploadSymbols([
      '--path',
      '${dsym.path}/',
      '--app-version',
      '1.2.3',
      '--platform',
      'ios',
      '--endpoint',
      'http://127.0.0.1:${server.port}',
    ], environment: {
      'FLUTTERVEIL_UPLOAD_KEY': 'test-upload-key',
    });

    final request = await received.future;
    await server.close(force: true);
    await tempDir.delete(recursive: true);

    expect(exitCode, 0);
    expect(request.body, contains('filename="Runner.app.dSYM.zip"'));
  });

  test('rejects symlinks inside dSYM before upload', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('flutterveil_symbols_cli_');
    final dsym = Directory('${tempDir.path}/Runner.app.dSYM');
    final dwarf = Directory('${dsym.path}/Contents/Resources/DWARF');
    await dwarf.create(recursive: true);
    await Link('${dwarf.path}/Runner').create('/tmp/flutterveil-secret');

    final exitCode = await cli.runUploadSymbols([
      '--path',
      dsym.path,
      '--app-version',
      '1.2.3',
      '--platform',
      'ios',
      '--endpoint',
      'http://127.0.0.1:1',
    ], environment: {
      'FLUTTERVEIL_UPLOAD_KEY': 'test-upload-key',
    });

    await tempDir.delete(recursive: true);

    expect(exitCode, cli.usageExitCode);
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
