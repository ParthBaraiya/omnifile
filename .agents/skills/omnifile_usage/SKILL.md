---
name: omnifile_usage
description: How and when to use the `omnifile` Flutter package (OmniFile, OmniBytesLoader, OmniSizeLoader, OmniFileExtensions, OmniFileUtils, formatFileSize). Use when writing or reviewing app code that handles a file which may come from a network URL, in-memory bytes, a Flutter asset or a local path — reading bytes, streaming a download, measuring size, guessing MIME type, classifying by extension, showing an image, or handling web/native differences.
---

# Using `omnifile`

`omnifile` gives one type, `OmniFile`, for a file that lives in one of four places, plus loaders that read or measure it. Write code against `OmniFile` instead of branching on "URL vs `Uint8List` vs asset key vs path".

```dart
import 'package:omnifile/omnifile.dart'; // the only import; there are no other public libraries
```

Requires Dart `^3.12.2`.

## When to use it

Use it when a widget or helper must accept a file from more than one source, or when you need bytes, size, MIME type or an image provider without caring where the file came from.

Do **not** use it for: writing or uploading files, picking files, sniffing content-based MIME types, or paths on web (local files do not exist there). It is read-only and extension-based.

## Build an `OmniFile`

| Source | Shorthand | Meaning of `path` |
| --- | --- | --- |
| network | `'https://…/a.pdf'.networkFile` | the URL |
| local | `'/storage/…/a.pdf'.localFile` | filesystem path |
| asset | `'assets/logo.png'.assetFile` | asset key from `pubspec.yaml` |
| memory | `bytes.memoryFile` | none — carries `bytes` |

- Use the constructor (`OmniFile(source: .network, path: …)`) to supply `name`, a known `size:`, `lastModified` or `metadata`.
- A memory file has no `name` and `mimeType` is `application/octet-stream`. Give it a name with `rename('avatar.png')` — that fixes `name`/`extension` (and so `imageProvider`) but **not** `mimeType`, which is always derived from `path`.
- `rename()` renames only the descriptor, drops `lastModified`, and cannot clear `metadata`.
- The constructor only asserts `path` or `bytes` is non-null. A network file with only bytes (or a memory file with only a path) is accepted and fails later — pass what the source needs.

## Read the file — always through a loader

`OmniFile` does no I/O except `size`. Reading goes through a loader:

```dart
final bytes = await OmniBytesLoader.fromFile(file).load();            // whole file
final stream = await OmniBytesLoader.fromFile(file).stream();         // chunks
```

- Always pick with `fromFile`; do not construct a subclass for the wrong source (it throws).
- `stream()` is real only for network files. Other sources emit their whole content as one event on a single-subscription stream.
- **Network stream gotchas:** it is a broadcast stream shared by every call on the *same loader instance* — keep the instance, do not call `fromFile` per listener. Chunks are not replayed, so attach all listeners in the same turn. Awaiting `stream()` without listening leaks the request. Use `load()` instead when every consumer needs the whole body.
- `load()` on a network file throws a plain `Exception` for non-200 responses; assets throw a `FlutterError` for a missing key.

## Size

```dart
await file.size;           // int? — cached after the first non-null answer
await file.formattedSize;  // '1.4 MB' or null
await OmniSizeLoader.fromFile(file).load(); // uncached, fresh measurement
```

- Network = a `HEAD` request reading `Content-Length`; many servers omit it → `null`.
- Asset = loads the whole asset to measure it. For big assets pass `size:` to the constructor instead.
- Network and asset failures become `null`, so "missing", "offline" and "no header" look identical. Local files **throw**.
- `formatFileSize(bytes)` uses 1024 per step on native Windows and 1000 everywhere else (including web); the unit label is always `KB`/`MB`/`GB`.

## Name, extension, MIME

- `file.extension` — last segment after `.`, **not lowercased**, no leading dot; `null` when `name` is null. A dot-less name returns the whole name.
- `file.nameWithoutExtension` — keeps only the part before the **first** dot (`archive.tar.gz` → `archive`).
- `file.mimeType` — from the raw `path` at construction. A URL with a query string (`a.pdf?token=1`) yields `application/octet-stream`; strip the query yourself or use `OmniFileUtils.getMimeFromExtension(file.extension ?? '')`.
- For network files `name` is the last URL path segment, still percent-encoded.

## Classify by extension

`OmniFileUtils` predicates take the extension **without the leading `.`** and lowercase it themselves (except `isSVG`, which is case-sensitive):

`isImage`, `isAudio`, `isVideo`, `isArchive`, `isPlayableVideo`, `isCroppableImage`, `canPreviewImageByDefault`, `isSVG` and `isXLSX`. All of them take an extension, including `isXLSX`.

`isPlayableVideo` is true when the extension is in `videoPlayerVideoExtensions`, so it depends on the platform (on an unsupported desktop it is `mp4` only).

```dart
OmniFileUtils.isImage(file.extension);
```

They match narrower sets than the MIME table (`isImage` skips tiff/psd/ai/raw; `isAudio` skips wma/aiff). Reference extensions through `OmniFileExtensions.png`, never raw strings; `7z`, `3gp`, `3g2` are `sevenZ`, `g3p`, `g3p2`.

Lists that answer "can the framework handle it?" depend on the platform (via `currentPlatform`) and are fixed for the process:

- `OmniFileExtensions.flutterImageExtensions` — what `Image` decodes (HEIC/HEIF only on iOS/macOS).
- `OmniFileExtensions.videoPlayerVideoExtensions` / `videoPlayerAudioExtensions` — what the `video_player` plugin can play on this platform. Container support is not codec support; `initialize` has the last word.

## Show an image

```dart
final provider = file.imageProvider;     // ImageProvider? — null if Flutter can't decode the extension
if (provider != null) return Image(image: provider);
if (OmniFileUtils.isImage(file.extension)) return const Icon(Icons.image); // svg, avif, …
```

`imageProvider` decides by `extension`, so a nameless memory file always returns `null` until renamed. It throws `UnsupportedPlatformException` for a local file on web.

## Platforms and errors

- network, memory and asset work everywhere; **local is native-only**.
- Guard before reading: `file.source.isSupported`, `file.isValid`, or `supportsLocalFiles`. A local `OmniFile` can still be *constructed* on web (inert).
- Catch package errors with `OmniFileException` (covers `OmniFileNotFoundException` — has `.path` — and `UnsupportedPlatformException`); it is `dart:io`-free so the same `catch` compiles on web. Source mismatches and network non-200s are still plain `Exception`s, and a missing path/bytes is a null-check `TypeError`.
- `currentPlatform` is the real host OS natively and always `web` in a browser; it ignores `debugDefaultTargetPlatformOverride`, so tests cannot fake another platform.

## Quick decision guide

- Need bytes → `OmniBytesLoader.fromFile(f).load()`.
- Need progress or a big download → keep one `OmniBytesLoader`, `await loader.stream()`, optionally `await loader.size` for the total.
- Need a display size → `await f.formattedSize`.
- Need a fresh size → `OmniSizeLoader.fromFile(f).load()`, not `f.size`.
- Need to know if it's an image/video/audio → `OmniFileUtils.*(f.extension)`.
- Need to render an image → `f.imageProvider`, fall back on `isImage`.
- Local file in shared/web code → check `source.isSupported` first.
