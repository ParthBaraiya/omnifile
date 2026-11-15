# omnifile example

A small app showing the four kinds of `OmniFile`:

| Source  | Built with                          | Demonstrates                                    |
| ------- | ----------------------------------- | ----------------------------------------------- |
| network | `'https://…/owl.jpg'.networkFile`   | metadata, `size` via HEAD, image preview, streaming with progress |
| asset   | `'assets/notes.txt'.assetFile`      | reading through the asset bundle                |
| memory  | `bytes.memoryFile.rename('x.json')` | naming nameless bytes                           |
| local   | `path.localFile` (type a path)      | native-only source; hidden on web via `isSupported` |

Every card shows `name`, `extension`, `mimeType`, `isValid`, a category from
`OmniFileUtils`, the formatted `size`, an `imageProvider` preview when Flutter
can decode the file, and buttons for `OmniBytesLoader.load()` / `stream()`.

```sh
cd example
flutter pub get
flutter run
```
