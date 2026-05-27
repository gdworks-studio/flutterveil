# flutterveil

## Installation

Add `flutterveil` to your app's `pubspec.yaml`:

```yaml
dependencies:
  flutterveil: ^0.1.0
```

Then fetch packages:

```bash
flutter pub get
```

## Quick Start

```dart
void main() {
  runZonedGuarded(() async {
    await FlutterVeil.init(apiKey: 'YOUR_API_KEY');
    runApp(const MyApp());
  }, (error, stack) => FlutterVeil.capture(error, stack));
}
```

## API Reference

| Method | Signature | Description |
| --- | --- | --- |
| `init` | `static Future<void> init({required String apiKey, String endpoint = 'http://localhost:8080', String appVersion = 'unknown', String buildNumber = 'unknown'})` | Starts a session, uploads queued events, and registers Flutter error handlers. |
| `capture` | `static Future<void> capture(Object error, StackTrace stack)` | Queues a crash event and starts a background upload attempt. |
| `upload` | `static Future<void> upload()` | Uploads queued events to the configured ingestion endpoint. |
| `dispose` | `static Future<void> dispose()` | Records a session end event and flushes queued events. |
