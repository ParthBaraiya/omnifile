/// Extension, MIME-type and file-size helpers — pure data and predicates, no
/// I/O.
///
/// [OmniFileUtils] answers "what kind of file is this?" by matching an
/// extension against the lists in `constants.dart`, where
/// [OmniFileExtensions] and [extensionToMimeType] live, and [formatFileSize]
/// renders a byte count for display.
///
/// Every extension is written **without** the leading `.` and in lowercase. [OmniFile.extension] gives you the dot-less form but does not
/// lowercase it, which is fine: the predicates lowercase their argument
/// themselves ([OmniFileUtils.isSVG] excepted).
library;

import 'package:omnifile/omnifile.dart';

/// Predicates that classify a file by its extension.
///
/// All of these take the extension without its leading `.` — `png`, not
/// `.png` — and lowercase it themselves ([isSVG] excepted). Nothing here reads
/// the file, so the answers are only as trustworthy as the file's name.
abstract class OmniFileUtils {
  /// The MIME type registered for [extension], or `application/octet-stream`
  /// if there is none.
  ///
  /// This is what fills [OmniFile.mimeType].
  ///
  /// Params:
  /// - [extension] - file extension without `.`.
  static String getMimeFromExtension(String extension) {
    return extensionToMimeType[extension.toLowerCase()] ??
        "application/octet-stream";
  }

  /// Whether [extension] belongs to an image format.
  ///
  /// Covers vector and camera formats too ([OmniFileExtensions.svg],
  /// [OmniFileExtensions.heic], [OmniFileExtensions.avif], …), most
  /// of which Flutter cannot decode on its own — see
  /// [canPreviewImageByDefault] for that narrower question. `false` for
  /// `null`.
  ///
  /// Not every image-ish extension in [OmniFileExtensions] is in this set:
  /// [OmniFileExtensions.tiff], [OmniFileExtensions.psd],
  /// [OmniFileExtensions.ai] and [OmniFileExtensions.raw] have constants and
  /// MIME types but return `false` here.
  ///
  /// Params:
  /// - [extension] - file extension without `.`.
  static bool isImage(String? extension) {
    if (extension == null) return false;
    return OmniFileExtensions.imageExtensions.contains(extension.toLowerCase());
  }

  /// Whether [extension] is [OmniFileExtensions.svg].
  ///
  /// Case sensitive, unlike the rest of these predicates: pass an
  /// already-lowercased extension.
  ///
  /// Params:
  /// - [extension] - file extension without `.`, lowercase.
  static bool isSVG(String extension) {
    return extension == OmniFileExtensions.svg;
  }

  /// Whether an image with [extension] can be decoded, and therefore cropped,
  /// by Flutter itself.
  ///
  /// JPEG and PNG everywhere, plus HEIC/HEIF on iOS and macOS. Platform
  /// dependent: it follows [OmniFileExtensions.flutterCroppableExtensions],
  /// which is fixed from [currentPlatform] the first time it is read.
  ///
  /// Params:
  /// - [extension] - file extension without `.`.
  static bool isCroppableImage(String extension) {
    return OmniFileExtensions.flutterCroppableExtensions.contains(
      extension.toLowerCase(),
    );
  }

  /// Whether an image with [extension] can be shown without a decoder package.
  ///
  /// The same set as [isCroppableImage], accepting `null` — this is the check
  /// behind [OmniFileImageProviderExt.imageProvider].
  ///
  /// Params:
  /// - [extension] - file extension without `.`.
  static bool canPreviewImageByDefault(String? extension) {
    return OmniFileExtensions.flutterCroppableExtensions.contains(
      extension?.toLowerCase() ?? '',
    );
  }

  /// Whether [extension] belongs to an audio format. `false` for `null`.
  ///
  /// Params:
  /// - [extension] - file extension without `.`.
  static bool isAudio(String? extension) {
    if (extension == null) return false;
    return OmniFileExtensions.audioExtensions.contains(extension.toLowerCase());
  }

  /// Whether [extension] belongs to a video format. `false` for `null`.
  ///
  /// Says nothing about whether the device can play it; see [isPlayableVideo].
  ///
  /// Params:
  /// - [extension] - file extension without `.`.
  static bool isVideo(String? extension) {
    if (extension == null) return false;
    return OmniFileExtensions.videoExtensions.contains(extension.toLowerCase());
  }

  /// Whether [extension] belongs to an archive or disk-image format.
  ///
  /// `false` for `null`.
  ///
  /// Params:
  /// - [extension] - file extension without `.`.
  static bool isArchive(String? extension) {
    if (extension == null) return false;
    return OmniFileExtensions.archiveExtensions.contains(
      extension.toLowerCase(),
    );
  }

  /// Whether [extension] is [OmniFileExtensions.xlsx]. `false` for `null`.
  ///
  /// Params:
  /// - [extension] - file extension without `.`.
  static bool isXLSX(String? extension) {
    return extension?.toLowerCase() == OmniFileExtensions.xlsx;
  }

  /// Whether a video with [extension] can be played by the `video_player`
  /// plugin on the current platform. `false` for `null`.
  ///
  /// Matches [OmniFileExtensions.videoPlayerVideoExtensions], so the answer
  /// depends on the platform: `mov` plays on iOS and macOS but not on Android,
  /// and on platforms with no official player only [OmniFileExtensions.mp4]
  /// qualifies. Container support is not codec support.
  ///
  /// Params:
  /// - [extension] - file extension without `.`.
  static bool isPlayableVideo(String? extension) {
    return OmniFileExtensions.videoPlayerVideoExtensions.contains(
      extension?.toLowerCase(),
    );
  }
}

/// Renders [bytes] as a human-readable size — `512 b`, `1.4 KB`, `2.0 MB`,
/// `1.1 GB`.
///
/// [decimalPlaces] controls the fraction shown for KB and up; byte counts are
/// always printed whole. The unit step is platform dependent — 1024 on
/// native Windows, 1000 everywhere else, web included — so the same byte count reads differently
/// across platforms, matching what each platform's own file manager reports.
///
/// Note for tests: [currentPlatform] is the real host OS, not Flutter's
/// `defaultTargetPlatform`, so under `flutter_test` this uses 1024 on a Windows
/// machine and 1000 elsewhere, and `debugDefaultTargetPlatformOverride` has no
/// effect. On web the platform is always [CurrentPlatform.web], so it is 1000.
///
/// Throws an [ArgumentError] if [bytes] is negative.
String formatFileSize(int bytes, {int decimalPlaces = 1}) {
  if (bytes < 0) {
    throw ArgumentError('File size cannot be negative');
  }

  // Windows reports sizes in binary units, everything else in decimal ones.
  // [currentPlatform] rather than `Platform.isWindows` so this also compiles on
  // web, where it is always `.web` and therefore decimal.
  final kilos = currentPlatform == .windows ? 1024 : 1000;

  final kb = kilos;
  final mb = kb * kilos;
  final gb = mb * kilos;

  if (bytes < kb) {
    return '$bytes b';
  } else if (bytes < mb) {
    return '${(bytes / kb).toStringAsFixed(decimalPlaces)} KB';
  } else if (bytes < gb) {
    return '${(bytes / mb).toStringAsFixed(decimalPlaces)} MB';
  } else {
    return '${(bytes / gb).toStringAsFixed(decimalPlaces)} GB';
  }
}
