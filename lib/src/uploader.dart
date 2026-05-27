import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'event_queue.dart';

class Uploader {
  Uploader({
    EventQueue? queue,
    http.Client? httpClient,
    Duration retryDelay = const Duration(seconds: 5),
  })  : _queue = queue ?? EventQueue(),
        _httpClient = httpClient ?? http.Client(),
        _retryDelay = retryDelay;

  static const int _maxAttempts = 3;

  final EventQueue _queue;
  final http.Client _httpClient;
  final Duration _retryDelay;

  Future<void> upload({
    required String endpoint,
    required String apiKey,
  }) async {
    var events = await _queue.drain();
    if (events.isEmpty) {
      return;
    }

    for (var attempt = 1; attempt <= _maxAttempts; attempt += 1) {
      final result = await _postEvents(
        endpoint: endpoint,
        apiKey: apiKey,
        events: events,
      );

      if (result == _UploadResult.success) {
        return;
      }

      if (result == _UploadResult.rateLimited) {
        stderr.writeln(
          '[flutterveil] HTTP 429 from ingestion endpoint. '
          'Dropping ${events.length} event(s) for this upload cycle.',
        );
        return;
      }

      await _queue.enqueueAll(events);

      if (attempt == _maxAttempts) {
        return;
      }

      await Future<void>.delayed(_retryDelay);
      events = await _queue.drain();
      if (events.isEmpty) {
        return;
      }
    }
  }

  Future<_UploadResult> _postEvents({
    required String endpoint,
    required String apiKey,
    required List<Map<String, dynamic>> events,
  }) async {
    final normalizedEndpoint = endpoint.endsWith('/')
        ? endpoint.substring(0, endpoint.length - 1)
        : endpoint;

    try {
      final response = await _httpClient.post(
        Uri.parse('$normalizedEndpoint/events'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'events': events}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _UploadResult.success;
      }

      if (response.statusCode == 429) {
        return _UploadResult.rateLimited;
      }

      return _UploadResult.retryableFailure;
    } catch (_) {
      return _UploadResult.retryableFailure;
    }
  }
}

enum _UploadResult {
  success,
  rateLimited,
  retryableFailure,
}
