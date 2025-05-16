import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('File Comparison Tests', () {
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

    testWidgets('Compare input OGG and output AAC files', (WidgetTester tester) async {
      // Thực hiện chuyển đổi
      print('Bắt đầu chuyển đổi OGG sang AAC...');
      final result = await FlutterOggToAac.convert(testOggPath, outputAacPath);
      print('Kết quả chuyển đổi: $result');
      
      // Kiểm tra file đã được tạo
      expect(await File(outputAacPath).exists(), true);
      
      // Đọc cả hai file
      final oggBytes = await File(testOggPath).readAsBytes();
      final aacBytes = await File(outputAacPath).readAsBytes();
      
      print('Kích thước file OGG: ${oggBytes.length} bytes');
      print('Kích thước file AAC: ${aacBytes.length} bytes');
      
      // So sánh kích thước
      print('Tỷ lệ kích thước AAC/OGG: ${aacBytes.length / oggBytes.length}');
      
      // So sánh header
      final oggHeader = oggBytes.sublist(0, oggBytes.length >= 32 ? 32 : oggBytes.length);
      final aacHeader = aacBytes.sublist(0, aacBytes.length >= 32 ? 32 : aacBytes.length);
      
      print('OGG header: ${oggHeader.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      print('AAC header: ${aacHeader.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      
      // Kiểm tra xem file AAC có phải là bản sao của file OGG không
      bool isIdentical = oggBytes.length == aacBytes.length;
      if (isIdentical) {
        // So sánh từng byte
        for (int i = 0; i < oggBytes.length; i++) {
          if (oggBytes[i] != aacBytes[i]) {
            isIdentical = false;
            break;
          }
        }
      }
      
      print('Hai file ${isIdentical ? "giống nhau" : "khác nhau"}');
      
      // Kiểm tra xem file AAC có chứa signature của OGG không
      bool containsOggSignature = false;
      if (aacBytes.length >= 4) {
        // OGG signature là "OggS"
        if (String.fromCharCodes(aacBytes.sublist(0, 4)) == "OggS") {
          containsOggSignature = true;
        }
      }
      
      print('File AAC ${containsOggSignature ? "có chứa" : "không chứa"} signature của OGG');
      
      // Kiểm tra xem file AAC có chứa các byte đặc trưng của AAC không
      bool containsAacSignature = false;
      for (int i = 0; i < aacBytes.length - 2; i++) {
        // ADTS header bắt đầu với 0xFF 0xF1 hoặc 0xFF 0xF9
        if (aacBytes[i] == 0xFF && (aacBytes[i + 1] & 0xF0) == 0xF0) {
          containsAacSignature = true;
          print('Tìm thấy ADTS header tại vị trí $i');
          break;
        }
      }
      
      print('File AAC ${containsAacSignature ? "có chứa" : "không chứa"} signature của AAC');
      
      // Kết luận
      if (isIdentical) {
        print('KẾT LUẬN: File AAC là bản sao y hệt của file OGG, không có chuyển đổi thực sự');
      } else if (containsOggSignature) {
        print('KẾT LUẬN: File AAC vẫn chứa signature của OGG, có thể chỉ là file OGG được đổi tên');
      } else if (containsAacSignature) {
        print('KẾT LUẬN: File AAC có chứa signature của AAC, có thể đã được chuyển đổi thành công');
      } else {
        print('KẾT LUẬN: File AAC không phải là AAC hợp lệ và cũng không phải là OGG, định dạng không xác định');
      }
    });
  });
}
