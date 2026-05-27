# flutterveil

Flutter crash monitoring SDK. Three-line install, zero Firebase dependency, indie-priced hosted backend.

## Installation

Add `flutterveil` to your app's `pubspec.yaml`:

```yaml
dependencies:
  flutterveil: ^0.1.0
```

Then:

```bash
flutter pub get
```

## Quick Start

The complete pattern wires three handlers — together they catch every uncaught Dart and Flutter error:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutterveil/flutterveil.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Init — also registers PlatformDispatcher.onError for async errors
    await FlutterVeil.init(apiKey: 'YOUR_API_KEY');

    // 2. Flutter framework errors (widget build, render, layout)
    FlutterError.onError = (details) {
      FlutterVeil.capture(details.exception, details.stack ?? StackTrace.current);
    };

    runApp(const MyApp());
  }, (error, stack) {
    // 3. Zone errors — sync exceptions in init, isolate spawn errors, anything else
    FlutterVeil.capture(error, stack);
  });
}
```

If you skip handlers 2 and 3 you'll miss ~30–40% of real-world crashes (framework errors, sync errors in init). Always wire all three.

## What gets captured

| Handler | Catches |
|---|---|
| `PlatformDispatcher.onError` (auto via `init()`) | Async errors that reach the Dart engine — unhandled futures, errors in zones without their own handler |
| `FlutterError.onError` (manual) | Widget build errors, render exceptions, layout overflows, anything thrown inside Flutter's framework |
| `runZonedGuarded` callback (manual) | Sync errors during init, errors in isolates spawned without an error listener, anything outside Flutter's pipeline |

Not captured (yet):
- Native crashes in iOS Swift / Android Kotlin / C++ via FFI — planned for v2
- `print()` / `debugPrint()` output — those aren't exceptions
- Errors you `try/catch` and handle yourself

## Manual capture

For caught exceptions you still want to report:

```dart
try {
  await riskyOperation();
} catch (e, stack) {
  FlutterVeil.capture(e, stack);
  // ... handle the error in your UI
}
```

## API Reference

| Method | Signature | Description |
| --- | --- | --- |
| `init` | `static Future<void> init({required String apiKey, String endpoint = 'http://localhost:8080', String appVersion = 'unknown', String buildNumber = 'unknown'})` | Starts a session, uploads queued events, and registers `PlatformDispatcher.onError`. |
| `capture` | `static Future<void> capture(Object error, StackTrace stack)` | Queues a crash event and starts a background upload attempt. |
| `upload` | `static Future<void> upload()` | Manually triggers an upload of queued events. Normally automatic. |
| `dispose` | `static Future<void> dispose()` | Records a session end event and flushes queued events. Call when your app is shutting down cleanly. |

## Configuration

`endpoint` defaults to `http://localhost:8080` for local development. Point it at your production ingestion service:

```dart
await FlutterVeil.init(
  apiKey: 'YOUR_API_KEY',
  endpoint: 'https://ingest.flutterveil.io',
  appVersion: '1.0.0',
  buildNumber: '1',
);
```

## License

MIT
