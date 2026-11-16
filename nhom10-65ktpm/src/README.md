# Mã nguồn SingLearn

Project Flutter Android ban đầu của Nhóm 10, lớp 65KTPM.

Xem [README của nhóm](../README.md) để biết yêu cầu môi trường, lệnh chạy,
phạm vi đã triển khai và quy trình nộp bài. Đề cương nằm trong [docs/](../docs/).

Chạy các lệnh sau tại thư mục này:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run -d <device-id>
```

Kiểm tra ngày 16/11/2026: analyze không có lỗi, 2 widget test thành công và
build APK debug thành công. Chưa kiểm thử khởi chạy Android vì chưa có
thiết bị kết nối hoặc emulator.

Gradle Wrapper 9.3.1 và JAR khởi động được đưa vào mã nguồn. Mặc định wrapper
lưu bản phân phối/cache trong `android/.gradle/` để tránh lỗi Kotlin DSL khi
cache người dùng nằm qua junction/đường dẫn chuyển hướng trên Windows.
Cấu hình `GRADLE_USER_HOME` do người chạy đặt rõ ràng vẫn được giữ nguyên;
wrapper không thay đổi biến môi trường toàn máy. Lần build đầu cần mạng để
tải Gradle và dependency; các bản phân phối được kiểm tra SHA-256.

APK nằm tại `build/app/outputs/flutter-apk/app-debug.apk`. Cache và APK bị
Git bỏ qua, không đưa vào kho nộp bài.

Hiện chỉ có màn hình giới thiệu và widget test; chưa có thư viện bài hát,
trình phát, Firebase hay các chức năng học tập trong đề cương.
