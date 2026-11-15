# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`omnifile` is a Flutter *package* (library only — no `example/` app, no platform folders). It provides `OmniFile`, a single descriptor for a file that may live in one of four places (network URL, in-memory bytes, Flutter asset, local filesystem path), plus loaders that fetch bytes from whichever source a given file uses.

Current state worth knowing: `README.md` and the `pubspec.yaml` `description` are written, but `CHANGELOG.md`, the empty `homepage:` and the `flutter: ">=1.17.0"` constraint in `pubspec.yaml` are still the unmodified `flutter create --template=package` leftovers, and `test/` exists but is empty. Current branch is `master`; commits use a leading gitmoji (`:sparkles:`, `:art:`, `:note:`).

## Commands

```powershell
flutter pub get                     # deps
flutter analyze                     # lints (flutter_lints 6.0 via analysis_options.yaml) — currently clean
dart format lib                     # formatting
flutter test                        # all tests (test/ is currently empty)
flutter test test/foo_test.dart     # single file
flutter test test/foo_test.dart --plain-name "some test name"   # single test
```

SDK constraint is `sdk: ^3.12.2`, and the code leans on two recent Dart features throughout, so it will not compile on older SDKs:

- **Private named parameters** — `OmniFile({this._size})` is passed as `size:` from callers (see `rename()`).
- **Dot shorthands** — `source: .network`, `case .memory:`, `this == .local`, `currentPlatform == .ios`. The enum type is never spelled out where it can be inferred; match that when adding code.

## Architecture

One public entry point, [lib/omnifile.dart](lib/omnifile.dart), which only re-exports the libraries under [lib/src/](lib/src/); consumers import `package:omnifile/omnifile.dart`. Inside `src/`, files import siblings relatively — except the loaders and `utils.dart`/`constants.dart`, which import the barrel.

- [lib/src/omnifile.dart](lib/src/omnifile.dart) — `OmniFile`. A lightweight descriptor: it carries *either* `path` or `bytes` (asserted in the constructor), derives `name` from the path via `_getName` (URI-aware for network, `p.basename` otherwise) and `mimeType` from the extension at construction time, and lazily caches `_size`.
- [lib/src/enums.dart](lib/src/enums.dart) — `OmniFileSource` (with its `isX` getters and `isSupported`) and `CurrentPlatform`.
- [lib/src/extensions.dart](lib/src/extensions.dart) — the ergonomic entry points: `String.networkFile` / `.localFile` / `.assetFile`, `Uint8List.memoryFile`, and `OmniFile.imageProvider`, which maps each source onto the matching Flutter `ImageProvider`.
- [lib/src/loaders/data_loader.dart](lib/src/loaders/data_loader.dart) — `OmniBytesLoader`, one subclass per source, dispatched by `OmniBytesLoader.fromFile(file)`. Each subclass also re-checks `file.source` and throws if it was constructed with a mismatched file. Only the network loader implements a real `stream()` (a shared broadcast stream); the others wrap `load().asStream()`.
- [lib/src/loaders/size_loader.dart](lib/src/loaders/size_loader.dart) — `OmniSizeLoader`, the same shape as the bytes loader (one subclass per source, `fromFile` dispatch, per-subclass source re-check) but returning `Future<int?>` from `load()`, plus a `loadFormatted()` that runs the result through `formatFileSize`. `OmniFile.size` is a thin caching wrapper over `OmniSizeLoader.fromFile(this).load()` — the loaders themselves are stateless and re-measure on every call, so use them directly when you want a fresh read.
- [lib/src/constants.dart](lib/src/constants.dart) — pure data: `OmniFileExtensions` (per-extension `const String`s, the category lists `imageExtensions`, `audioExtensions`, `videoExtensions`, `archiveExtensions`, and the platform-dependent `flutterImageExtensions`, `flutterCroppableExtensions`, `videoPlayerVideoExtensions`, `videoPlayerAudioExtensions`) and the `extensionToMimeType` map keyed by those same constants.
- [lib/src/utils.dart](lib/src/utils.dart) — the `OmniFileUtils.isImage`/`isVideo`/... predicates that match against those lists, and top-level `formatFileSize`.
- [lib/src/exceptions.dart](lib/src/exceptions.dart) — `OmniFileException` base + `UnsupportedPlatformException` and `OmniFileNotFoundException`. Deliberately `dart:io`-free so the same `catch` compiles on web and native.

