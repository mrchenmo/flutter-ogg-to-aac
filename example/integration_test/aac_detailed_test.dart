import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AAC Detailed Format Analysis', () {
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

    testWidgets('Detailed analysis of AAC file structure', (WidgetTester tester) async {
      // Thực hiện chuyển đổi
      print('Bắt đầu chuyển đổi OGG sang AAC...');
      final result = await FlutterOggToAac.convert(testOggPath, outputAacPath);
      print('Kết quả chuyển đổi: $result');

      // Kiểm tra file đã được tạo
      expect(await File(outputAacPath).exists(), true);

      // Đọc toàn bộ file
      final bytes = await File(outputAacPath).readAsBytes();
      print('Kích thước file AAC: ${bytes.length} bytes');

      // Phân tích cấu trúc file
      analyzeAacFile(bytes);

      // Thử phát file để xác nhận nó có thể phát được
      final player = AudioPlayer();
      try {
        await player.setFilePath(outputAacPath);
        final duration = await player.duration;

        print('Thời lượng audio: ${duration?.inMilliseconds ?? 0} ms');
        expect(duration, isNotNull);

        // Phát một đoạn ngắn để xác nhận
        await player.play();
        await Future.delayed(Duration(milliseconds: 500));
        await player.pause();

        print('File AAC có thể phát được, định dạng hợp lệ');
      } catch (e) {
        print('Lỗi khi phát file: $e');
        fail('Không thể phát file AAC: $e');
      } finally {
        await player.dispose();
      }
    });
  });
}

// Hàm phân tích cấu trúc file AAC
void analyzeAacFile(Uint8List bytes) {
  print('\n--- PHÂN TÍCH CẤU TRÚC FILE AAC ---');

  // Kiểm tra xem file có phải là ADTS AAC hay MP4 container
  if (bytes.length < 8) {
    print('File quá nhỏ để phân tích');
    return;
  }

  // In ra 32 byte đầu tiên để phân tích
  final headerHex = bytes.sublist(0, bytes.length >= 32 ? 32 : bytes.length)
      .map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}')
      .join(' ');
  print('Header bytes (hex): $headerHex');

  // Kiểm tra ADTS header
  if (bytes[0] == 0xFF && (bytes[1] & 0xF0) == 0xF0) {
    print('Định dạng: AAC với ADTS header (AAC raw format)');
    analyzeAdtsHeader(bytes);
  }
  // Kiểm tra MP4 container
  else if (String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp') {
    print('Định dạng: AAC trong MP4/M4A container');
    analyzeMp4Container(bytes);
  }
  // Kiểm tra MPEG-4 Audio (AAC) không có ADTS header
  else if (bytes[0] == 0x00 && bytes[1] == 0x00) {
    print('Định dạng: Có thể là MPEG-4 Audio (AAC) không có ADTS header');
    print('Cần kiểm tra thêm để xác định chính xác');
  }
  else {
    print('Định dạng không xác định. Không phải ADTS AAC hoặc MP4 container tiêu chuẩn');
    print('Có thể là định dạng đặc biệt hoặc bị hỏng');
  }
}

