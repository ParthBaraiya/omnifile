# omnifile

A single descriptor for files that live anywhere: **network URLs**, **in-memory
bytes**, **Flutter assets**, or **local paths** — with loaders for their bytes,
stream, size, and MIME type.

Most apps end up with four different shapes for "a file": a URL from the API, a
`Uint8List` from a picker, an asset key from `pubspec.yaml`, and a path from the
filesystem. Every widget and helper that touches one then has to branch on which
it got. `omnifile` collapses those four into one `OmniFile` value, and puts the
reading behind loaders that know what to do with each source.

```dart
Future<void> upload(OmniFile file) async {
  final bytes = await OmniBytesLoader.fromFile(file).load();
  // ...same code whether it came from a URL, a picker, an asset, or disk.
}
```

## Features

- **One descriptor, four sources** — `OmniFile` carries either a `path` or
  `bytes`, and its `source` decides how everything else resolves.
- **Cheap by default** — the descriptor does no I/O except `size`. `name`,
  `extension` and `mimeType` are derived from the path at construction time.
- **Loaders, not methods** — `OmniBytesLoader` reads the contents,
  `OmniSizeLoader` measures it. One implementation per source, picked for you by
  `fromFile`.
- **Real streaming for downloads** — the network loader hands back the HTTP
  response stream instead of buffering the whole body, as a broadcast stream
  that closes its client for you and is shared between concurrent callers.
- **94 MIME types** off the extension, plus `isImage` / `isVideo` / `isAudio` /
  `isArchive` predicates, per-platform lists of what Flutter decodes
  (`flutterImageExtensions`) and what `video_player` plays
  (`videoPlayerVideoExtensions`, `videoPlayerAudioExtensions`), and a
  `formatFileSize` that follows platform convention.
- **Widget-ready** — `file.imageProvider` maps a file onto the matching
  `ImageProvider`, and returns `null` for formats Flutter cannot decode instead
  of failing at paint time.
- **Web-safe** — `dart:io` is confined to one conditionally-imported file, so
  the package builds for web (Wasm included). Exceptions are `dart:io`-free too,
  so the same `catch` compiles everywhere.

## Getting started

```yaml
dependencies:
  omnifile: ^0.0.1
```

or `flutter pub add omnifile`, then:

```dart
import 'package:omnifile/omnifile.dart';
```

Requires Dart SDK `^3.12.2`. The package uses private named parameters and dot
shorthands, so it will not compile on older SDKs.

## Usage

### 1. Build a file and inspect it

The four extension getters are the short way in; use the constructor when you
need to supply a name, a pre-known size, `lastModified` or `metadata`.

```dart
final report = 'https://example.com/q3/report.pdf'.networkFile;
report.name;                 // 'report.pdf'
report.extension;            // 'pdf'
report.mimeType;             // 'application/pdf'
await report.size;           // 248133 — one HEAD request, then cached
await report.formattedSize;  // '248.1 KB'

final logo   = 'assets/images/logo.png'.assetFile;
final saved  = '/storage/emulated/0/Download/invoice.xlsx'.localFile;
final picked = pickerResult.bytes.memoryFile.rename('avatar.png');

OmniFileUtils.isImage(logo.extension);  // true
OmniFileUtils.isXLSX(saved);            // true
saved.isValid;                          // false on web — no filesystem
```

A memory file has no path, so it has no name and an `application/octet-stream`
MIME type until you `rename()` it.

### 2. Read the bytes — same call for every source

```dart
final bytes = await OmniBytesLoader.fromFile(file).load();
```

For a large download, stream it instead. Only the network loader streams for
real; the others emit their contents as a single event so a `StreamBuilder` or
`await for` pipeline does not have to special-case them.

The network stream is a broadcast stream, so several listeners can share one
download — subscribe them in the same turn, since chunks are not replayed for a
listener that joins late. Keep the loader instance around to share: every call
made while the download is running hands back that same stream, and the
underlying `http.Client` is closed as soon as the body ends, errors, or the last
subscription is cancelled.

```dart
final loader = OmniBytesLoader.fromFile(bigVideo);
final total  = await loader.size;  // may be null
var received = 0;

await for (final chunk in await loader.stream()) {
  received += chunk.length;
  if (total != null) onProgress(received / total);
}
```

### 3. Show it in a widget

```dart
Widget build(BuildContext context) {
  final provider = file.imageProvider;

  if (provider != null) {
    return Image(image: provider);   // Memory/Asset/Network/FileImage
  }
  if (OmniFileUtils.isImage(file.extension)) {
    return const Icon(Icons.image);  // an image Flutter can't decode (SVG, …)
  }
  return FileTile(name: file.name ?? 'Unnamed', type: file.mimeType);
}
```

`imageProvider` is non-null only for formats Flutter decodes itself — `jpg`,
`jpeg`, `png`, plus `heic` and `heif` on iOS and macOS.

## Supported MIME types

`OmniFile.mimeType` is guessed from the extension — never sniffed from the
contents — and falls back to `application/octet-stream` for anything not listed
below. `extensionToMimeType` is the map itself,
`OmniFileUtils.getMimeFromExtension` reads it with the fallback applied, and
every extension is also a constant on `OmniFileExtensions`.

