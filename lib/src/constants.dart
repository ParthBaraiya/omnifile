/// The extension constants and the lists and map built from them.
///
/// [OmniFileExtensions] holds every extension string this package knows plus
/// the category lists that [OmniFileUtils] predicates match against, and
/// [extensionToMimeType] maps those same constants to MIME types. Some lists
/// depend on the platform — they are computed once, on first access, from
/// [currentPlatform], which cannot change while the app runs.
///
/// Every extension is written **without** the leading `.` and in lowercase.
library;

import 'dart:collection';

import 'package:omnifile/omnifile.dart';

/// The extension strings this package knows about, as constants.
///
/// Always **without** the leading `.` and lowercase, so they can be compared
/// against [OmniFile.extension] directly and used as [extensionToMimeType]
/// keys. Reference the constants rather than retyping the literals — a few
/// names have to differ from their string ([sevenZ], [g3p], [g3p2]) because
/// Dart identifiers cannot start with a digit.
abstract class OmniFileExtensions {
  /// Image extensions, as matched by [OmniFileUtils.isImage].
  ///
  /// Includes formats Flutter cannot decode on its own, such as [svg] and
  /// [avif]; see [flutterImageExtensions] for the ones it can.
  static const imageExtensions = [
    jpg,
    jpeg,
    png,
    gif,
    webp,
    bmp,
    svg,
    heic,
    heif,
    avif,
    ico,
    wbmp,
  ];

  /// Extensions Flutter's own engine decodes on the current platform, with no
  /// decoder package.
  ///
  /// JPEG, PNG, GIF (animated too), WebP (animated too), BMP and WBMP
  /// everywhere, plus HEIC and HEIF on iOS and macOS, whose engines hand
  /// decoding to the OS. Broader than [flutterCroppableExtensions], which is
  /// about what can be cropped, and narrower than [imageExtensions], which is
  /// every image format this package recognises.
  ///
  /// Computed once, on first access, from [currentPlatform], and unmodifiable.
  /// Because [currentPlatform] is the real host OS, it does not respond to
  /// `debugDefaultTargetPlatformOverride` in tests.
  static final flutterImageExtensions = UnmodifiableListView([
    jpg,
    jpeg,
    png,
    gif,
    webp,
    bmp,
    wbmp,
    if (currentPlatform == .ios || currentPlatform == .macos) ...[heic, heif],
  ]);

  /// Extensions Flutter can decode itself, as matched by
  /// [OmniFileUtils.isCroppableImage] and
  /// [OmniFileUtils.canPreviewImageByDefault].
  ///
  /// JPEG and PNG everywhere, plus HEIC and HEIF on iOS and macOS. Computed
  /// once, on first access, from [currentPlatform], and unmodifiable — so it
  /// does not respond to `debugDefaultTargetPlatformOverride` in tests, and on
  /// web it never includes HEIC/HEIF.
  static final flutterCroppableExtensions = UnmodifiableListView([
    jpg,
    jpeg,
    png,
    if (currentPlatform == .ios || currentPlatform == .macos) ...{heic, heif},
  ]);

  /// Audio extensions, as matched by [OmniFileUtils.isAudio].
  static const audioExtensions = [
    mp3,
    wav,
    aac,
    m4a,
    ogg,
    opus,
    flac,
    amr,
    mid,
    midi,
  ];

  /// Video extensions, as matched by [OmniFileUtils.isVideo].
  static const videoExtensions = [
    mp4,
    m4v,
    mov,
    avi,
    wmv,
    flv,
    mkv,
    webm,
    g3p,
    g3p2,
    mpeg,
    mpg,
  ];

  /// Archive and disk-image extensions, as matched by
  /// [OmniFileUtils.isArchive].
  static const archiveExtensions = [
    zip,
    rar,
    sevenZ,
    tar,
    gz,
    tgz,
    bz2,
    xz,
    iso,
    dmg,
  ];

