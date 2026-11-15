/// The extensions that make an [OmniFile] ergonomic to build and to display.
///
/// Three of them, all thin: [OmniFilePathStringExt] reads a `String` as a URL,
/// filesystem path or asset key, [OmniFileBytesExt] wraps a [Uint8List] that
/// is already in memory, and [OmniFileImageProviderExt] maps a file onto the
/// [ImageProvider] for its source.
///
/// The four building getters return a non-nullable [OmniFile], so there is
/// nothing to unwrap. `imageProvider` is the one that can be `null`: it returns
/// `null` for formats Flutter has no decoder for, rather than failing at paint
/// time.
library;

import 'dart:typed_data';

import 'package:flutter/painting.dart';

import 'local_file/local_file.dart';
import 'omnifile.dart';
import 'utils.dart';

/// Builds an [OmniFile] out of a URL, asset key or filesystem path.
extension OmniFilePathStringExt on String {
  /// Treats this string as a URL to fetch over HTTP.
  OmniFile get networkFile => OmniFile(source: .network, path: this);

  /// Treats this string as a path on the device's filesystem.
  ///
  /// Fine to call on web — the descriptor is inert there, and only reading it
  /// throws [UnsupportedPlatformException].
  OmniFile get localFile => OmniFile(source: .local, path: this);

  /// Treats this string as an asset key, as declared in `pubspec.yaml`.
  OmniFile get assetFile => OmniFile(source: .asset, path: this);
}

/// Builds an [OmniFile] out of bytes that are already in memory.
extension OmniFileBytesExt on Uint8List {
  /// Wraps these bytes as an [OmniFileSource.memory] file.
  ///
  /// The result has no [OmniFile.name] and a `application/octet-stream`
  /// MIME type, since there is no path to derive either from; use
  /// [OmniFile.rename] to give it a name.
  OmniFile get memoryFile => OmniFile(source: .memory, bytes: this);
}

/// Turns an [OmniFile] into the Flutter [ImageProvider] for its source.
extension OmniFileImageProviderExt on OmniFile {
  /// An [ImageProvider] that renders this file, or `null` if Flutter cannot
  /// display it.
  ///
  /// Maps each source onto its provider: [MemoryImage], [AssetImage],
  /// [NetworkImage], or a `FileImage` for local files. Returns `null` unless
  /// [OmniFileUtils.canPreviewImageByDefault] accepts the extension, so
  /// formats Flutter has no decoder for (SVG, HEIC off iOS, …) opt out rather
  /// than failing at paint time.
  ///
  /// Throws [UnsupportedPlatformException] for a local file on web.
  ImageProvider<Object>? get imageProvider {
    if (!OmniFileUtils.canPreviewImageByDefault(extension)) {
      return null;
    }

    if (source.isMemory) {
      return MemoryImage(bytes!);
    } else if (source.isAsset) {
      return AssetImage(path!);
    } else if (source.isNetwork) {
      return NetworkImage(path!);
    } else if (source.isLocal) {
      return localFileImageProvider(path!);
    } else {
      return null;
    }
  }
}
