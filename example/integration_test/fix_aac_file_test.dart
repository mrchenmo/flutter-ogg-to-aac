import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Fix AAC File Tests', () {
    late String tempDir;
    late String testOggPath;
    late String outputAacPath;
    late String fixedAacPath;

    setUpAll(() async {
      // Lấy thư mục tạm để lưu file test
      final directory = await getTemporaryDirectory();
      tempDir = directory.path;
      
      // Tạo đường dẫn cho file test
      testOggPath = '$tempDir/test_audio.ogg';
      outputAacPath = '$tempDir/output_audio.aac';
      fixedAacPath = '$tempDir/fixed_audio.aac';
      
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
      final fixedAacFile = File(fixedAacPath);
      
      if (await testOggFile.exists()) {
        await testOggFile.delete();
      }
      
      if (await outputAacFile.exists()) {
        await outputAacFile.delete();
      }
      
      if (await fixedAacFile.exists()) {
        await fixedAacFile.delete();
      }
    });

    testWidgets('Fix AAC file by removing invalid header', (WidgetTester tester) async {
      // Thực hiện chuyển đổi
      print('Bắt đầu chuyển đổi OGG sang AAC...');
      final result = await FlutterOggToAac.convert(testOggPath, outputAacPath);
      print('Kết quả chuyển đổi: $result');
      
      // Kiểm tra file đã được tạo
      expect(await File(outputAacPath).exists(), true);
      
      // Đọc file AAC
      final bytes = await File(outputAacPath).readAsBytes();
      print('Kích thước file AAC: ${bytes.length} bytes');
      
      // Tìm kiếm ADTS header
      int adtsHeaderPosition = -1;
      for (int i = 0; i < bytes.length - 2; i++) {
        if (bytes[i] == 0xFF && (bytes[i + 1] & 0xF0) == 0xF0) {
          adtsHeaderPosition = i;
          break;
        }
      }
      
      if (adtsHeaderPosition >= 0) {
        print('Tìm thấy ADTS header tại vị trí $adtsHeaderPosition');
        
        // Tạo file AAC mới bắt đầu từ ADTS header
        final fixedBytes = bytes.sublist(adtsHeaderPosition);
        await File(fixedAacPath).writeAsBytes(fixedBytes);
        
        print('Đã tạo file AAC đã sửa: $fixedAacPath');
        print('Kích thước file AAC đã sửa: ${fixedBytes.length} bytes');
        
        // Kiểm tra file đã sửa
        expect(await File(fixedAacPath).exists(), true);
        
        // Thử phát file AAC đã sửa
        print('Thử phát file AAC đã sửa...');
        
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
          await player.setFilePath(fixedAacPath);
          
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
          
          // Dừng phát
          await player.pause();
          print('Đã dừng phát audio');
          
          print('File AAC đã sửa có thể phát được, định dạng hợp lệ');
        } catch (e) {
          print('Lỗi khi phát file AAC đã sửa: $e');
          fail('Không thể phát file AAC đã sửa: $e');
        } finally {
          // Dọn dẹp
          await player.dispose();
        }
      } else {
        print('Không tìm thấy ADTS header trong file');
        fail('Không tìm thấy ADTS header trong file');
      }
    });
  });
}
