import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutterveil/flutterveil.dart';

Future<void> main() async {
  // Canonical 3-handler pattern — catches every uncaught Dart and Flutter error.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initializes session tracking, queues, and PlatformDispatcher.onError.
    await FlutterVeil.init(apiKey: 'YOUR_API_KEY');

    // Flutter framework errors (widget build, render, layout).
    // Wire here — the SDK doesn't depend on package:flutter so it can't auto-register this.
    FlutterError.onError = (details) {
      FlutterVeil.capture(details.exception, details.stack ?? StackTrace.current);
    };

    runApp(const FlutterVeilExampleApp());
  }, (Object error, StackTrace stack) {
    // Catches zone errors — sync exceptions in init, isolate spawn errors,
    // anything the other two handlers miss.
    FlutterVeil.capture(error, stack);
  });
}

class FlutterVeilExampleApp extends StatelessWidget {
  const FlutterVeilExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('flutterveil example'),
        ),
      ),
    );
  }
}