  /// Video extensions the `video_player` plugin can play on the current
  /// platform.
  ///
  /// Each platform has its own player, so the list follows it: ExoPlayer on
  /// Android (MP4, M4V, WebM, Matroska, FLV, 3GP/3G2, HLS), AVPlayer on iOS and
  /// macOS (MP4, M4V, QuickTime, 3GP/3G2, MPEG, HLS), and the browser on web
  /// (MP4, M4V, WebM, QuickTime). Windows, Linux and any other platform have no
  /// official player, so they get only [mp4], the one container everything
  /// agrees on.
  ///
  /// Container support is not codec support, so the final word is always the
  /// controller's `initialize`. [m3u8] is an HLS playlist rather than a file,
  /// but it is what `video_player` is most often pointed at for streams.
  /// [wmv] and [avi] are absent: none of the platform players handle them.
  ///
  /// Computed once, on first access, from [currentPlatform], and unmodifiable.
  static final videoPlayerVideoExtensions = UnmodifiableListView(
    switch (currentPlatform) {
      .android => const [mp4, m4v, webm, mkv, flv, g3p, g3p2, m3u8],
      .ios || .macos => const [mp4, m4v, mov, g3p, g3p2, mpeg, mpg, m3u8],
      .web => const [mp4, m4v, webm, mov],
      _ => const [mp4],
    },
  );

  /// Audio extensions the `video_player` plugin can play on the current
  /// platform — it has no separate audio player, so audio goes through the same
  /// controller as video.
  ///
  /// Follows the platform player like [videoPlayerVideoExtensions]: Android
  /// takes the widest set (including [ogg], [oga], [opus], [flac], [amr] and
  /// [weba]), iOS and macOS take [mp3], [wav], [aac], [m4a], [flac], [aiff] and
  /// MIDI, the browser takes the web-friendly formats, and any other platform
  /// gets only the four every decoder handles. [wma] is absent everywhere.
  ///
  /// Computed once, on first access, from [currentPlatform], and unmodifiable.
  static final videoPlayerAudioExtensions = UnmodifiableListView(
    switch (currentPlatform) {
      .android => const [
        mp3,
        wav,
        aac,
        m4a,
        ogg,
        oga,
        opus,
        flac,
        amr,
        mid,
        midi,
        weba,
      ],
      .ios || .macos => const [mp3, wav, aac, m4a, flac, aiff, mid, midi],
      .web => const [mp3, wav, aac, m4a, ogg, oga, opus, flac, weba],
      _ => const [mp3, wav, aac, m4a],
    },
  );

  // Images

  /// JPEG image.
  static const jpg = 'jpg';

  /// JPEG image, spelled out.
  static const jpeg = 'jpeg';

  /// PNG image.
  static const png = 'png';

  /// GIF image, possibly animated.
  static const gif = 'gif';

  /// WebP image.
  static const webp = 'webp';

  /// Windows bitmap image.
  static const bmp = 'bmp';

  /// SVG vector image. Flutter needs a package such as `flutter_svg` to render
  /// it.
  static const svg = 'svg';

  /// HEIC image — Apple's HEIF container, the iPhone camera default.
  static const heic = 'heic';

  /// HEIF image.
  static const heif = 'heif';

  /// AVIF image.
  static const avif = 'avif';

  /// Adobe Illustrator document.
  static const ai = 'ai';

  /// Adobe Photoshop document.
  static const psd = 'psd';

  /// Raw camera sensor data.
  static const raw = 'raw';

  /// TIFF image.
  static const tiff = 'tiff';

  /// TIFF image, short form.
  static const tif = 'tif';

  /// Windows icon image.
  static const ico = 'ico';

  /// Wireless Bitmap image — a 1-bit format Flutter's engine decodes.
  static const wbmp = 'wbmp';

  // Video

  /// MP4 video — the one container every platform can play.
  static const mp4 = 'mp4';

  /// iTunes MPEG-4 video.
  static const m4v = 'm4v';

  /// QuickTime video.
  static const mov = 'mov';

