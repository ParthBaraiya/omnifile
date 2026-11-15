/// [OmniFile] itself — the descriptor the rest of the package is built around.
///
/// One class for a file from any [OmniFileSource]. It carries *either* a path
/// or bytes, derives its name and MIME type from them once at construction
/// time, and otherwise does as little as possible: [OmniFile.size] is the only
/// member that reaches outside the object, and even that delegates to an
/// [OmniSizeLoader]. Reading the contents is deliberately not its job — hand
/// it to `OmniBytesLoader.fromFile` for that.
///
/// See `extensions.dart` for the `networkFile` / `localFile` / `assetFile` /
/// `memoryFile` shorthands that build one without naming the constructor, and
/// for `imageProvider`.
library;

import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'enums.dart';
import 'loaders/size_loader.dart';
import 'utils.dart';

/// A lightweight descriptor for a file from any [OmniFileSource].
///
/// It holds *either* a [path] or [bytes] — never neither — and derives [name]
/// and [mimeType] from them when constructed. Beyond [size] it performs no I/O
/// of its own: to read the contents, pass it to
/// `OmniBytesLoader.fromFile`.
///
/// ```dart
/// final report = 'https://example.com/q3/report.pdf'.networkFile;
/// report.name;      // 'report.pdf'
/// report.mimeType;  // 'application/pdf'
///
/// final bytes = await OmniBytesLoader.fromFile(report).load();
/// ```
///
/// The `networkFile` / `localFile` / `assetFile` / `memoryFile`
/// shorthands cover the common cases; use the constructor directly when you
/// need to supply a custom [name], an already-known size, [lastModified] or
/// [metadata].
class OmniFile {
  /// Where this file's bytes live, and therefore how every other member on
  /// this class resolves.
  final OmniFileSource source;

  /// How to locate the file: a URL for [OmniFileSource.network], an asset
  /// key for [OmniFileSource.asset], a filesystem path for
  /// [OmniFileSource.local].
  ///
  /// `null` for [OmniFileSource.memory] files, which carry [bytes]
  /// instead. At least one of [path] and [bytes] must be non-null — that is all
  /// the constructor asserts, so passing both is allowed.
  final String? path;

  /// The file's contents, when they are already in memory.
  ///
  /// Non-null for [OmniFileSource.memory] files; the other sources carry
  /// a [path] and are read on demand instead.
  final Uint8List? bytes;

  /// The MIME type guessed from the [path]'s extension when this file was
  /// constructed.
  ///
  /// Falls back to `application/octet-stream` for unknown extensions — and so
  /// also for [OmniFileSource.memory] files, which have no path to guess
  /// from. Never sniffed from the contents.
  ///
  /// Read off the raw [path] rather than off [name] or [extension], by taking
  /// everything after its last `.`. For a URL that carries a query string or
  /// fragment that trailing piece is not an extension —
  /// `report.pdf?token=abc` yields `pdf?token=abc` — so this falls back to
  /// `application/octet-stream` while [extension], which reads the parsed
  /// [name], still says `pdf`.
  final String mimeType;

  /// The file's display name, including its extension — `report.pdf`.
  ///
  /// Taken from the constructor when given, otherwise derived from [path]: the
  /// last URL path segment for [OmniFileSource.network], the basename for
  /// [OmniFileSource.asset] and [OmniFileSource.local]. `null` for
  /// [OmniFileSource.memory] files unless you name them yourself, and `null`
  /// too for a network file whose [path] will not parse as a URI.
  final String? name;

  /// Only available for [OmniFileSource.local] files.
  ///
  /// Nothing in this package populates it, so it is `null` unless you pass it
  /// in — typically from whatever produced the path (a file picker, a
  /// directory listing).
  final DateTime? lastModified;

  /// Cache for [size], seeded by the constructor and filled in on first read.
  int? _size;

  /// Anything you want to carry alongside the file — untyped, and the one
  /// mutable field on an otherwise immutable descriptor.
  ///
  /// Nothing in this package reads or writes it. Use it for whatever the thing
  /// that produced the file knows and this descriptor has no field for: the
  /// picker result it came from, an upload id, a caption. [rename] carries it
  /// over unless you pass a replacement.
  dynamic metadata;

