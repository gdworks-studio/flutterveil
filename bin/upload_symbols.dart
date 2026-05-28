import 'dart:io';

import 'package:http/http.dart' as http;

const int usageExitCode = 64;

Future<void> main(List<String> args) async {
  final exitCode = await runUploadSymbols(args);
  if (exitCode != 0) {
    exit(exitCode);
  }
}

Future<int> runUploadSymbols(
  List<String> args, {
  http.Client? client,
}) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage);
    return 0;
  }

  late final _UploadConfig config;
  try {
    config = await _parseConfig(args);
  } on FormatException catch (error) {
    stderr.writeln('[flutterveil] ${error.message}');
    stderr.writeln(_usage);
    return usageExitCode;
  }

  final ownsClient = client == null;
  final httpClient = client ?? http.Client();
  try {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${config.endpoint}/v1/symbol-files'),
    )
      ..headers[HttpHeaders.authorizationHeader] = 'Bearer ${config.apiKey}'
      ..fields['app_version'] = config.appVersion
      ..fields['platform'] = config.platform
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          config.file.path,
          filename: _basename(config.file.path),
        ),
      );

    final response = await httpClient.send(request);
    await response.stream.drain<void>();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      stdout
          .writeln('[flutterveil] Uploaded symbols for ${config.appVersion}.');
      return 0;
    }

    stderr.writeln(
      '[flutterveil] Symbol upload failed with HTTP ${response.statusCode}.',
    );
    return 1;
  } on SocketException catch (error) {
    stderr.writeln(
        '[flutterveil] Network error while uploading symbols: ${error.message}');
    return 1;
  } finally {
    if (config.temporaryDirectory != null &&
        await config.temporaryDirectory!.exists()) {
      await config.temporaryDirectory!.delete(recursive: true);
    }
    if (ownsClient) {
      httpClient.close();
    }
  }
}

String normalizeEndpoint(String endpoint) {
  final trimmed = endpoint.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw const FormatException('Endpoint must be an absolute URL.');
  }
  if (uri.hasQuery || uri.hasFragment) {
    throw const FormatException(
        'Endpoint must not include a query or fragment.');
  }

  final host = uri.host.toLowerCase();
  final isLocalhost =
      host == 'localhost' || host == '127.0.0.1' || host == '::1';
  if (uri.scheme != 'https' && !(uri.scheme == 'http' && isLocalhost)) {
    throw const FormatException(
      'Endpoint must use HTTPS, except localhost development endpoints.',
    );
  }

  final normalizedPath = uri.path.endsWith('/') && uri.path.length > 1
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  return uri
      .replace(path: normalizedPath)
      .toString()
      .replaceFirst(RegExp(r'/$'), '');
}

Future<_UploadConfig> _parseConfig(List<String> args) async {
  final flags = _parseFlags(args);
  final path = flags['path'];
  final apiKey = flags['api-key'];
  final appVersion = flags['app-version'];
  final platform = flags['platform'];
  final endpoint = flags['endpoint'];

  if (path == null || path.trim().isEmpty) {
    throw const FormatException('Missing required --path.');
  }
  if (apiKey == null || apiKey.trim().isEmpty) {
    throw const FormatException('Missing required --api-key.');
  }
  if (appVersion == null || appVersion.trim().isEmpty) {
    throw const FormatException('Missing required --app-version.');
  }
  if (platform == null || (platform != 'ios' && platform != 'android')) {
    throw const FormatException('--platform must be ios or android.');
  }
  if (endpoint == null || endpoint.trim().isEmpty) {
    throw const FormatException('Missing required --endpoint.');
  }

  final selected = await _selectSymbolFile(path, platform);
  return _UploadConfig(
    file: selected.file,
    temporaryDirectory: selected.temporaryDirectory,
    apiKey: apiKey.trim(),
    appVersion: appVersion.trim(),
    platform: platform,
    endpoint: normalizeEndpoint(endpoint),
  );
}

Map<String, String> _parseFlags(List<String> args) {
  final flags = <String, String>{};
  var index = 0;
  while (index < args.length) {
    final token = args[index];
    if (!token.startsWith('--')) {
      throw FormatException('Unexpected argument: $token');
    }
    final name = token.substring(2);
    if (name.isEmpty) {
      throw const FormatException('Invalid empty flag.');
    }
    if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
      throw FormatException('Missing value for --$name.');
    }
    flags[name] = args[index + 1];
    index += 2;
  }
  return flags;
}

Future<_SelectedFile> _selectSymbolFile(
    String inputPath, String platform) async {
  final type = await FileSystemEntity.type(inputPath, followLinks: false);
  if (type == FileSystemEntityType.notFound) {
    throw FormatException('Symbol path does not exist: $inputPath');
  }
  if (type == FileSystemEntityType.file) {
    return _SelectedFile(File(inputPath));
  }

  final directory = Directory(inputPath);
  if (platform == 'android') {
    final mapping = await _findFirstFile(directory, 'mapping.txt');
    if (mapping == null) {
      throw const FormatException(
          'Android symbol path must contain mapping.txt.');
    }
    return _SelectedFile(mapping);
  }

  if (inputPath.endsWith('.dSYM')) {
    return _zipDsymDirectory(directory);
  }

  final zip = await _findFirstFile(directory, null, extension: '.zip');
  if (zip == null) {
    throw const FormatException(
        'iOS symbol path must be a .dSYM directory or .zip file.');
  }
  return _SelectedFile(zip);
}

Future<File?> _findFirstFile(
  Directory directory,
  String? basename, {
  String? extension,
}) async {
  await for (final entity
      in directory.list(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final name = _basename(entity.path);
    if (basename != null && name == basename) {
      return entity;
    }
    if (extension != null && name.endsWith(extension)) {
      return entity;
    }
  }
  return null;
}

Future<_SelectedFile> _zipDsymDirectory(Directory directory) async {
  final tempDir = await Directory.systemTemp.createTemp('flutterveil_dsym_');
  final zipFile = File('${tempDir.path}/${_basename(directory.path)}.zip');
  final parentPath = directory.parent.path;
  final result = await Process.run(
    'zip',
    ['-qry', zipFile.path, _basename(directory.path)],
    workingDirectory: parentPath,
  );
  if (result.exitCode != 0) {
    throw const FormatException('Unable to zip .dSYM directory.');
  }
  return _SelectedFile(zipFile, temporaryDirectory: tempDir);
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

const String _usage = '''
Usage:
  dart run flutterveil:upload_symbols --path <path> --api-key <key> --app-version <version> --platform <ios|android> --endpoint <url>
''';

class _UploadConfig {
  const _UploadConfig({
    required this.file,
    required this.temporaryDirectory,
    required this.apiKey,
    required this.appVersion,
    required this.platform,
    required this.endpoint,
  });

  final File file;
  final Directory? temporaryDirectory;
  final String apiKey;
  final String appVersion;
  final String platform;
  final String endpoint;
}

class _SelectedFile {
  const _SelectedFile(this.file, {this.temporaryDirectory});

  final File file;
  final Directory? temporaryDirectory;
}
