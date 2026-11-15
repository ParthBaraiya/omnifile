/// The loaders that turn an [OmniFile] descriptor into actual bytes.
///
/// [OmniBytesLoader] is the shared interface, with one implementation per
/// [OmniFileSource]. Call [OmniBytesLoader.fromFile] and let it pick;
/// the concrete classes are public mostly so they can be named in tests and
/// type annotations.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:omnifile/omnifile.dart';

/// Reads the bytes of an [OmniFile], whichever source it came from.
///
/// ```dart
/// final loader = OmniBytesLoader.fromFile(file);
/// final bytes = await loader.load();
/// ```
///
/// Use [fromFile] rather than picking a subclass by hand: each subclass
/// re-checks `file.source` and throws if it was handed a file it cannot read.
abstract class OmniBytesLoader {
  /// The file this loader reads.
  final OmniFile file;

  /// Binds a loader to [file]; prefer [fromFile], which picks the right
  /// subclass for you.
  const OmniBytesLoader(this.file);

  /// Loads the file bytes from its respective source.
  ///
  /// Every implementation reads whichever member its source implies —
  /// [OmniFile.path] for network, asset and local files, [OmniFile.bytes] for
  /// memory ones — and asserts it with `!`. A file built without the member its
  /// source needs therefore fails with a null-check [TypeError], not an
  /// [OmniFileException]; the size loaders answer `null` in the same situation.
  Future<List<int>> load();

  /// Loads the file bytes as a stream.
  ///
  /// Only [OmniNetworkBytesLoader] streams for real, and it is also the only
  /// one that returns a broadcast stream — one you can listen to more than
  /// once, and one that is shared between concurrent calls. The other loaders
  /// have nothing to stream from, so they read everything through [load] and
  /// emit it as a single event on a single-subscription stream.
  Future<Stream<List<int>>> stream();

  /// The file's size in bytes, or `null` if it cannot be determined.
  ///
  /// Straight through to [OmniFile.size], including its caching and its
  /// per-source error behaviour. Use [OmniSizeLoader.fromFile] instead when
  /// you want the measurement without the descriptor's cache.
  Future<int?> get size => file.size;

  /// Returns the loader that can read [file], chosen by its
  /// [OmniFile.source].
  static OmniBytesLoader fromFile(OmniFile file) {
    return switch (file.source) {
      .network => OmniNetworkBytesLoader(file),
      .memory => OmniMemoryBytesLoader(file),
      .asset => OmniAssetBytesLoader(file),
      .local => OmniLocalFileBytesLoader(file),
    };
  }
}

/// Downloads files over HTTP, using [OmniFile.path] as the URL.
///
/// The only loader that streams for real, which makes it the one to use for
/// large downloads or progress reporting. Both [load] and [stream] throw a
/// plain [Exception] if the response status is not 200.
///
/// Unlike its siblings this loader is stateful, and it holds one invariant: a
/// single instance never has more than one download running. [stream] opens a
/// download only when it has none live, and every call made until that one
/// ends hands back the very same stream. Keep the instance around rather than
/// calling [OmniBytesLoader.fromFile] again per listener — a fresh loader has
/// nothing cached, so it opens a request of its own.
class OmniNetworkBytesLoader extends OmniBytesLoader {
  /// Binds this loader to an [OmniFileSource.network] file.
  OmniNetworkBytesLoader(super.file);

  /// The live download [stream] shares, or `null` when none is running.
  Future<Stream<List<int>>>? _pendingStream;

  /// Tags the current download so that one which has ended can only ever drop
  /// its own [_pendingStream] entry, never a newer download's.
  int _generation = 0;