// Phân tích ADTS header
void analyzeAdtsHeader(Uint8List bytes) {
  if (bytes.length < 7) {
    print('File quá nhỏ để phân tích ADTS header');
    return;
  }

  // ADTS header là 7 hoặc 9 byte
  final hasProtection = (bytes[1] & 0x01) == 0;
  final headerLength = hasProtection ? 9 : 7;

  if (bytes.length < headerLength) {
    print('File quá nhỏ để phân tích đầy đủ ADTS header');
    return;
  }

  // Phân tích các trường trong ADTS header
  final mpegVersion = (bytes[1] & 0x08) >> 3; // 0: MPEG-4, 1: MPEG-2
  final layer = (bytes[1] & 0x06) >> 1; // Luôn là 0 cho AAC
  final profileMinusOne = (bytes[2] & 0xC0) >> 6; // Profile = value + 1
  final samplingFreqIndex = (bytes[2] & 0x3C) >> 2;
  final channelConfig = ((bytes[2] & 0x01) << 2) | ((bytes[3] & 0xC0) >> 6);
  final frameLength = ((bytes[3] & 0x03) << 11) | (bytes[4] << 3) | ((bytes[5] & 0xE0) >> 5);

  // Mapping sampling frequency index to actual frequency
  final samplingFrequencies = [
    96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350
  ];
  final samplingFreq = samplingFreqIndex < samplingFrequencies.length
      ? samplingFrequencies[samplingFreqIndex]
      : 'Unknown';

  // Mapping profile to name
  final profiles = ['AAC Main', 'AAC LC', 'AAC SSR', 'AAC LTP'];
  final profile = profileMinusOne < profiles.length ? profiles[profileMinusOne] : 'Unknown';

  print('ADTS Header Analysis:');
  print('- MPEG Version: ${mpegVersion == 0 ? "MPEG-4" : "MPEG-2"}');
  print('- Layer: $layer (should be 0 for AAC)');
  print('- Protection: ${hasProtection ? "Yes" : "No"}');
  print('- Profile: $profile');
  print('- Sampling Frequency: $samplingFreq Hz');
  print('- Channel Configuration: $channelConfig');
  print('- Frame Length: $frameLength bytes');

  // Kiểm tra nhiều ADTS frame
  int offset = 0;
  int frameCount = 0;

  while (offset + headerLength < bytes.length) {
    // Kiểm tra sync word (0xFFF)
    if (bytes[offset] == 0xFF && (bytes[offset + 1] & 0xF0) == 0xF0) {
      frameCount++;

      // Lấy frame length từ header
      final frameLen = ((bytes[offset + 3] & 0x03) << 11) |
                       (bytes[offset + 4] << 3) |
                       ((bytes[offset + 5] & 0xE0) >> 5);

      // Di chuyển đến frame tiếp theo
      offset += frameLen;
    } else {
      // Không tìm thấy sync word, có thể là dữ liệu bị hỏng
      break;
    }
  }

  print('- Số lượng ADTS frame phát hiện được: $frameCount');
}

// Phân tích MP4 container
void analyzeMp4Container(Uint8List bytes) {
  if (bytes.length < 8) {
    print('File quá nhỏ để phân tích MP4 container');
    return;
  }

  // Đọc kích thước của box đầu tiên
  final firstBoxSize = bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3];
  final firstBoxType = String.fromCharCodes(bytes.sublist(4, 8));

  print('MP4 Container Analysis:');
  print('- First box: $firstBoxType (size: $firstBoxSize bytes)');

  // Kiểm tra brand trong ftyp box
  if (firstBoxType == 'ftyp' && bytes.length >= 12) {
    final majorBrand = String.fromCharCodes(bytes.sublist(8, 12));
    print('- Major brand: $majorBrand');

    // Kiểm tra các compatible brands
    int offset = 16; // Sau major_brand và minor_version
    List<String> compatibleBrands = [];

    while (offset + 4 <= firstBoxSize && offset + 4 <= bytes.length) {
      final brand = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      compatibleBrands.add(brand);
      offset += 4;
    }

    if (compatibleBrands.isNotEmpty) {
      print('- Compatible brands: ${compatibleBrands.join(', ')}');
    }
  }

  // Tìm kiếm các box quan trọng
  findMp4Boxes(bytes);
}

// Tìm kiếm các box quan trọng trong MP4 container
void findMp4Boxes(Uint8List bytes) {
  int offset = 0;
  Map<String, int> boxCounts = {};

  while (offset + 8 <= bytes.length) {
    // Đọc kích thước và loại box
    final boxSize = bytes[offset] << 24 | bytes[offset + 1] << 16 |
                   bytes[offset + 2] << 8 | bytes[offset + 3];
    final boxType = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));

    // Cập nhật số lượng box
    boxCounts[boxType] = (boxCounts[boxType] ?? 0) + 1;

    // Kiểm tra box 'mdat' (media data)
    if (boxType == 'mdat') {
      print('- Found media data box (mdat) at offset $offset, size: $boxSize bytes');
    }

    // Kiểm tra box 'moov' (movie metadata)
    if (boxType == 'moov') {
      print('- Found movie metadata box (moov) at offset $offset, size: $boxSize bytes');
    }

    // Kiểm tra box 'mp4a' (AAC audio)
    if (boxType == 'mp4a') {
      print('- Found AAC audio box (mp4a) at offset $offset, size: $boxSize bytes');
    }

    // Di chuyển đến box tiếp theo
    if (boxSize > 0) {
      offset += boxSize;
    } else {
      // Box size = 0 nghĩa là box kéo dài đến cuối file
      break;
    }
  }

  // In ra tất cả các loại box đã tìm thấy
  print('- Các loại box đã tìm thấy:');
  boxCounts.forEach((type, count) {
    print('  * $type: $count box');
  });
}
