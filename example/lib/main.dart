import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutterveil/flutterveil.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await FlutterVeil.init(apiKey: 'YOUR_API_KEY');
    runApp(const FlutterVeilExampleApp());
  }, (Object error, StackTrace stack) => FlutterVeil.capture(error, stack));
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
