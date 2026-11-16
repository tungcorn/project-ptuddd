# Danh Sách Thành Viên - Nhóm 10

- **Lớp học phần / Lớp sinh hoạt:** 65KTPM
- **Học phần:** Phát triển ứng dụng cho thiết bị di động
- **Tên đề tài / Ứng dụng:** SingLearn – Ứng dụng học tiếng Anh qua bài hát
- **Giảng viên hướng dẫn:** ThS. Đỗ Oanh Cường
- **Nền tảng:** Flutter · Android (Android 7.0 / API 24 trở lên)

## Bảng Thông Tin Thành Viên

Phân công được cập nhật theo quyết định của nhóm trưởng ngày 16/11/2026, đồng bộ với mục 9 của [đề cương SingLearn](docs/TH4_DeCuong_Project_SingLearn.md) và bản Word trong `docs/`. Đây là trách nhiệm triển khai, không phải xác nhận tính năng đã hoàn thành.

| STT | Họ và Tên | Mã Sinh Viên | Lớp Sinh Hoạt | Vai Trò | Nhiệm Vụ Phân Công | Đóng Góp (%) | Email |
| :-: | --------- | :----------: | :-----------: | :-----: | ------------------ | :----------: | ----- |
| 1 | Ngô Quang Tùng | 2351170631 | 65KTPM | Trưởng nhóm | M1: Thư viện, trình phát/LRC, nghe lại câu; khung app tối thiểu và điều phối tích hợp/đóng gói. Giai đoạn sau: phát nền, màn hình khóa, tải offline, lặp A–B | 100%* | tung01012005s@gmail.com |
| 2 | Nguyễn Hải Ninh | 2351170609 | 65KTPM | Thành viên | M2: Tra/lưu từ kèm ngữ cảnh, xử lý trùng, flashcard SM-2, Hive CE và đồng bộ từ vựng. Giai đoạn sau: nhập/sửa và quản trị nội dung bài hát | 100%* | Chưa cung cấp |
| 3 | Đào Ngọc Đình | 2351170582 | 65KTPM | Thành viên | M3: Bài tập điền từ, sắp xếp lời, trắc nghiệm, chấm/tổng kết phiên và luyện phát âm. Giai đoạn sau: thử thách đoán tên bài hát; không phụ trách bạn bè/bảng xếp hạng | 100%* | Chưa cung cấp |
| 4 | Phạm Ngọc Bách | 2351170576 | 65KTPM | Thành viên | M4: Xác thực/hồ sơ, dữ liệu theo người dùng, trang chủ, XP/cấp độ/streak/huy hiệu, thống kê, nhắc học. Giai đoạn sau: bạn bè và bảng xếp hạng | 100%* | Chưa cung cấp |

**Công việc chung:** chuẩn bị tối thiểu 30 bài hát có quyền sử dụng cả bản ghi/lời; phân bổ ban đầu Tùng/Ninh/Đình/Bách: 8/8/7/7 bài và cân lại theo độ khó. Mỗi người tự viết phần báo cáo/slide, chuẩn bị demo và kiểm thử phần mình; người tổng hợp chỉ ghép/chuẩn hóa. Review/dự phòng: Tùng ↔ Đình, Ninh ↔ Bách; thay đổi contract có bên sử dụng cùng rà soát. Nhóm trưởng điều phối, không mặc định sửa lỗi thay các owner.

**Thứ tự triển khai:** tích hợp sớm luồng một bài hát → lưu từ → ôn → tiến độ, sau đó mở rộng bài tập/phát âm và các phần việc giai đoạn sau. Không tự cắt tính năng khỏi đề cương; cập nhật tải sau từng mốc, trao đổi giảng viên nếu cần đổi phạm vi. Mỗi người bảo vệ bằng luồng chạy thật, một quyết định kỹ thuật, ca lỗi/biên và kết quả kiểm thử; không chỉ chia màn hình để trình bày.

**\* Tỷ lệ đóng góp:** giữ nguyên mức 100%/thành viên từ danh sách ban đầu; chưa phải kết quả đánh giá thực tế. Nhóm cần xác nhận cách tính và cập nhật theo công việc thực hiện trước khi nộp. Không tự suy diễn thành tỷ trọng chia tổng 100%.

**Thông tin còn thiếu:** email của Nguyễn Hải Ninh, Đào Ngọc Đình và Phạm Ngọc Bách. Cần bổ sung email thật trước khi nộp; không dùng địa chỉ giả.

## Hướng Dẫn Thiết Lập Môi Trường Và Khởi Chạy

### 1. Môi trường

- Flutter stable 3.47.2 / Dart 3.13.2 là môi trường dùng để thiết lập khung ban đầu; `pubspec.yaml` yêu cầu Dart `>=3.13.0 <4.0.0`.
- Android Studio, Android SDK và JDK 17; hoàn tất Android licenses theo `flutter doctor`.
- Thiết bị Android API 24+ hoặc Android Emulator; bản hiện tại chỉ có màn hình giới thiệu, chưa cần Firebase.
- Khi triển khai ghi âm, phát nhạc và thông báo, cần kiểm thử thêm trên thiết bị thật.

### 2. Lấy và chạy mã nguồn

```bash
git clone https://github.com/tungcorn/project-ptuddd.git
cd project-ptuddd
git switch nhom10-65ktpm
cd nhom10-65ktpm/src
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
```

Thay `<device-id>` bằng mã thiết bị Android do `flutter devices` trả về. Nếu đã mở kho hiện tại thì chỉ cần vào `nhom10-65ktpm/src` và chạy từ `flutter pub get`.

Các thay đổi thiết lập phải được commit/push lên nhánh nhóm trước khi thành viên khác có thể clone được phiên bản này.

### 3. Trạng thái ứng dụng

Hiện là **khung dự án SingLearn**, gồm cấu hình Android, màn hình giới thiệu và widget test. Chưa triển khai các tính năng nghe nhạc, lời LRC, bài tập, flashcard, Firebase và tiến độ học tập. Không cần `build_runner` ở giai đoạn này.

Kiểm tra ngày 16/11/2026: `flutter analyze` không có lỗi, 2 widget test thành công và `flutter build apk --debug` tạo APK thành công. Chưa kiểm thử khởi chạy trên thiết bị Android/emulator. Cấu trúc, hướng dẫn build và các việc cần hoàn thiện xem [README.md](README.md).
