/// The `dart:io`-backed half of the local-file abstraction.
///
/// This is the only library in the package allowed to import `dart:io`.
/// Nothing imports it directly: `local_file.dart` conditionally exports it
/// where `dart:io` exists, and `local_file_web.dart` in its place on web.
/// Both halves must keep exactly the same public API — see `local_file.dart`
/// for why nothing catches it when they drift.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';

import '../enums.dart';
import '../exceptions.dart';

/// Whether the current platform can read files from a local filesystem.
///
/// `false` on web, `true` everywhere else.
const bool supportsLocalFiles = true;

/// The platform the app is running on, read from `Platform.operatingSystem`.
///
/// This is the real host OS — it ignores `debugDefaultTargetPlatformOverride`,
/// so tests cannot fake another platform through it.
final currentPlatform = CurrentPlatform.fromOS(Platform.operatingSystem);

/// The size in bytes of the file at [path].
///
/// Throws [OmniFileNotFoundException] if nothing is there.
Future<int> localFileLength(String path) async {
  final file = File(path);
  if (!await file.exists()) throw OmniFileNotFoundException(path);

  return file.length();
}

/// Reads the whole file at [path] into memory.
///
/// Throws [OmniFileNotFoundException] if nothing is there.
Future<Uint8List> localFileBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) throw OmniFileNotFoundException(path);

  return file.readAsBytes();
}

/// An [ImageProvider] that decodes the file at [path].
///
/// Existence is not checked here — a missing file surfaces as an image loading
/// error when the provider is resolved.
ImageProvider localFileImageProvider(String path) => FileImage(File(path));
