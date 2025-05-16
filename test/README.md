# Hướng dẫn chạy test cho Flutter OGG to AAC Converter

Tài liệu này hướng dẫn cách chạy các bài test cho plugin Flutter OGG to AAC Converter.

## Chuẩn bị

1. Đảm bảo bạn đã cài đặt Flutter SDK và các công cụ phát triển cần thiết.
2. Đảm bảo bạn đã kết nối thiết bị thật hoặc máy ảo để chạy các bài test tích hợp.
3. Chuẩn bị file OGG mẫu để test (đặt trong thư mục `example/assets/test_audio.ogg`).

## Các loại test

### 1. Unit Test

Unit test kiểm tra các chức năng cơ bản của API Dart.

```bash
flutter test test/flutter_ogg_to_aac_test.dart
```

### 2. Test tích hợp

Test tích hợp kiểm tra chức năng thực tế trên thiết bị.

```bash
flutter test test/flutter_ogg_to_aac_integration_test.dart
```

### 3. Test hiệu suất

Test hiệu suất đo thời gian chuyển đổi và tỷ lệ nén.

```bash
flutter test test/performance_test.dart
```

### 4. Test ứng dụng ví dụ

Test ứng dụng ví dụ kiểm tra UI và chức năng chuyển đổi.

```bash
cd example
flutter test integration_test/app_test.dart
```

## Chuẩn bị file test

Để chạy các bài test tích hợp và hiệu suất, bạn cần chuẩn bị file OGG mẫu:

1. Tạo thư mục `example/assets` nếu chưa có.
2. Đặt file OGG mẫu vào thư mục `example/assets` với tên `test_audio.ogg`.
3. Cập nhật file `example/pubspec.yaml` để đăng ký file assets:

```yaml
flutter:
  assets:
    - assets/test_audio.ogg
```

4. Chạy lệnh `flutter pub get` trong thư mục `example`.

## Giải quyết vấn đề

Nếu bạn gặp lỗi khi chạy các bài test:

1. Đảm bảo bạn đã cài đặt đúng các dependency.
2. Kiểm tra quyền truy cập file trên thiết bị.
3. Kiểm tra file OGG mẫu có hợp lệ không.
4. Đảm bảo thiết bị có đủ dung lượng lưu trữ.

## Tạo file OGG mẫu

Nếu bạn không có file OGG mẫu, bạn có thể tạo một file đơn giản bằng cách sử dụng FFmpeg:

```bash
ffmpeg -f lavfi -i "sine=frequency=440:duration=5" -c:a libvorbis test_audio.ogg
```

Lệnh này tạo một file OGG 5 giây với âm thanh sine wave 440Hz.
