import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'path_provider_stub.dart'
    if (dart.library.ui) 'package:path_provider/path_provider.dart'
    as path_provider;

typedef DirectoryProvider = Future<Directory> Function();

class EventQueue {
  EventQueue({
    DirectoryProvider? directoryProvider,
  }) : _directoryProvider =
            directoryProvider ?? path_provider.getApplicationDocumentsDirectory;

  static const String queueFileName = 'flutterveil_queue.json';

  final DirectoryProvider _directoryProvider;
  Completer<void>? _lock;

  Future<void> enqueue(Map<String, dynamic> event) {
    return _withLock(() async {
      final events = await _readEvents();
      events.add(Map<String, dynamic>.from(event));
      await _writeEvents(events);
    });
  }

  Future<void> enqueueAll(List<Map<String, dynamic>> events) {
    return _withLock(() async {
      final current = await _readEvents();
      current.addAll(events.map(Map<String, dynamic>.from));
      await _writeEvents(current);
    });
  }

  Future<List<Map<String, dynamic>>> drain() {
    return _withLock(() async {
      final events = await _readEvents();
      if (events.isNotEmpty) {
        await _writeEvents([]);
      }
      return events;
    });
  }

  Future<int> length() async {
    final events = await _readEvents();
    return events.length;
  }

  Future<T> _withLock<T>(Future<T> Function() action) async {
    while (_lock != null) {
      await _lock!.future;
    }

    final currentLock = Completer<void>();
    _lock = currentLock;

    try {
      return await action();
    } finally {
      _lock = null;
      currentLock.complete();
    }
  }

  Future<File> _queueFile() async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return File('${directory.path}/$queueFileName');
  }

  Future<List<Map<String, dynamic>>> _readEvents() async {
    final file = await _queueFile();
    if (!await file.exists()) {
      return [];
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map<Object?, Object?>>()
        .map(
          (event) => event.map(
            (k, v) => MapEntry(k.toString(), v),
          ),
        )
        .toList();
  }

  Future<void> _writeEvents(List<Map<String, dynamic>> events) async {
    final file = await _queueFile();
    final tmpFile = File('${file.path}.tmp');

    await tmpFile.writeAsString(jsonEncode(events), flush: true);
    await tmpFile.rename(file.path);
  }
}
