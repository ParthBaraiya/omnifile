/// The exceptions this package throws, without a `dart:io` import in sight.
///
/// [OmniFileException] is the base type; catch it to cover both
/// [UnsupportedPlatformException] and [OmniFileNotFoundException] at once.
library;

/// Base class for every exception thrown by `omnifile`.
///
/// Catching this type covers both the "this platform can't do that"
/// ([UnsupportedPlatformException]) and the "the file isn't there"
/// ([OmniFileNotFoundException]) cases without importing `dart:io`, so
/// the same `catch` works on web and on native.
abstract class OmniFileException implements Exception {
  /// What went wrong, in a form fit for a log line.
  final String message;

  /// The path of the file the operation was attempted on, when there is one.
  final String? path;

  /// Creates an exception describing [message], optionally about [path].
  const OmniFileException(this.message, {this.path});

  /// `RuntimeType: message (path)`, with the path omitted when there is none.
  @override
  String toString() {
    final where = path == null ? '' : ' ($path)';
    return '$runtimeType: $message$where';
  }
}

/// Thrown when an operation cannot be performed on the current platform.
///
/// In practice this means touching an `OmniFileSource.local` file on the
/// web, where there is no filesystem to read from. Network, memory and asset
/// files work everywhere.
class UnsupportedPlatformException extends OmniFileException {
  /// Creates the exception; [message] should name the operation that is
  /// unavailable.
  const UnsupportedPlatformException(super.message, {super.path});
}

/// Thrown when an `OmniFileSource.local` file does not exist on disk.
class OmniFileNotFoundException extends OmniFileException {
  /// Creates the exception for the file at [path], which was not there.
  const OmniFileNotFoundException(String path)
    : super('Local file not found', path: path);
}
