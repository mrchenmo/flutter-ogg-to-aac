import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AAC Format Validation Tests', () {
    late String tempDir;
    late String testOggPath;
    late String outputAacPath;

    setUpAll(() async {
      // Lấy thư mục tạm để lưu file test
      final directory = await getTemporaryDirectory();
      tempDir = directory.path;

      // Tạo đường dẫn cho file test
      testOggPath = '$tempDir/test_audio.ogg';
      outputAacPath = '$tempDir/output_audio.aac';

      // Tạo file OGG test từ asset
      try {
        final ByteData data = await rootBundle.load('assets/sample.ogg');
        final buffer = data.buffer;
        await File(testOggPath).writeAsBytes(
          buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)
        );

        print('Đã tạo file test OGG: $testOggPath');
        print('Kích thước file: ${await File(testOggPath).length()} bytes');
      } catch (e) {
        print('Không thể tạo file test: $e');
        fail('Không thể tạo file test: $e');
      }
    });

    tearDownAll(() async {
      // Xóa các file test sau khi hoàn thành
      final testOggFile = File(testOggPath);
      final outputAacFile = File(outputAacPath);

      if (await testOggFile.exists()) {
        await testOggFile.delete();
      }

      if (await outputAacFile.exists()) {
        await outputAacFile.delete();
      }
    });

    testWidgets('Verify AAC file format after conversion', (WidgetTester tester) async {
      // Kiểm tra file OGG test đã được tạo
      expect(await File(testOggPath).exists(), true);

      // Thực hiện chuyển đổi
      print('Bắt đầu chuyển đổi OGG sang AAC...');
      final stopwatch = Stopwatch()..start();

      final result = await FlutterOggToAac.convert(testOggPath, outputAacPath);

      stopwatch.stop();
      print('Thời gian chuyển đổi: ${stopwatch.elapsedMilliseconds} ms');

      // Kiểm tra kết quả
      print('Kết quả chuyển đổi: $result');
      expect(result, isNotNull);
      expect(await File(outputAacPath).exists(), true);

      // Kiểm tra kích thước file
      final fileSize = await File(outputAacPath).length();
      print('Kích thước file AAC: $fileSize bytes');
      expect(fileSize, greaterThan(0));

      // Kiểm tra header của file AAC
      final bytes = await File(outputAacPath).readAsBytes();
      print('Kiểm tra header của file AAC...');

      // Phương pháp 1: Kiểm tra header AAC/ADTS hoặc MP4 container
      bool isValidAacFormat = false;

      // Kiểm tra ADTS header (AAC raw format)
      if (bytes.length >= 2) {
        // ADTS header bắt đầu với 0xFF 0xF1 hoặc 0xFF 0xF9
        if (bytes[0] == 0xFF && (bytes[1] & 0xF0) == 0xF0) {
          print('File có ADTS header hợp lệ (AAC raw format)');
          isValidAacFormat = true;
        }
      }

      // Kiểm tra MP4/M4A container (AAC trong container)
      if (bytes.length >= 8) {
        // Kiểm tra các box MP4 phổ biến như 'ftyp'
        final boxType = String.fromCharCodes(bytes.sublist(4, 8));
        if (boxType == 'ftyp') {
          print('File có MP4/M4A container hợp lệ (box type: $boxType)');
          isValidAacFormat = true;
        }
      }

      // In ra các byte đầu tiên để debug
      if (!isValidAacFormat) {
        final headerBytes = bytes.length >= 16 ? bytes.sublist(0, 16) : bytes;
        print('Header bytes: ${headerBytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      }

      // Phương pháp 2: Thử phát file bằng just_audio
      print('Thử phát file AAC để xác nhận định dạng...');
      try {
        final player = AudioPlayer();
        await player.setFilePath(outputAacPath);

        // Lấy thông tin về file audio
        final duration = await player.duration;
        print('Thời lượng audio: ${duration?.inMilliseconds ?? 0} ms');

        // Nếu có thể lấy được thời lượng, file có thể phát được
        expect(duration, isNotNull);
        expect(duration!.inMilliseconds, greaterThan(0));

        // Dọn dẹp
        await player.dispose();

        print('File AAC có thể phát được, định dạng hợp lệ');
        isValidAacFormat = true;
      } catch (e) {
        print('Không thể phát file AAC: $e');
      }

      // Kết luận về định dạng file
      expect(isValidAacFormat, true, reason: 'File AAC không có định dạng hợp lệ');
    });
  });
}
