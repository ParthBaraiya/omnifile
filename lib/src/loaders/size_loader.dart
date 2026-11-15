/// The loaders that answer how big an [OmniFile] is.
///
/// [OmniSizeLoader] is the shared interface, with one implementation per
/// [OmniFileSource]. Call [OmniSizeLoader.fromFile] and let it pick;
/// the concrete classes are public mostly so they can be named in tests and
/// type annotations.
///
/// This is what backs [OmniFile.size]. The difference is caching: these
/// loaders are stateless and go out and measure the file on every [load] call,
/// while [OmniFile.size] remembers the first answer. Reach for a loader
/// directly when you want a fresh measurement, or when you want to talk about
/// "the thing that measures a file" without holding a descriptor's cache.
library;

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:omnifile/omnifile.dart';

/// Measures the size of an [OmniFile], whichever source it came from.
///
/// ```dart
/// final loader = OmniSizeLoader.fromFile(file);
/// final size = await loader.load();
/// ```
///
/// Use [fromFile] rather than picking a subclass by hand: each subclass
/// re-checks `file.source` and throws if it was handed a file it cannot
/// measure.
///
/// Every implementation returns `null` rather than throwing when the size
/// simply cannot be established — an empty path, a server that omits
/// `Content-Length`. [OmniLocalFileSizeLoader] is the exception, and
/// throws for a missing file or an absent filesystem.
abstract class OmniSizeLoader {
  /// The file this loader measures.
  final OmniFile file;

  /// Binds a loader to [file]; prefer [fromFile], which picks the right
  /// subclass for you.
  const OmniSizeLoader(this.file);

  /// The file's size in bytes, or `null` if it cannot be determined.
  ///
  /// Which failures become `null` depends on the source: the network and asset
  /// loaders swallow every failure, while [OmniLocalFileSizeLoader] throws for
  /// a missing file or an absent filesystem. See the library header and each
  /// subclass for the details.
  ///
  /// Nothing is cached here: each call measures the file again.
  Future<int?> load();

  /// [load] rendered for display — `1.4 MB` — or `null` if the size is
  /// unknown.
  ///
  /// See [formatFileSize] for the unit convention, which is platform
  /// dependent.
  Future<String?> loadFormatted() {
    return load().then((size) => size == null ? null : formatFileSize(size));
  }

  /// Returns the loader that can measure [file], chosen by its
  /// [OmniFile.source].
  static OmniSizeLoader fromFile(OmniFile file) {
    return switch (file.source) {
      .network => OmniNetworkSizeLoader(file),
      .memory => OmniMemorySizeLoader(file),
      .asset => OmniAssetSizeLoader(file),
      .local => OmniLocalFileSizeLoader(file),
    };
  }
}

/// Asks an HTTP server how big the file at [OmniFile.path] is.
///
/// Sends a `HEAD` request and reads the `Content-Length` header, so the body
/// is never downloaded. Plenty of servers do not answer that question —
/// chunked responses, dynamic endpoints, a proxy that strips the header — and
/// every one of those cases comes back as `null`.
class OmniNetworkSizeLoader extends OmniSizeLoader {
  /// Binds this loader to an [OmniFileSource.network] file.
  const OmniNetworkSizeLoader(super.file);

  /// Reads `Content-Length` off a `HEAD` response.
  ///
  /// Returns `null` for anything short of a 200 carrying a numeric
  /// `Content-Length`, and swallows transport failures into `null` too — an
  /// offline device and a header-less server are indistinguishable from here.
  @override
  Future<int?> load() async {
    if (file.source != .network) {
      throw Exception("File source is not network");
    }

    try {
      if (file.path == null) return null;

      // Send a HEAD request to the server to get file metadata
      final response = await http.head(Uri.parse(file.path!));

      // Check if the response is successful
      if (response.statusCode != 200) return null;

      // Extract the file size from the Content-Length header
      final contentLength = response.headers['content-length'];

      return contentLength == null ? null : int.tryParse(contentLength);
    } catch (e) {
      return null;
    }
  }
}

/// Measures a file on the local filesystem by stat-ing it.
///
/// The one loader that throws instead of returning `null`: an
/// [UnsupportedPlatformException] on web, where there is no filesystem, and an
/// [OmniFileNotFoundException] when the path does not exist. An empty or
/// absent [OmniFile.path] still yields `null`, without touching the disk.
class OmniLocalFileSizeLoader extends OmniSizeLoader {
  /// Binds this loader to an [OmniFileSource.local] file.
  const OmniLocalFileSizeLoader(super.file);

  /// Stats the file on disk.
  @override
  Future<int?> load() async {
    if (file.source != .local) {
      throw Exception("File source is not local");
    }

    if (file.path?.isEmpty ?? true) return null;

    return localFileLength(file.path!);
  }
}

/// Measures the bytes an [OmniFileSource.memory] file already carries.
///
/// Nothing is read; this is [Uint8List.lengthInBytes] behind the same
/// interface as the rest, and the only loader with no failure mode of its own.
class OmniMemorySizeLoader extends OmniSizeLoader {
  /// Binds this loader to an [OmniFileSource.memory] file.
  const OmniMemorySizeLoader(super.file);

  /// Completes immediately with the length of [OmniFile.bytes], or `null` if
  /// there are none — a memory file built with only a [OmniFile.path] satisfies
  /// the constructor but has nothing to measure.
  @override
  Future<int?> load() async {
    if (file.source != .memory) {
      throw Exception("File source is not memory");
    }

    return file.bytes?.lengthInBytes;
  }
}

/// Measures an asset bundled with the app, through Flutter's [rootBundle].
///
/// The bundle has no size-only API, so this loads the whole asset into memory
/// and measures it — the same cost as reading it. Prefer a pre-seeded size on
/// the descriptor if you are only after the number for a large asset.
class OmniAssetSizeLoader extends OmniSizeLoader {
  /// Binds this loader to an [OmniFileSource.asset] file.
  const OmniAssetSizeLoader(super.file);

  /// Loads the asset out of the bundle and returns its length.
  ///
  /// Returns `null` if the key is not in the bundle, rather than letting the
  /// [FlutterError] out.
  @override
  Future<int?> load() async {
    if (file.source != .asset) {
      throw Exception("File source is not asset");
    }

    try {
      if (file.path == null) return null;

      final data = await rootBundle.load(file.path!);

      return data.lengthInBytes;
    } catch (e) {
      return null;
    }
  }
}
