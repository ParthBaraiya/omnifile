/// The `dart:io`-free half of the local-file abstraction.
///
/// This is the half `local_file.dart` exports when `dart:io` is unavailable
/// (web). Every entry point throws [UnsupportedPlatformException]; see
/// `local_file_io.dart` for the implementation used everywhere else. Both
/// halves must keep exactly the same public API — see `local_file.dart` for
/// why nothing catches it when they drift.
library;

import 'dart:typed_data';

import 'package:flutter/painting.dart';

import '../enums.dart';
import '../exceptions.dart';

/// Whether the current platform can read files from a local filesystem.
///
/// `false` on web, `true` everywhere else. Guard on this (or on
/// `OmniFileSource.isSupported`) instead of catching
/// [UnsupportedPlatformException] when you can branch ahead of time.
const bool supportsLocalFiles = false;

/// Always [CurrentPlatform.web]: this half is only compiled where `dart:io` is
/// unavailable, and the browser's host OS is deliberately not consulted.
final currentPlatform = CurrentPlatform.web;

/// Throws the [UnsupportedPlatformException] describing [operation] on [path].
Never _unsupported(String operation, String path) {
  throw UnsupportedPlatformException(
    '$operation is not supported on this platform: there is no local '
    'filesystem to read from',
    path: path,
  );
}

/// The size in bytes of the file at [path] — always throws
/// [UnsupportedPlatformException] here.
Future<int> localFileLength(String path) async =>
    _unsupported('Reading the size of a local file', path);

/// Reads the whole file at [path] into memory — always throws
/// [UnsupportedPlatformException] here.
Future<Uint8List> localFileBytes(String path) async =>
    _unsupported('Reading the bytes of a local file', path);

/// An [ImageProvider] for the file at [path] — always throws
/// [UnsupportedPlatformException] here.
ImageProvider localFileImageProvider(String path) =>
    _unsupported('Displaying a local file as an image', path);
