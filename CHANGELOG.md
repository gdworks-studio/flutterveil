# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] — 2026-05-30 — Security hardening

### Security

- **HTTPS enforced for uploads.** `FlutterVeil.init` now refuses to upload crash
  data to a non-HTTPS endpoint (localhost exempt for local dev) — previously a
  misconfigured `http://` endpoint would send the API key and crash payload in
  cleartext. Uploads are disabled with a clear stderr warning instead. Mirrors
  the existing HTTPS enforcement in the `upload_symbols` CLI.
- **Offline queue is bounded.** The on-disk event queue is now capped at
  `EventQueue.maxQueuedEvents` (1000), dropping the oldest events first. Prevents
  unbounded disk growth during long offline periods and keeps a full drain within
  the backend's per-batch limit.

## [0.2.0] — 2026-05-29 — Week 5: symbol-upload CLI

### Added

- `bin/upload_symbols.dart` — `dart run flutterveil:upload_symbols` CLI for uploading dSYM (iOS) / ProGuard mapping (Android) to the symbolication endpoint.
- Reads the upload key from `FLUTTERVEIL_UPLOAD_KEY` env var or stdin — **never from `--api-key` argv** (avoids leaking the secret into process list / shell history).
- Zips a `.dSYM` directory for upload (skips symlinks, cleans up the temp archive); enforces HTTPS endpoints except localhost.
- Uses the project's separate `symbol_upload_key`, not the ingestion API key.

## [0.1.1] — 2026-05-29

### Fixed

- Changed SDK session event names from `start` / `end` to `session_start` / `session_end` to match the backend ingestion contract.

## [0.1.0] — 2026-05-28

Initial release.

### Added

- Dart SDK (`flutterveil` package) with three-line install pattern
- `FlutterVeil.init({ apiKey, endpoint, appVersion, buildNumber })` — initializes session tracking, drains queued events, registers `PlatformDispatcher.onError` for async error capture
- `FlutterVeil.capture(error, stack)` — explicit capture for caught exceptions
- `FlutterVeil.upload()` — manual upload trigger (normally automatic)
- `FlutterVeil.dispose()` — graceful shutdown with session end event
- Session tracking via UUID v4 generated with `dart:math Random.secure()` — no `uuid` package dependency
- Offline event queue using `path_provider` + atomic JSON file write (tmp-rename pattern) — no SQLite dependency
- Upload retry: up to 3 attempts with configurable delay; HTTP 429 events discarded (not re-queued) to respect free-tier limits
- Conditional import via `if (dart.library.ui)` for error hooks — package compiles and runs in pure-Dart test contexts without a Flutter binding

### Documentation

- Canonical 3-handler pattern in `example/lib/main.dart` and `README.md`: `PlatformDispatcher.onError` (auto), `FlutterError.onError` (manual), `runZonedGuarded` callback (manual)
- README explains what each handler catches and what is *not* captured (native crashes, `print()`, caught exceptions)

### Notes

- SDK is a Flutter package (depends on `flutter` + `path_provider`); the `if (dart.library.ui)` conditional-import + stub design keeps the library compilable and unit-testable in pure-Dart contexts without a Flutter binding
- `FlutterError.onError` requires one-line manual wiring in user's `main()` (documented in README)
- Native crash capture (iOS Swift / Android Kotlin / C++ via FFI) is intentionally not in v0.1; planned for v2

[Unreleased]: https://github.com/gdworks/flutterveil/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/gdworks/flutterveil/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/gdworks/flutterveil/releases/tag/v0.1.0
