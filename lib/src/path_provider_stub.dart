import 'dart:io';

Future<Directory> getApplicationDocumentsDirectory() {
  throw UnsupportedError(
    'EventQueue requires path_provider on Flutter platforms. '
    'Pass directoryProvider when running pure Dart tests.',
  );
}