| Category | Extensions |
| --- | --- |
| Images | `jpg` `jpeg` `png` `gif` `webp` `bmp` `svg` `heic` `heif` `avif` `ico` `wbmp` `tiff` `tif` `psd` `raw` `ai` |
| Video | `mp4` `m4v` `mov` `avi` `wmv` `flv` `mkv` `webm` `3gp` `3g2` `mpeg` `mpg` `m3u8` |
| Audio | `mp3` `wav` `aac` `m4a` `ogg` `oga` `opus` `flac` `amr` `mid` `midi` `wma` `weba` `aiff` |
| Documents | `pdf` `txt` `rtf` `csv` `tsv` `md` `log` `epub` `rss` `java` |
| Microsoft Office | `doc` `docx` `xls` `xlsx` `ppt` `pptx` |
| OpenDocument | `odt` `ods` `odp` |
| Web and markup | `html` `htm` `css` `js` `json` `xml` `yaml` `yml` |
| Archives and disk images | `zip` `rar` `7z` `tar` `gz` `tgz` `bz2` `xz` `iso` `dmg` |
| Executables, design, CAD | `apk` `aab` `ipa` `jar` `exe` `msi` `dll` `eps` `ps` `dwg` `mdb` `pub` `crd` |

The `OmniFileUtils` predicates match narrower sets than this table on purpose —
`isImage` skips `tiff`, `tif`, `psd`, `ai` and `raw`, and `isAudio` skips `wma`
and `aiff`, for instance. Each predicate's
dartdoc lists exactly what it matches.

## Platform support

| Source | Android | iOS | macOS | Windows | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| `network` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `memory` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `asset` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `local` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

`dart:io` lives in exactly one conditionally-imported file, so the package
builds for web. Constructing a local `OmniFile` on web is still fine — the
descriptor is inert — but *reading* one (`size`, `imageProvider`,
`OmniBytesLoader.load`) throws `UnsupportedPlatformException`. Check first with
`file.source.isSupported`, `file.isValid`, or the top-level
`supportsLocalFiles`.

## Error handling

Everything the package raises on purpose extends `OmniFileException`, which does
not import `dart:io` — so one `catch` covers web and native:

```dart
try {
  final bytes = await OmniBytesLoader.fromFile(file).load();
} on OmniFileNotFoundException catch (e) {
  // a local path that isn't there — e.path tells you which
} on UnsupportedPlatformException catch (e) {
  // a local file on web
} on OmniFileException catch (e) {
  // anything else this package raises
}
```

Failures are not reported uniformly, and it is worth knowing which is which:

| Situation | Result |
| --- | --- |
| Network file, non-200 response | throws a plain `Exception`, not an `OmniFileException` |
| Asset key not in the bundle, `load()` | throws whatever the bundle throws — a `FlutterError` |
| Asset key not in the bundle, `size` | `null` |
| Server omits `Content-Length`, or device offline, for `size` | `null` |
| Local path missing | throws `OmniFileNotFoundException` |
| Local file on web | throws `UnsupportedPlatformException` |
| Loader handed a file from the wrong source | throws a plain `Exception` |
| File built without the member its source needs | null-check `TypeError` from `load()`, `null` from `size` |

The upshot for sizes: a missing asset, an offline device and a header-less server
are all indistinguishable through `OmniFile.size`. Local files are the exception,
and do throw.

## Things worth knowing

- **`size` is cached, loaders are not.** `OmniFile.size` measures once and
  remembers; a `null` answer is *not* cached, so it is retried on the next read.
  The loaders are stateless and re-measure on every `load()` — use them directly
  when you want a fresh number.
- **Measuring an asset costs as much as reading it.** Flutter's bundle has no
  size-only API, so `size` on a large asset loads the whole thing. Pre-seed the
  size on the descriptor if you only need the number.
- **`size` for a network file is a `HEAD` request** reading `Content-Length` —
  cheap, but plenty of servers do not answer it.
- **`mimeType` is read off the raw `path`, not off `name`.** A URL with a query
  string breaks the guess: `report.pdf?token=abc` yields
  `application/octet-stream`, while `extension` still says `pdf`.
- **`nameWithoutExtension` keeps only the first dot-separated segment**, so
  `archive.tar.gz` becomes `archive`.
- **`extension` is not lowercased.** The predicates lowercase their own
  argument, so this only matters if you compare it yourself — and for `isSVG`,
  which is case-sensitive.
- **`rename()` renames nothing on disk or on the server.** It returns a copy
  with a new `name`, keeps the `mimeType` derived from `path`, carries over any
  cached size and `metadata`, and drops `lastModified`.
- **`lastModified` is never populated by this package.** Pass it in from
  whatever produced the path.
- **`formatFileSize` is platform dependent by design:** 1024 bytes to the KB on
  Windows, 1000 everywhere else, matching what each platform's own file manager
  reports. The platform comes from `currentPlatform` — the real host OS natively,
  and always `web` (so 1000) in a browser — not from Flutter's
  `defaultTargetPlatform`, so tests see the machine's own convention and
  `debugDefaultTargetPlatformOverride` has no effect. Negative input throws
  `ArgumentError`.
- **`OmniBytesLoader.stream()` only streams for real on network files,** and
  only that one is a broadcast stream — the others are single-subscription and
  throw if you listen twice. The network stream does not replay: a listener
  that subscribes after the bytes have started flowing misses what it missed.
  Awaiting `stream()` and never listening leaves the request open, since nothing
  owns the response until the first subscription arrives.
- **`metadata` is `dynamic` and mutable** — the one non-final field. Nothing in
  the package reads it; use it for the picker result, an upload id, a caption.

## Additional information

Contributions and bug reports are welcome — please open an issue with the
platform, the source (`network` / `memory` / `asset` / `local`) and a minimal
repro.

When adding a source, extend the enum, its `isX` getter, the three exhaustive
switches (`_getName`, `OmniBytesLoader.fromFile`, `OmniSizeLoader.fromFile`),
both loader hierarchies, and `imageProvider` / `isValid` / `isSupported`. When
adding an extension, add the `OmniFileExtensions` constant, an
`extensionToMimeType` entry keyed by that constant, and the relevant category
list. Anything touching the filesystem goes through `lib/src/local_file/`, never
`dart:io` directly.
