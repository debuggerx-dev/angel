# Mustache View Template for Angel3

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_mustache?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/mustache/LICENSE)

A service that renders Mustache template into HTML view for [Angel3](https://angel3-framework.web.app/) framework.

Thanks so much @c4wrd for his help with bringing this project to life!

## Installation

In `pubspec.yaml`:

```yaml
dependencies:
    angel3_mustache: ^3.1.0
```

## Usage

```dart
const FileSystem fs = const LocalFileSystem();

configureServer(Angel app) async {
  // Run the plug-in
  await app.configure(mustache(fs.directory('views')));
  
  // Render `hello.mustache`
  await res.render('hello', {'name': 'world'});
}
```

@# Options

- **partialsPath**: A path within the viewsDirectory to search for partials in.
    Default is `./partials`.
- **fileExtension**: The file extension to search for. Default is `.mustache`.
