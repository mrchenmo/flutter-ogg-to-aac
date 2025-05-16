import 'dart:io';
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

  group('AAC Playback Test', () {
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

    testWidgets('Test playback of converted AAC file', (WidgetTester tester) async {
      // Thực hiện chuyển đổi
      print('Bắt đầu chuyển đổi OGG sang AAC...');
      final result = await FlutterOggToAac.convert(testOggPath, outputAacPath);
      print('Kết quả chuyển đổi: $result');

      // Kiểm tra file đã được tạo
      expect(await File(outputAacPath).exists(), true);

      // Tạo một widget để phát audio
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Audio Playback Test'),
            ),
          ),
        ),
      );

      // Tạo player
      final player = AudioPlayer();

      try {
        // Thiết lập file audio
        await player.setFilePath(outputAacPath);

        // Lấy thông tin về file audio
        final duration = await player.duration;
        print('Thời lượng audio: ${duration?.inMilliseconds ?? 0} ms');
        expect(duration, isNotNull);
        expect(duration!.inMilliseconds, greaterThan(0));

        // Phát audio
        print('Bắt đầu phát audio...');
        await player.play();

        // Đợi một khoảng thời gian để nghe audio
        await Future.delayed(Duration(seconds: 2));

        // Kiểm tra trạng thái phát
        expect(player.playing, true);

        // Kiểm tra vị trí phát
        final position = await player.position;
        print('Vị trí phát: ${position.inMilliseconds} ms');
        expect(position.inMilliseconds, greaterThan(0));

        // Dừng phát
        await player.pause();
        print('Đã dừng phát audio');

        // Kiểm tra trạng thái sau khi dừng
        expect(player.playing, false);

        print('Test phát audio thành công');
      } catch (e) {
        print('Lỗi khi phát audio: $e');
        fail('Không thể phát file AAC: $e');
      } finally {
        // Dọn dẹp
        await player.dispose();
      }
    });

    testWidgets('Test seeking in AAC file', (WidgetTester tester) async {
      // Kiểm tra file đã được tạo
      if (!await File(outputAacPath).exists()) {
        // Thực hiện chuyển đổi nếu file chưa tồn tại
        await FlutterOggToAac.convert(testOggPath, outputAacPath);
      }

      expect(await File(outputAacPath).exists(), true);

      // Tạo một widget để phát audio
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Audio Seeking Test'),
            ),
          ),
        ),
      );

      // Tạo player
      final player = AudioPlayer();

      try {
        // Thiết lập file audio
        await player.setFilePath(outputAacPath);

        // Lấy thông tin về file audio
        final duration = await player.duration;
        print('Thời lượng audio: ${duration?.inMilliseconds ?? 0} ms');
        expect(duration, isNotNull);

        // Tính toán vị trí seek (50% thời lượng)
        final seekPosition = Duration(milliseconds: (duration!.inMilliseconds * 0.5).round());
        print('Vị trí seek: ${seekPosition.inMilliseconds} ms');

        // Seek đến vị trí
        await player.seek(seekPosition);

        // Kiểm tra vị trí sau khi seek
        final position = await player.position;
        print('Vị trí sau khi seek: ${position.inMilliseconds} ms');

        // Cho phép một chút sai số trong việc seek
        expect(
          position.inMilliseconds,
          closeTo(seekPosition.inMilliseconds, 500), // Cho phép sai số 500ms
        );

        // Phát một đoạn ngắn từ vị trí seek
        await player.play();
        await Future.delayed(Duration(seconds: 1));
        await player.pause();

        print('Test seek thành công');
      } catch (e) {
        print('Lỗi khi test seek: $e');
        fail('Không thể seek trong file AAC: $e');
      } finally {
        // Dọn dẹp
        await player.dispose();
      }
    });
  });
}