  /// Audio Video Interleave video.
  static const avi = 'avi';

  /// Windows Media video.
  static const wmv = 'wmv';

  /// Flash video.
  static const flv = 'flv';

  /// Matroska video.
  static const mkv = 'mkv';

  /// WebM video.
  static const webm = 'webm';

  /// 3GP mobile video — `'3gp'`, renamed because identifiers cannot start with
  /// a digit.
  static const g3p = '3gp';

  /// 3G2 mobile video — `'3g2'`, renamed because identifiers cannot start with
  /// a digit.
  static const g3p2 = '3g2';

  /// MPEG video.
  static const mpeg = 'mpeg';

  /// MPEG video, short form.
  static const mpg = 'mpg';

  /// HLS playlist — a text index of video segments, used for streaming rather
  /// than a video file itself.
  static const m3u8 = 'm3u8';

  // Audio

  /// MP3 audio.
  static const mp3 = 'mp3';

  /// WAV audio, usually uncompressed.
  static const wav = 'wav';

  /// AAC audio.
  static const aac = 'aac';

  /// MPEG-4 audio.
  static const m4a = 'm4a';

  /// Ogg Vorbis audio.
  static const ogg = 'ogg';

  /// Opus audio.
  static const opus = 'opus';

  /// FLAC lossless audio.
  static const flac = 'flac';

  /// AMR audio, typical of voice recordings.
  static const amr = 'amr';

  /// MIDI sequence.
  static const mid = 'mid';

  /// MIDI sequence, spelled out.
  static const midi = 'midi';

  /// Windows Media audio. Not in the [OmniFileUtils.isAudio] list.
  static const wma = 'wma';

  /// Ogg audio, the audio-only extension for Ogg Vorbis/FLAC/Opus streams.
  static const oga = 'oga';

  /// WebM audio — the audio-only form of [webm].
  static const weba = 'weba';

  /// AIFF audio, Apple's uncompressed format.
  static const aiff = 'aiff';

  // Documents

  /// PDF document.
  static const pdf = 'pdf';

  /// Plain text.
  static const txt = 'txt';

  /// Rich Text Format document.
  static const rtf = 'rtf';

  /// RSS feed.
  static const rss = 'rss';

  /// Java source file.
  static const java = 'java';

  /// Markdown document.
  static const md = 'md';

  /// Log file.
  static const log = 'log';

  /// Tab-separated values.
  static const tsv = 'tsv';

  /// EPUB e-book.
  static const epub = 'epub';

  // Microsoft Office

  /// Legacy Word document.
  static const doc = 'doc';

  /// Word document.
  static const docx = 'docx';

  /// Legacy Excel spreadsheet.
  static const xls = 'xls';

  /// Excel spreadsheet — see [OmniFileUtils.isXLSX].
  static const xlsx = 'xlsx';

  /// Legacy PowerPoint presentation.
  static const ppt = 'ppt';

  /// PowerPoint presentation.
  static const pptx = 'pptx';

  // OpenDocument

  /// OpenDocument text document.
  static const odt = 'odt';

  /// OpenDocument spreadsheet.
  static const ods = 'ods';

  /// OpenDocument presentation.
  static const odp = 'odp';

  // Web & Markup

  /// HTML document.
  static const html = 'html';

  /// HTML document, short form.
  static const htm = 'htm';

  /// CSS stylesheet.
  static const css = 'css';

  /// JavaScript source file.
  static const js = 'js';

  /// JSON document.
  static const json = 'json';

  /// XML document.
  static const xml = 'xml';

  /// YAML document.
  static const yaml = 'yaml';

  /// YAML document, short form.
  static const yml = 'yml';

  // Archives

  /// ZIP archive.
  static const zip = 'zip';

  /// RAR archive.
  static const rar = 'rar';

  /// 7-Zip archive — `'7z'`, renamed because identifiers cannot start with a
  /// digit.
  static const sevenZ = '7z';

