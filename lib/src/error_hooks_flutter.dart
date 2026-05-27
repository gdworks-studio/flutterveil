import 'package:flutter/foundation.dart';

typedef FlutterVeilErrorHandler = void Function(Object error, StackTrace stack);

void registerFlutterVeilErrorHooks(FlutterVeilErrorHandler handler) {
  final previousFlutterOnError = FlutterError.onError;

  FlutterError.onError = (FlutterErrorDetails details) {
    previousFlutterOnError?.call(details);
    handler(details.exception, details.stack ?? StackTrace.current);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    handler(error, stack);
    return false;
  };
}
