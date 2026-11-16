# Danh Sách Thành Viên - Nhóm 10

- **Lớp học phần / Lớp sinh hoạt:** 65KTPM
- **Tên đề tài / Ứng dụng:** SingLearn – Ứng dụng học tiếng Anh qua bài hát
- **Giảng viên hướng dẫn:** ThS. Đỗ Oanh Cường

## Bảng Thông Tin Thành Viên

| STT | Họ và Tên | Mã Sinh Viên | Lớp Sinh Hoạt | Vai Trò | Nhiệm Vụ Phân Công | Đóng Góp (%) | Email |
| --- | --------- | ------------ | ------------- | ------- | ------------------- | ------------- | ----- |
| 1 | Ngô Quang Tùng | 2351170631 | 65KTPM | Trưởng nhóm | Thư viện bài hát, trình phát/LRC, nghe lại câu, phát nền, tải offline, lặp A–B; khung ứng dụng và điều phối tích hợp | 100%* | tung01012005s@gmail.com |
| 2 | Nguyễn Hải Ninh | 2351170609 | 65KTPM | Thành viên | Tra/lưu từ theo ngữ cảnh, flashcard SM-2, lưu cục bộ và đồng bộ từ vựng; quản trị nội dung bài hát | 100%* | Chưa cung cấp |
| 3 | Đào Ngọc Đình | 2351170582 | 65KTPM | Thành viên | Bài tập điền từ, sắp xếp lời, trắc nghiệm, chấm/tổng kết phiên, luyện phát âm; thử thách đoán tên bài hát | 100%* | Chưa cung cấp |
| 4 | Phạm Ngọc Bách | 2351170576 | 65KTPM | Thành viên | Xác thực/hồ sơ, dữ liệu theo người dùng, trang chủ, XP/cấp độ/streak/huy hiệu, thống kê, nhắc học; bạn bè và bảng xếp hạng | 100%* | Chưa cung cấp |

\* Tỷ lệ đóng góp giữ theo danh sách ban đầu, chưa phải đánh giá thực tế; cần xác nhận trước khi nộp.

## Hướng Dẫn Thiết Lập Môi Trường Và Khởi Chạy

### 1. Môi trường

- Flutter 3.47.2 / Dart 3.13.2.
- Android Studio, Android SDK, JDK 17; hoàn tất Android licenses theo `flutter doctor`.
- Thiết bị Android 7.0 / API 24 trở lên hoặc Android Emulator.

### 2. Lấy và chạy mã nguồn

```bash
git clone https://github.com/tungcorn/project-ptuddd.git
cd project-ptuddd
git switch nhom10-65ktpm
cd nhom10-65ktpm/src
flutter doctor
flutter pub get
flutter devices
flutter run -d <device-id>
```

Thay `<device-id>` bằng ID thiết bị Android từ `flutter devices`.
