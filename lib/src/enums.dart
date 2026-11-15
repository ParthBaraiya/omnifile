/// [OmniFileSource] and [CurrentPlatform] — the two enums the rest of the
/// package switches on.
///
/// [OmniFileSource] names the four places a file's bytes can live; it decides
/// how a name is derived from a path, which loader reads or measures the file,
/// and which Flutter image provider can display it. Three of the four work
/// everywhere; only [OmniFileSource.local] needs a real filesystem, which is
/// what [OmniFileSource.isSupported] answers.
///
/// [CurrentPlatform] names the platform the code is running on, as reported by
/// `dart:io` natively and fixed to [CurrentPlatform.web] on web.
///
/// Adding an [OmniFileSource] value means extending every exhaustive switch
/// over it and the `if`-chains that are not exhaustive — the analyzer catches
/// the former only.
library;

import 'local_file/local_file.dart';

/// Where the bytes of an [OmniFile] actually live.
///
/// Every [OmniFile] carries exactly one source, and it is the source that
/// decides how the file's name, size, bytes and image provider are resolved.
/// All four work on every platform except [local], which needs a real
/// filesystem — see [isSupported].
enum OmniFileSource {
  /// A remote file addressed by a URL and fetched over HTTP.
  ///
  /// [OmniFile.path] holds the URL, and [OmniFile.name] is the last
  /// segment of that URL's path. This is the only source with real streaming
  /// support.
  network,

  /// A file whose contents are already in memory as bytes.
  ///
  /// Carries [OmniFile.bytes] instead of a path, and so has no name of
  /// its own unless one is passed to the constructor.
  memory,

  /// A file bundled with the app and read through Flutter's asset bundle.
  ///
  /// [OmniFile.path] is an asset key such as `assets/images/logo.png`,
  /// declared in the `pubspec.yaml` of whichever package ships it.
  asset,

  /// A file on the device's own filesystem.
  ///
  /// [OmniFile.path] is a filesystem path. This is the one
  /// platform-dependent source; see [isSupported].
  local;

  /// Whether this is [network].
  bool get isNetwork => this == .network;

  /// Whether this is [memory].
  bool get isMemory => this == .memory;

  /// Whether this is [asset].
  bool get isAsset => this == .asset;

  /// Whether this is [local].
  bool get isLocal => this == .local;

  /// Whether files from this source can be read on the current platform.
  ///
  /// Only [local] is platform dependent: it needs a filesystem, which the web
  /// does not have. Reading a [local] file when this is `false` throws an
  /// [UnsupportedPlatformException].
  bool get isSupported => !isLocal || supportsLocalFiles;
}

/// The platform this code is running on.
///
/// Exposed as the top-level [currentPlatform]. Unlike Flutter's
/// `defaultTargetPlatform` it is not overridable in tests and does not follow
/// `debugDefaultTargetPlatformOverride`: natively it is the real host OS, and
/// on web it is always [web] — never the browser's host OS.
enum CurrentPlatform {
  /// A native platform this package has no name for.
  none,

  /// Android.
  android,

  /// iOS.
  ios,

  /// Fuchsia.
  fuchsia,

  /// Linux.
  linux,

  /// macOS.
  macos,

  /// Windows.
  windows,

  /// Any browser, whatever its host OS. `dart:io` is unavailable there, so
  /// this is never produced by [CurrentPlatform.fromOS].
  web;

  /// Maps a `dart:io` `Platform.operatingSystem` string onto its value, or
  /// [none] for an operating system with no entry.
  factory CurrentPlatform.fromOS(String os) {
    return switch (os) {
      "android" => .android,
      "fuchsia" => .fuchsia,
      "ios" => .ios,
      "linux" => .linux,
      "macos" => .macos,
      "windows" => .windows,
      _ => .none,
    };
  }
}
