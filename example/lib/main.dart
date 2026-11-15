import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:omnifile/omnifile.dart';

void main() => runApp(const OmniFileExampleApp());

class OmniFileExampleApp extends StatelessWidget {
  const OmniFileExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'omnifile example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 1. Network: a URL string becomes a descriptor with `.networkFile`.
  final OmniFile _network =
      'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg'
          .networkFile;

  /// 2. Asset: an asset key declared in `pubspec.yaml`.
  final OmniFile _asset = 'assets/notes.txt'.assetFile;

  /// 3. Memory: bytes you already have. They carry no name, so give them one
  /// with `rename()` to get an extension and a MIME-derived type.
  final OmniFile _memory = Uint8List.fromList(
    utf8.encode('{"hello": "from memory"}'),
  ).memoryFile.rename('greeting.json');

  /// 4. Local: any filesystem path. Native only — on web the descriptor is
  /// inert and reading it throws `UnsupportedPlatformException`.
  final _pathController = TextEditingController();
  OmniFile? _local;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('omnifile example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FileCard(title: 'Network file', file: _network),
          FileCard(title: 'Asset file', file: _asset),
          FileCard(title: 'Memory file', file: _memory),
          _buildLocalCard(),
        ],
      ),
    );
  }

  Widget _buildLocalCard() {
    if (!OmniFileSource.local.isSupported) {
      return const Card(
        child: ListTile(
          title: Text('Local file'),
          subtitle: Text(
            'Not supported on this platform (web has no filesystem). '
            'OmniFileSource.local.isSupported is false.',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: 'Local file path',
                      hintText: r'C:\Users\me\Pictures\photo.png',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    final path = _pathController.text.trim();
                    setState(
                      () => _local = path.isEmpty ? null : path.localFile,
                    );
                  },
                  child: const Text('Inspect'),
                ),
              ],
            ),
          ),
        ),
        if (_local != null)
          // The key makes the card rebuild when the path changes.
          FileCard(
            key: ValueKey(_local!.path),
            title: 'Local file',
            file: _local!,
          ),
      ],
    );
  }
}

/// Shows everything [OmniFile] knows about a file, and lets you read it.
class FileCard extends StatefulWidget {
  const FileCard({super.key, required this.title, required this.file});

  final String title;
  final OmniFile file;

  @override
  State<FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<FileCard> {
  late final Future<String?> _size = widget.file.formattedSize;
  String _result = '';
  double? _progress;

  OmniFile get file => widget.file;

  /// Reads the whole file with the loader matching its source.
  Future<void> _load() async {
    setState(() => _result = 'Loading...');
    try {
      final bytes = await OmniBytesLoader.fromFile(file).load();
      final preview = _isText(file.extension)
          ? '\n${utf8.decode(bytes, allowMalformed: true)}'
          : '';
      setState(() => _result = 'Loaded ${bytes.length} bytes.$preview');
    } catch (e) {
      // Network/asset failures are bare Exceptions; local failures are
      // OmniFileExceptions (not found / unsupported platform).
      setState(() => _result = 'Failed: $e');
    }
  }

  /// Streams the file, reporting progress as chunks arrive.
  Future<void> _stream() async {
    setState(() {
      _result = '';
      _progress = 0;
    });
    try {
      final total = await file.size;
      final stream = await OmniBytesLoader.fromFile(file).stream();
      var received = 0;
      await for (final chunk in stream) {
        received += chunk.length;
        if (total != null && total > 0) {
          setState(() => _progress = received / total);
        }
      }
      setState(() => _result = 'Streamed $received bytes.');
    } catch (e) {
      setState(() => _result = 'Failed: $e');
    } finally {
      setState(() => _progress = null);
    }
  }

  bool _isText(String? ext) =>
      const {'txt', 'json', 'md', 'csv'}.contains(ext?.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Null for anything Flutter can't decode (txt, pdf, svg, ...), and throws
    // for local files on web, so only ask when the source is supported.
    final image = file.source.isSupported ? file.imageProvider : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _row('source', file.source.name),
            _row('name', file.name ?? '—'),
            _row('extension', file.extension ?? '—'),
            _row('mimeType', file.mimeType),
            _row('isValid', '${file.isValid}'),
            _row(
              'category',
              [
                if (OmniFileUtils.isImage(file.extension)) 'image',
                if (OmniFileUtils.isVideo(file.extension)) 'video',
                if (OmniFileUtils.isAudio(file.extension)) 'audio',
                if (OmniFileUtils.isArchive(file.extension)) 'archive',
              ].join(', ').ifEmpty('other'),
            ),
            FutureBuilder<String?>(
              future: _size,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _row('size', 'error: ${snapshot.error}');
                }
                return _row(
                  'size',
                  snapshot.connectionState == ConnectionState.done
                      ? snapshot.data ?? 'unknown'
                      : '...',
                );
              },
            ),
            if (image != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(image: image, height: 160, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _load,
                  child: const Text('Load bytes'),
                ),
                if (file.source.isNetwork)
                  OutlinedButton(
                    onPressed: _stream,
                    child: const Text('Stream'),
                  ),
              ],
            ),
            if (_progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _progress),
            ],
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_result),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