Plus the platform pair under [lib/src/local_file/](lib/src/local_file/) — see [Web](#web).

[.agents/skills/omnifile_usage/SKILL.md](.agents/skills/omnifile_usage/SKILL.md) is a consumer-facing skill describing how and when to call the public API. It restates behaviour (nullability, which predicates take what, per-platform lists), so update it in the same change whenever public signatures or semantics change.

Reading is deliberately not the descriptor's job: `OmniFile` performs no I/O except `size`, and everything else goes through a loader.

### Documentation convention

Every library has a `library;` dartdoc header, and every public member is documented — including the reasons behind a design choice and the ways it can bite (`size` swallowing errors, `nameWithoutExtension` truncating `archive.tar.gz`, `isSVG` being the one case-sensitive predicate). Extension-classifying helpers end with a `Params:` block noting that the extension arrives without the leading `.`.

`flutter_lints` does not enable `public_member_api_docs`, so nothing enforces this — keep new public API documented to the same depth by hand, explaining behaviour rather than restating the name.

### Change patterns

**Adding a source**: add the enum value (in `enums.dart`) and its `isX` getter, then extend the three exhaustive switches — `_getName`, `OmniBytesLoader.fromFile`, and `OmniSizeLoader.fromFile` — add a bytes-loader *and* a size-loader subclass, and handle it in `imageProvider`, `isValid`, and `isSupported`. The switches are exhaustive, so the analyzer catches most of these for you; `imageProvider` and `isValid` are `if`-chains and will silently fall through. If the new source needs `dart:io`, it goes through the platform pair rather than importing it directly (see [Web](#web)).

**Adding an extension**: add the `static const String` to `OmniFileExtensions`, add an `extensionToMimeType` entry (keyed by the constant, never a raw string), and add it to any category list it belongs to (in `constants.dart`, which is also where the per-platform `flutter*` / `videoPlayer*` lists live). Extensions are always passed *without* the leading `.` and compared lowercased; unknown extensions fall back to `application/octet-stream`. A few constant names must differ from their string because Dart identifiers cannot start with a digit — `sevenZ` = `7z`, `g3p` = `3gp`, `g3p2` = `3g2`.

### Web

The package builds for web (verified with `flutter build web`, Wasm dry run included). Network, memory and asset sources work everywhere; local is native-only.

**`dart:io` is confined to one file.** [lib/src/local_file/local_file_io.dart](lib/src/local_file/local_file_io.dart) and [lib/src/local_file/local_file_web.dart](lib/src/local_file/local_file_web.dart) are a conditional-export pair selected in [lib/src/local_file/local_file.dart](lib/src/local_file/local_file.dart) by

```dart
export 'local_file_web.dart' if (dart.library.io) 'local_file_io.dart';
```

They must expose an identical API — `supportsLocalFiles`, `currentPlatform`, `localFileLength`, `localFileBytes`, `localFileImageProvider`. **Nothing else in `lib/` may import `dart:io`.** Nothing enforces this: the analyzer only ever resolves the `dart.library.io` branch, so a stray `dart:io` import or an API drift between the two halves shows up as a *web build* failure, never as an analyze failure. Verify web-affecting changes by building a throwaway app against the package with a path dependency.

The web half throws `UnsupportedPlatformException` from `localFileLength`, `localFileBytes` and `localFileImageProvider`, so on web `size`, `imageProvider`, `OmniLocalFileBytesLoader.load` and `OmniLocalFileSizeLoader.load` throw rather than returning null. Constructing a local `OmniFile` on web is still fine — it's an inert descriptor; `isValid` returns `false` and `OmniFileSource.isSupported` is the cheap pre-check.

**Platform *detection* goes through that pair too.** `currentPlatform` (a `CurrentPlatform` enum) is `CurrentPlatform.fromOS(Platform.operatingSystem)` natively and always `.web` on web — it is *not* Flutter's `defaultTargetPlatform`, so it never reports the browser's host OS and ignores `debugDefaultTargetPlatformOverride`. `formatFileSize` and the platform-dependent lists in `OmniFileExtensions` read it. Those lists are `static final` and computed once on first access (the platform cannot change at runtime). Knock-on for tests: `currentPlatform` is the real host OS under `flutter_test`, so `formatFileSize` uses KB = 1024 on a Windows machine and 1000 elsewhere, and a test cannot fake another platform.

### Known rough edges

- `OmniAssetSizeLoader` / `OmniNetworkSizeLoader` swallow all failures into `null`, so a missing asset, an offline device and a server that omits `Content-Length` are indistinguishable through `OmniFile.size`; `OmniLocalFileSizeLoader` is the exception and lets `OmniFileNotFoundException` / `UnsupportedPlatformException` throw.
- `OmniAssetSizeLoader` has to load the whole asset to measure it — the bundle exposes no size-only API — so `size` on a big asset costs as much as reading it.
- `metadata` is `dynamic` and mutable — the only non-`final` field on an otherwise immutable descriptor. `rename()` carries it over via `newMetadata ?? metadata`, so it cannot be cleared.
- `rename()` reconstructs the object and drops `lastModified`. `lastModified` is declared but nothing in the package populates it.
- `mimeType` is computed from the raw `path` (`path?.split('.').last`) at construction, while `extension`, `imageProvider` and the predicates read `name`. A custom `name:`, `rename()`, or a URL with a query string therefore leaves `mimeType` as `application/octet-stream` while `extension` is correct. A nameless memory file has a `null` `extension`, so `imageProvider` is `null` until it is renamed.
- `extension` splits on the *last* dot and `nameWithoutExtension` on the *first*, so for `archive.tar.gz` they give `gz` and `archive`.
- The constructor only asserts `bytes != null || path != null`, not that the member matches the source, and `isValid` returns `true` whenever `bytes != null`. A mismatched file (network with only bytes, memory with only a path) is accepted and fails later with a null-check `TypeError` in the bytes loaders or `null` from the size loaders.
- `OmniMemoryBytesLoader.load()` is the one `load()` that is not `async`, so its source-mismatch `Exception` is thrown synchronously instead of surfacing as a failed `Future`.
- The network loader's `load()` / `stream()` throw a bare `Exception` on a non-200 response and on a source mismatch, rather than an `OmniFileException`.
