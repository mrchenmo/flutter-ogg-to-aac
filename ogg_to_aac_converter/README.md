# OGG to AAC Converter

A Flutter plugin to convert audio files from OGG format to AAC without using FFMPEG.

## Features

- Convert audio files from OGG format to AAC
- Use native platform APIs (MediaCodec on Android, AVAudioConverter on iOS)
- No dependency on FFMPEG

## Installation

Add the plugin to your project's `pubspec.yaml` file:

```yaml
dependencies:
  ogg_to_aac_converter: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Usage

```dart
import 'package:ogg_to_aac_converter/ogg_to_aac_converter.dart';

// Convert OGG file to AAC
try {
  String? outputPath = await OggToAacConverter.convert(
    '/path/to/input.ogg',
    '/path/to/output.aac'
  );

  if (outputPath != null) {
    print('Conversion successful: $outputPath');
  }
} catch (e) {
  print('Error during conversion: $e');
}
```

## How it works

### Android

1. Uses libogg/libvorbis to decode OGG file to PCM
2. Uses MediaCodec to encode PCM to AAC

### iOS

1. Uses libogg/libvorbis to decode OGG file to PCM
2. Uses AVAudioConverter to encode PCM to AAC

## Requirements

- Android: API 21+
- iOS: 12.0+

## License

This plugin is released under the MIT license.
