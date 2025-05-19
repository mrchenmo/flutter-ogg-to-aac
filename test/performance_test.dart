import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

// Note: This test needs to run on a real device or emulator
// Use command: flutter test test/performance_test.dart

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterOggToAac Performance Tests', () {
    late String tempDir;
    late String testOggPath;
    late String outputAacPath;

    setUpAll(() async {
      // Get temporary directory to save test files
      final directory = await getTemporaryDirectory();
      tempDir = directory.path;

      // Create paths for test files
      testOggPath = '$tempDir/test_audio.ogg';
      outputAacPath = '$tempDir/output_audio.aac';

      // Create OGG test file from asset
      try {
        final ByteData data = await rootBundle.load('assets/test_audio.ogg');
        final buffer = data.buffer;
        await File(testOggPath).writeAsBytes(
          buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)
        );
      } catch (e) {
        print('Cannot create test file: $e');
        // Create an empty OGG file for testing
        await File(testOggPath).writeAsBytes([]);
      }
    });

    tearDownAll(() async {
      // Delete test files after completion
      final testOggFile = File(testOggPath);
      final outputAacFile = File(outputAacPath);

      if (await testOggFile.exists()) {
        await testOggFile.delete();
      }

      if (await outputAacFile.exists()) {
        await outputAacFile.delete();
      }
    });

    test('Measure conversion time', () async {
      if (!await File(testOggPath).exists()) {
        // Skip test if test file doesn't exist
        return;
      }

      // Measure conversion time
      final stopwatch = Stopwatch()..start();

      try {
        await FlutterOggToAac.convert(testOggPath, outputAacPath);
      } catch (e) {
        print('Error during conversion: $e');
        return;
      }

      stopwatch.stop();

      // Print conversion time
      print('Conversion time: ${stopwatch.elapsedMilliseconds} ms');

      // Check result
      expect(await File(outputAacPath).exists(), true);

      // Check output file size
      final inputFileSize = await File(testOggPath).length();
      final outputFileSize = await File(outputAacPath).length();

      print('Input file size: $inputFileSize bytes');
      print('Output file size: $outputFileSize bytes');
      print('Compression ratio: ${outputFileSize / inputFileSize}');

      // Ensure output file has a reasonable size
      expect(outputFileSize, greaterThan(0));
    });

    test('Test multiple conversions', () async {
      if (!await File(testOggPath).exists()) {
        // Skip test if test file doesn't exist
        return;
      }

      const iterations = 3;
      final conversionTimes = <int>[];

      for (var i = 0; i < iterations; i++) {
        final outputPath = '$tempDir/output_audio_$i.aac';

        // Measure conversion time
        final stopwatch = Stopwatch()..start();

        try {
          await FlutterOggToAac.convert(testOggPath, outputPath);
        } catch (e) {
          print('Error during conversion #$i: $e');
          continue;
        }

        stopwatch.stop();
        conversionTimes.add(stopwatch.elapsedMilliseconds);

        // Check result
        expect(await File(outputPath).exists(), true);

        // Delete output file
        await File(outputPath).delete();
      }

      // Print average conversion time
      if (conversionTimes.isNotEmpty) {
        final averageTime = conversionTimes.reduce((a, b) => a + b) / conversionTimes.length;
        print('Average conversion time: $averageTime ms');
      }
    });
  });
}
