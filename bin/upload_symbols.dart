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
  Map<String, String>? environment,
  Future<String?> Function()? readStdinLine,
}) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage);
    return 0;
  }

  late final _UploadConfig config;
  try {
    config = await _parseConfig(
      args,
      environment: environment ?? Platform.environment,
      readStdinLine: readStdinLine ?? () async => stdin.readLineSync(),
    );
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
      ..headers[HttpHeaders.authorizationHeader] = 'Bearer ${config.uploadKey}'
      ..fields['app_version'] = config.appVersion
      ..fields['platform'] = config.platform
      ..fields.addAll(config.buildNumber.isEmpty
          ? const <String, String>{}
          : {'build_number': config.buildNumber})
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
  if (uri.userInfo.isNotEmpty) {
    throw const FormatException('Endpoint must not include userinfo.');
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

Future<_UploadConfig> _parseConfig(
  List<String> args, {
  required Map<String, String> environment,
  required Future<String?> Function() readStdinLine,
}) async {
  final flags = _parseFlags(args);
  final path = flags['path'];
  final appVersion = flags['app-version'];
  final buildNumber = flags['build-number'];
  final platform = flags['platform'];
  final endpoint = flags['endpoint'];

  if (path == null || path.trim().isEmpty) {
    throw const FormatException('Missing required --path.');
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

  final normalizedEndpoint = normalizeEndpoint(endpoint);
  final uploadKey = await _resolveUploadKey(flags, environment, readStdinLine);
  final selected = await _selectSymbolFile(path, platform);
  return _UploadConfig(
    file: selected.file,
    temporaryDirectory: selected.temporaryDirectory,
    uploadKey: uploadKey,
    appVersion: appVersion.trim(),
    buildNumber: buildNumber?.trim() ?? '',
    platform: platform,
    endpoint: normalizedEndpoint,
  );
}

Map<String, String> _parseFlags(List<String> args) {
  const valueFlags = {
    'path',
    'app-version',
    'build-number',
    'platform',
    'endpoint',
  };
  const switchFlags = {'upload-key-stdin'};
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
    if (name == 'api-key') {
      throw const FormatException(
        '--api-key has been removed. Use FLUTTERVEIL_UPLOAD_KEY or --upload-key-stdin.',
      );
    }
    if (flags.containsKey(name)) {
      throw FormatException('Duplicate flag --$name.');
    }
    if (switchFlags.contains(name)) {
      flags[name] = 'true';
      index += 1;
      continue;
    }
    if (!valueFlags.contains(name)) {
      throw FormatException('Unknown flag --$name.');
    }
    if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
      throw FormatException('Missing value for --$name.');
    }
    flags[name] = args[index + 1];
    index += 2;
  }
  return flags;
}

Future<String> _resolveUploadKey(
  Map<String, String> flags,
  Map<String, String> environment,
  Future<String?> Function() readStdinLine,
) async {
  final envKey = environment['FLUTTERVEIL_UPLOAD_KEY']?.trim();
  if (flags.containsKey('upload-key-stdin')) {
    if (envKey != null && envKey.isNotEmpty) {
      throw const FormatException(
        'Use either FLUTTERVEIL_UPLOAD_KEY or --upload-key-stdin, not both.',
      );
    }
    final stdinKey = (await readStdinLine())?.trim();
    if (stdinKey == null || stdinKey.isEmpty) {
      throw const FormatException('Missing upload key on stdin.');
    }
    return stdinKey;
  }
  if (envKey != null && envKey.isNotEmpty) {
    return envKey;
  }
  throw const FormatException(
    'Missing upload key. Set FLUTTERVEIL_UPLOAD_KEY or pass --upload-key-stdin.',
  );
}

Future<_SelectedFile> _selectSymbolFile(
    String inputPath, String platform) async {
  final type = await FileSystemEntity.type(inputPath, followLinks: false);
  if (type == FileSystemEntityType.notFound) {
    throw FormatException('Symbol path does not exist: $inputPath');
  }
  if (type == FileSystemEntityType.link) {
    throw FormatException('Symbol path must not be a symlink: $inputPath');
  }
  final normalizedInputPath = _stripTrailingSeparators(inputPath);
  if (type == FileSystemEntityType.file) {
    return _SelectedFile(File(normalizedInputPath));
  }

  final directory = Directory(normalizedInputPath);
  if (platform == 'android') {
    final mapping = await _findFirstFile(directory, 'mapping.txt');
    if (mapping == null) {
      throw const FormatException(
          'Android symbol path must contain mapping.txt.');
    }
    return _SelectedFile(mapping);
  }

  if (_basename(normalizedInputPath).endsWith('.dSYM')) {
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
  await _rejectSymlinks(directory);
  final tempDir = await Directory.systemTemp.createTemp('flutterveil_dsym_');
  var keepTempDir = false;
  try {
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
    keepTempDir = true;
    return _SelectedFile(zipFile, temporaryDirectory: tempDir);
  } finally {
    if (!keepTempDir && await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

String _stripTrailingSeparators(String path) {
  var normalized = path;
  while (normalized.length > 1 &&
      (normalized.endsWith('/') || normalized.endsWith('\\'))) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

Future<void> _rejectSymlinks(Directory directory) async {
  await for (final entity
      in directory.list(recursive: true, followLinks: false)) {
    if (entity is Link) {
      throw FormatException(
        '.dSYM directory must not contain symlinks: ${entity.path}',
      );
    }
  }
}

const String _usage = '''
Usage:
  dart run flutterveil:upload_symbols --path <path> --app-version <version> [--build-number <build>] --platform <ios|android> --endpoint <url>

Set FLUTTERVEIL_UPLOAD_KEY or pass --upload-key-stdin.
''';

class _UploadConfig {
  const _UploadConfig({
    required this.file,
    required this.temporaryDirectory,
    required this.uploadKey,
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.endpoint,
  });

  final File file;
  final Directory? temporaryDirectory;
  final String uploadKey;
  final String appVersion;
  final String buildNumber;
  final String platform;
  final String endpoint;
}

class _SelectedFile {
  const _SelectedFile(this.file, {this.temporaryDirectory});

  final File file;
  final Directory? temporaryDirectory;
}
