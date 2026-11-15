/// The switchboard for the platform abstraction — one conditional export
/// that picks the half matching the platform, for both local-file access and
/// platform detection.
///
/// Everything in the package that touches the filesystem imports this library
/// rather than either half directly, which is what keeps `dart:io` confined to
/// `local_file_io.dart` and gets `local_file_web.dart` compiled in on web.
///
/// The two halves must expose an identical API — `supportsLocalFiles`,
/// `localFileLength`, `localFileBytes`, `localFileImageProvider` and
/// `currentPlatform`. Nothing enforces that: the analyzer only ever resolves the `dart.library.io`
/// branch, so drift between them surfaces as a *web build* failure and never
/// as an analyze failure.
library;

export 'local_file_web.dart' if (dart.library.io) 'local_file_io.dart';
