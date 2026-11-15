/// [OmniFile] — one descriptor for a file that may live at a network URL,
/// in memory, in the asset bundle, or on the local filesystem.
///
/// This is the package's single entry point: importing
/// `package:omnifile/omnifile.dart` gives you everything public. It re-exports
///
/// - [OmniFileSource], [CurrentPlatform] and [OmniFile] itself, plus the `networkFile` /
///   `localFile` / `assetFile` / `memoryFile` shorthands that build one and
///   [OmniFileImageProviderExt.imageProvider] for handing one to an `Image`
///   widget;
/// - [OmniBytesLoader] and its per-source subclasses, which read the bytes —
///   reading is deliberately not the descriptor's job;
/// - [OmniSizeLoader] and its per-source subclasses, the measuring that backs
///   [OmniFile.size];
/// - [OmniFileExtensions] and [extensionToMimeType] (the extension constants,
///   per-platform lists and MIME map), plus [OmniFileUtils] and
///   [formatFileSize] for the extension and MIME-type helpers;
/// - [OmniFileException] and its subtypes, all `dart:io`-free so the same
///   `catch` compiles on web and native;
/// - [supportsLocalFiles] and [currentPlatform], which answer whether this
///   platform has a filesystem at all and which platform that is.
library;

export 'src/constants.dart';
export 'src/enums.dart';
export 'src/exceptions.dart';
export 'src/extensions.dart';
export 'src/loaders/data_loader.dart';
export 'src/loaders/size_loader.dart';
export 'src/local_file/local_file.dart';
export 'src/omnifile.dart';
export 'src/utils.dart';
