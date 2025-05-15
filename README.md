# Flutter OGG to AAC

A Flutter plugin to convert audio files from OGG format to AAC without using FFMPEG.

## Features

- Convert audio files from OGG format to AAC
- Use native platform APIs (MediaCodec on Android, AVAudioConverter on iOS)
- No dependency on FFMPEG
- Lightweight and efficient conversion process

## Installation

Add the plugin to your project's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_ogg_to_aac: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Usage

```dart
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';

// Convert OGG file to AAC
try {
  String? outputPath = await FlutterOggToAac.convert(
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

## Third-Party Libraries

This plugin uses the following third-party libraries:

### libogg (v1.3.5)
- **License**: BSD 3-Clause License
- **Copyright**: Copyright (c) 2002, Xiph.org Foundation
- **Website**: https://xiph.org/ogg/
- **Purpose**: Provides the file format and bitstream container for Ogg audio files

### libvorbis (v1.3.7)
- **License**: BSD 3-Clause License
- **Copyright**: Copyright (c) 2002-2020, Xiph.org Foundation
- **Website**: https://xiph.org/vorbis/
- **Purpose**: Provides the decoder for Ogg Vorbis audio format

### MediaCodec (Android)
- **License**: Apache License 2.0
- **Copyright**: Copyright (c) The Android Open Source Project
- **Website**: https://developer.android.com/reference/android/media/MediaCodec
- **Purpose**: Native Android API for audio/video encoding and decoding

### AVAudioConverter (iOS)
- **License**: Apple iOS SDK License Agreement
- **Copyright**: Copyright (c) Apple Inc.
- **Website**: https://developer.apple.com/documentation/avfaudio/avaudioconverter
- **Purpose**: Native iOS API for audio format conversion

## License

This plugin is released under the MIT license.

```
MIT License

Copyright (c) 2023 nmtuong

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## License Compliance

When using this plugin in your application, you must comply with the license terms of all the third-party libraries mentioned above. This includes:

1. For **libogg** and **libvorbis** (BSD 3-Clause License):
   - Retain the copyright notice, list of conditions, and disclaimer in your documentation
   - Do not use the names of Xiph.org Foundation or its contributors to endorse your product without permission

2. For **MediaCodec** (Apache License 2.0):
   - Include a copy of the Apache License in your application
   - Indicate if you've modified any files from the original library

3. For **AVAudioConverter** (Apple iOS SDK License):
   - Comply with Apple's iOS SDK License Agreement
   - Only use in applications distributed through the App Store or as otherwise permitted by Apple

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Issues and Feedback

Please file issues and feedback using the [GitHub issue tracker](https://github.com/yourusername/flutter_ogg_to_aac/issues).