  /// Tar archive.
  static const tar = 'tar';

  /// Gzip-compressed file.
  static const gz = 'gz';

  /// Gzip-compressed tar archive — the single-extension form of `.tar.gz`.
  static const tgz = 'tgz';

  /// Bzip2-compressed file.
  static const bz2 = 'bz2';

  /// XZ-compressed file.
  static const xz = 'xz';

  /// ISO 9660 disc image.
  static const iso = 'iso';

  /// Apple disk image.
  static const dmg = 'dmg';

  // Others

  /// Comma-separated values.
  static const csv = 'csv';

  /// Android application package.
  static const apk = 'apk';

  /// Windows executable.
  static const exe = 'exe';

  /// Windows dynamic-link library.
  static const dll = 'dll';

  /// Windows Installer package.
  static const msi = 'msi';

  /// Java archive.
  static const jar = 'jar';

  /// iOS application archive.
  static const ipa = 'ipa';

  /// Android App Bundle.
  static const aab = 'aab';

  // Design / CAD / Office misc

  /// Encapsulated PostScript.
  static const eps = 'eps';

  /// AutoCAD drawing.
  static const dwg = 'dwg';

  /// Microsoft Access database.
  static const mdb = 'mdb';

  /// Microsoft Publisher document.
  static const pub = 'pub';

  /// PostScript document.
  static const ps = 'ps';

  /// Windows Cardfile.
  static const crd = 'crd';
}

