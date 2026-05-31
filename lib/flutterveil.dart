/// flutterveil — a Firebase-free Flutter crash-monitoring SDK with on-device
/// offline queueing.
///
/// Call [FlutterVeil.init] once in `main()` with your project API key and
/// ingestion endpoint. Uncaught Flutter errors are then captured automatically,
/// queued on-device, and uploaded over HTTPS (with retries when offline).
library;

export 'src/crash_reporter.dart';
export 'src/models.dart';