  /// Creates a descriptor for a file from [source].
  ///
  /// Either [bytes] or [path] must be non-null. [name] defaults to a name
  /// derived from [path], and the private size parameter (passed as `size:`)
  /// pre-seeds [size] so it can answer without any I/O.
  ///
  /// Constructing an [OmniFileSource.local] file on a platform without a
  /// filesystem (web) is allowed — the descriptor itself is inert. It is
  /// *reading* one ([size], [imageProvider], `OmniBytesLoader.load`) that
  /// throws [UnsupportedPlatformException]. Check [isValid] or
  /// [OmniFileSource.isSupported] first to avoid the throw.
  OmniFile({
    this.path,
    required this.source,
    this.bytes,
    String? name,
    this._size,
    this.lastModified,
    this.metadata,
  }) : assert(
         bytes != null || (path != null),
         'bytes and path parameters can not be null at the same time.',
       ),
       name = name ?? _getName(source, path),
       mimeType = OmniFileUtils.getMimeFromExtension(
         path?.split('.').lastOrNull ?? '',
       );

  /// Returns a copy of this file called [newName].
  ///
  /// Nothing is renamed on disk or on the server — only the descriptor's
  /// [name] changes, which in turn changes [extension] and
  /// [nameWithoutExtension]. [mimeType] keeps the type derived from [path] and
  /// [lastModified] is dropped; any cached [size] is carried over.
  ///
  /// Params:
  /// - [newName] - the new [name], extension included. Giving it an extension
  ///   that disagrees with [path] changes [extension] but not [mimeType].
  /// - [newMetadata] - replaces [metadata] on the copy; omit it (or pass
  ///   `null`) to carry the current value over.
  OmniFile rename(String newName, {dynamic newMetadata}) {
    return OmniFile(
      source: source,
      name: newName,
      path: path,
      bytes: bytes,
      size: _size,
      metadata: newMetadata ?? metadata,
    );
  }

  /// Whether this descriptor is worth trying to read.
  ///
  /// `true` when [bytes] are present, or when a path-based source has a
  /// non-empty [path]; `false` when the [source] is not supported on this
  /// platform (an [OmniFileSource.local] file on web). This is a cheap
  /// structural check — it does not touch the filesystem or the network, so a
  /// valid file can still turn out to be missing or unreachable.
  bool get isValid {
    if (bytes != null) return true;
    if (!source.isSupported) return false;

    return (source.isAsset || source.isLocal || source.isNetwork) &&
        (path?.isNotEmpty ?? false);
  }

  /// The [name]'s extension, without the leading `.` — `pdf` for `report.pdf`.
  ///
  /// This is the form every [OmniFileUtils] predicate expects. A name
  /// with no `.` in it yields the whole name, and a name of `null` yields
  /// `null`. Not lowercased.
  String? get extension => name?.split('.').lastOrNull;

  /// The [name] up to its first `.` — `report` for `report.pdf`.
  ///
  /// For a name with several dots this keeps only the first segment:
  /// `archive.tar.gz` yields `archive`.
  String? get nameWithoutExtension {
    return name?.split('.').firstOrNull;
  }

  /// The file's size in bytes, or `null` if it cannot be determined.
  ///
  /// Measured by the [OmniSizeLoader] for this [source], then cached, so
  /// repeated reads are free and only the first one does any work. What each
  /// source does:
  ///
  /// - [OmniFileSource.memory] — the length of [bytes].
  /// - [OmniFileSource.asset] — loads the asset and measures it.
  /// - [OmniFileSource.network] — sends an HTTP `HEAD` request and reads
  ///   the `Content-Length` header.
  /// - [OmniFileSource.local] — stats the file on disk.
  ///
  /// The asset and network loaders swallow every failure into `null`, so a
  /// missing asset, an offline device or a server that omits `Content-Length`
  /// are indistinguishable here. [OmniLocalFileSizeLoader] is the
  /// exception: it throws [OmniFileNotFoundException] if the path does
  /// not exist, and [UnsupportedPlatformException] on web.
  ///
  /// A `null` answer is not cached, so a size that was unknowable once is
  /// tried again on the next read.
  Future<int?> get size async {
    if (_size != null) return _size;

    return _size = await OmniSizeLoader.fromFile(this).load();
  }

  /// [size] rendered for display — `1.4 MB` — or `null` if the size is
  /// unknown.
  ///
  /// See [formatFileSize] for the unit convention, which is platform
  /// dependent.
  Future<String?> get formattedSize {
    return size.then((size) {
      return size == null ? null : formatFileSize(size);
    });
  }
}

/// Derives a display name from [path], the way [source] addresses files.
String? _getName(OmniFileSource source, String? path) {
  if (path == null) return null;
  switch (source) {
    case .network:
      final uri = Uri.tryParse(path);
      if (uri == null) return null;
      return uri.path.split('/').lastOrNull;
    case .asset:
    case .local:
      return p.basename(path);
    case .memory:
      return null;
  }
}