/// Maps each [OmniFileExtensions] constant to its MIME type.
///
/// Keyed by the constants, never by raw strings, so a typo is a compile error.
/// Read it through [OmniFileUtils.getMimeFromExtension], which lowercases
/// the key and supplies the `application/octet-stream` fallback for extensions
/// that are not listed here.
const extensionToMimeType = {
  // Images
  OmniFileExtensions.jpg: 'image/jpeg',
  OmniFileExtensions.jpeg: 'image/jpeg',
  OmniFileExtensions.png: 'image/png',
  OmniFileExtensions.gif: 'image/gif',
  OmniFileExtensions.webp: 'image/webp',
  OmniFileExtensions.bmp: 'image/bmp',
  OmniFileExtensions.svg: 'image/svg+xml',
  OmniFileExtensions.heic: 'image/heic',
  OmniFileExtensions.heif: 'image/heif',
  OmniFileExtensions.avif: 'image/avif',
  OmniFileExtensions.ai: 'application/postscript',
  OmniFileExtensions.psd: 'image/vnd.adobe.photoshop',
  OmniFileExtensions.raw: 'image/raw',
  OmniFileExtensions.tiff: 'image/tiff',
  OmniFileExtensions.tif: 'image/tiff',
  OmniFileExtensions.ico: 'image/vnd.microsoft.icon',
  OmniFileExtensions.wbmp: 'image/vnd.wap.wbmp',

  // Video
  OmniFileExtensions.mp4: 'video/mp4',
  OmniFileExtensions.m4v: 'video/x-m4v',
  OmniFileExtensions.mov: 'video/quicktime',
  OmniFileExtensions.avi: 'video/x-msvideo',
  OmniFileExtensions.wmv: 'video/x-ms-wmv',
  OmniFileExtensions.flv: 'video/x-flv',
  OmniFileExtensions.mkv: 'video/x-matroska',
  OmniFileExtensions.webm: 'video/webm',
  OmniFileExtensions.g3p: 'video/3gpp',
  OmniFileExtensions.g3p2: 'video/3gpp2',
  OmniFileExtensions.mpeg: 'video/mpeg',
  OmniFileExtensions.mpg: 'video/mpeg',
  OmniFileExtensions.m3u8: 'application/vnd.apple.mpegurl',

  // Audio
  OmniFileExtensions.mp3: 'audio/mpeg',
  OmniFileExtensions.wav: 'audio/wav',
  OmniFileExtensions.aac: 'audio/aac',
  OmniFileExtensions.m4a: 'audio/mp4',
  OmniFileExtensions.ogg: 'audio/ogg',
  OmniFileExtensions.opus: 'audio/opus',
  OmniFileExtensions.flac: 'audio/flac',
  OmniFileExtensions.amr: 'audio/amr',
  OmniFileExtensions.mid: 'audio/midi',
  OmniFileExtensions.midi: 'audio/midi',
  OmniFileExtensions.wma: 'audio/x-ms-wma',
  OmniFileExtensions.oga: 'audio/ogg',
  OmniFileExtensions.weba: 'audio/webm',
  OmniFileExtensions.aiff: 'audio/aiff',

  // Documents
  OmniFileExtensions.pdf: 'application/pdf',
  OmniFileExtensions.txt: 'text/plain',
  OmniFileExtensions.rtf: 'application/rtf',
  OmniFileExtensions.rss: 'application/rss+xml',
  OmniFileExtensions.java: 'text/x-java-source',
  OmniFileExtensions.md: 'text/markdown',
  OmniFileExtensions.log: 'text/plain',
  OmniFileExtensions.tsv: 'text/tab-separated-values',
  OmniFileExtensions.epub: 'application/epub+zip',

  // Microsoft Office
  OmniFileExtensions.doc: 'application/msword',
  OmniFileExtensions.docx:
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  OmniFileExtensions.xls: 'application/vnd.ms-excel',
  OmniFileExtensions.xlsx:
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  OmniFileExtensions.ppt: 'application/vnd.ms-powerpoint',
  OmniFileExtensions.pptx:
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',

  // OpenDocument
  OmniFileExtensions.odt: 'application/vnd.oasis.opendocument.text',
  OmniFileExtensions.ods: 'application/vnd.oasis.opendocument.spreadsheet',
  OmniFileExtensions.odp: 'application/vnd.oasis.opendocument.presentation',

  // Web & Markup
  OmniFileExtensions.html: 'text/html',
  OmniFileExtensions.htm: 'text/html',
  OmniFileExtensions.css: 'text/css',
  OmniFileExtensions.js: 'application/javascript',
  OmniFileExtensions.json: 'application/json',
  OmniFileExtensions.xml: 'application/xml',
  OmniFileExtensions.yaml: 'application/x-yaml',
  OmniFileExtensions.yml: 'application/x-yaml',

  // Archives
  OmniFileExtensions.zip: 'application/zip',
  OmniFileExtensions.rar: 'application/vnd.rar',
  OmniFileExtensions.sevenZ: 'application/x-7z-compressed',
  OmniFileExtensions.tar: 'application/x-tar',
  OmniFileExtensions.gz: 'application/gzip',
  OmniFileExtensions.tgz: 'application/gzip',
  OmniFileExtensions.bz2: 'application/x-bzip2',
  OmniFileExtensions.xz: 'application/x-xz',
  OmniFileExtensions.iso: 'application/x-iso9660-image',
  OmniFileExtensions.dmg: 'application/x-apple-diskimage',

  // Others
  OmniFileExtensions.csv: 'text/csv',
  OmniFileExtensions.apk: 'application/vnd.android.package-archive',
  OmniFileExtensions.exe: 'application/vnd.microsoft.portable-executable',
  OmniFileExtensions.dll: 'application/x-msdownload',
  OmniFileExtensions.msi: 'application/x-msi',
  OmniFileExtensions.jar: 'application/java-archive',
  OmniFileExtensions.ipa: 'application/octet-stream',
  OmniFileExtensions.aab: 'application/octet-stream',

  // Design / CAD / Office misc
  OmniFileExtensions.eps: 'application/postscript',
  OmniFileExtensions.dwg: 'image/vnd.dwg',
  OmniFileExtensions.mdb: 'application/x-msaccess',
  OmniFileExtensions.pub: 'application/x-mspublisher',
  OmniFileExtensions.ps: 'application/postscript',
  OmniFileExtensions.crd: 'application/x-mscardfile',
};