  /// Fetches the whole response body into memory with a single `GET`.
  @override
  Future<List<int>> load() async {
    if (file.source != .network) {
      throw Exception("File source is not network");
    }

    final uri = Uri.parse(file.path!);

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load network file (${file.name}): '
        '${response.statusCode}',
      );
    }

    return response.bodyBytes;
  }

  /// Streams the response body as it arrives, without buffering it all.
  ///
  /// The returned stream is a broadcast stream, so it accepts any number of
  /// listeners. Chunks only start flowing once the first listener arrives, and
  /// they are never replayed: a listener that subscribes later joins mid-body
  /// and misses everything already delivered. Subscribe every listener in the
  /// same turn — or use [load] — when each of them needs the whole file.
  ///
  /// Every call made while a download is live returns that download: the same
  /// stream object, and one single request for all of them. It makes no
  /// difference whether the download has been listened to yet, is halfway
  /// through the body, or was only just opened by a caller still awaiting this
  /// future — there is one, so that is what you get.
  ///
  /// A download stays live until it ends, and it ends in exactly one of four
  /// ways: the body finishes, the wire errors, the response was not a 200, or
  /// the last subscription is cancelled. Whichever it is, the [http.Client] is
  /// closed once and the cache is dropped in the same breath, so the *next*
  /// call — and only a call made after that point — opens a fresh download and
  /// caches that one instead. An ended stream stays ended: listening to it
  /// again yields nothing, so ask for a new one.
  ///
  /// One leak survives all of this: awaiting [stream] and never listening
  /// leaves the request open, because nothing owns the response until the
  /// first subscription arrives.
  @override
  Future<Stream<List<int>>> stream() async {
    if (file.source != .network) {
      throw Exception("File source is not network");
    }

    final live = _pendingStream;
    if (live != null) return live;

    // Cache the attempt before handing it out. `_openStream` only reaches its
    // first `await` after this assignment, so a caller arriving in the
    // meantime joins this download instead of opening a second one.
    final generation = ++_generation;
    final opening = _openStream(generation);
    _pendingStream = opening;

    // A request that never yields a stream leaves nothing live, so let the
    // next caller retry. This has to live out here: a failure inside
    // `_openStream` before its first `await` would otherwise clear the cache
    // before the assignment above had even happened, and cache the failure
    // for good.
    unawaited(
      opening.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) => _release(generation),
      ),
    );

    return opening;
  }

  /// Sends the request and wraps the response in the shared stream, closing
  /// the client if the download never starts.
  Future<Stream<List<int>>> _openStream(int generation) async {
    final client = http.Client();

    try {
      final request = http.Request('GET', Uri.parse(file.path!));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load network file (${file.name}): '
          '${response.statusCode}',
        );
      }

      return _shareStream(generation, client, response.stream);
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  /// Fans [source] out to any number of listeners, owning [client] until the
  /// download ends.
  Stream<List<int>> _shareStream(
    int generation,
    http.Client client,
    Stream<List<int>> source,
  ) {
    late final StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    var finished = false;

    Future<void> finish() async {
      if (finished) return;
      finished = true;

      // Free the cache first, so a listener that starts a new download from
      // its own onDone gets a fresh one instead of this dead stream.
      _release(generation);

      final pending = subscription;
      subscription = null;
      await pending?.cancel();
      client.close();

      if (!controller.isClosed) await controller.close();
    }

    controller = StreamController<List<int>>.broadcast(
      // The response is single-subscription, so it is pumped exactly once, and
      // only once somebody is listening — otherwise the first chunks would be
      // dropped before the caller could subscribe.
      onListen: () {
        subscription ??= source.listen(
          (chunk) {
            if (!finished) controller.add(chunk);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!finished) controller.addError(error, stackTrace);
            finish();
          },
          onDone: finish,
          cancelOnError: true,
        );
      },
      // Fired when the last listener cancels: the download has nowhere left to
      // go, so abort it rather than pumping bytes into the void.
      onCancel: finish,
    );

    return controller.stream;
  }

  /// Forgets the download of [generation] so the next [stream] call opens a
  /// new one — unless a newer download has already taken its place, in which
  /// case that one is still live and stays cached.
  void _release(int generation) {
    if (_generation == generation) _pendingStream = null;
  }
}

/// Loads files from the local filesystem.
///
/// Not available on web: both [load] and [stream] throw an
/// [UnsupportedPlatformException] there. If the path does not exist on a
/// platform that does have a filesystem, they throw an
/// [OmniFileNotFoundException] instead.
class OmniLocalFileBytesLoader extends OmniBytesLoader {
  /// Binds this loader to an [OmniFileSource.local] file.
  const OmniLocalFileBytesLoader(super.file);

  /// Reads the whole file off disk.
  @override
  Future<List<int>> load() async {
    if (file.source != .local) {
      throw Exception("File source is not local");
    }

    return localFileBytes(file.path!);
  }

  /// Reads the file through [load] and emits it as a single event.
  ///
  /// Not a real stream — the whole file is in memory before the first event.
  @override
  Future<Stream<List<int>>> stream() async {
    return load().asStream();
  }
}

/// Hands back the bytes an [OmniFileSource.memory] file already carries.
///
/// Nothing is read or copied; this exists so in-memory files can travel the
/// same code path as the rest.
class OmniMemoryBytesLoader extends OmniBytesLoader {
  /// Binds this loader to an [OmniFileSource.memory] file.
  OmniMemoryBytesLoader(super.file);

  /// Completes immediately with [OmniFile.bytes].
  @override
  Future<List<int>> load() {
    if (file.source != .memory) {
      throw Exception("File source is not memory");
    }

    return Future.value(file.bytes!);
  }

  /// Emits [OmniFile.bytes] as a single event.
  ///
  /// Not a real stream — the bytes were in memory to begin with.
  @override
  Future<Stream<List<int>>> stream() async {
    return load().asStream();
  }
}

/// Loads files bundled with the app, through Flutter's [rootBundle].
///
/// [OmniFile.path] is the asset key. Both [load] and [stream] throw
/// whatever the bundle throws — a [FlutterError] — when the key is not in the
/// bundle.
class OmniAssetBytesLoader extends OmniBytesLoader {
  /// Binds this loader to an [OmniFileSource.asset] file.
  const OmniAssetBytesLoader(super.file);

  /// Reads the asset out of the bundle.
  @override
  Future<List<int>> load() async {
    if (file.source != .asset) {
      throw Exception("File source is not asset");
    }

    final data = await rootBundle.load(file.path!);
    return data.buffer.asUint8List();
  }

  /// Reads the asset through [load] and emits it as a single event.
  ///
  /// Not a real stream — the bundle hands over the whole asset at once.
  @override
  Future<Stream<List<int>>> stream() async {
    return load().asStream();
  }
}
