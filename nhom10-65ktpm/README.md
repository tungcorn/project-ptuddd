# SingLearn – Nhóm 10 · 65KTPM

Ứng dụng học tiếng Anh qua bài hát, xây dựng bằng Flutter cho Android.

- **Học phần:** Phát triển ứng dụng cho thiết bị di động.
- **Giảng viên hướng dẫn:** ThS. Đỗ Oanh Cường.
- **Thành viên:** [Danh sách nhóm](danhsachnhom.md).
- **Đề cương, phân công chi tiết và kế hoạch:** [TH4 – SingLearn](docs/TH4_DeCuong_Project_SingLearn.md) · [Bản Word](docs/TH4_DeCuong_Project_SingLearn.docx).

## 1. Giới thiệu và trạng thái

Theo đề cương, SingLearn dự kiến có thư viện tối thiểu 30 bài hát có giấy phép phù hợp, trình phát và lời LRC đồng bộ, tra/lưu từ, flashcard SM-2, bài tập nghe, luyện phát âm, XP/streak/huy hiệu, bạn bè và thử thách. Dữ liệu dự kiến lưu offline và đồng bộ Firebase.

**Hiện mới là khung dự án, chưa phải ứng dụng hoàn thiện.**

| Hạng mục | Trạng thái |
| --- | --- |
| Đề cương TH4 Word/Markdown và video đề cương | Đã có trong `docs/` |
| Danh sách thành viên, phân công và kế hoạch | Đã cập nhật theo quyết định nhóm trưởng ngày 16/11/2026 |
| Khung Flutter Android, màn hình giới thiệu | Đã có |
| Các tính năng học tập, tiến độ, xã hội và Firebase | Chưa triển khai |
| Nội dung bài hát, kiểm thử thiết bị thật, báo cáo cuối kỳ | Chưa hoàn thành |

## 2. Cấu trúc thư mục

```text
nhom10-65ktpm/
├── README.md
├── danhsachnhom.md
├── docs/
│   ├── README.md
│   ├── TH4_DeCuong_Project_SingLearn.md
│   ├── TH4_DeCuong_Project_SingLearn.docx
│   └── TH4_Video_SingLearn.mp4
└── src/
    ├── pubspec.yaml
    ├── android/
    ├── assets/
    ├── lib/
    └── test/
```

`src/` là thư mục gốc Flutter. Dự án chỉ nhắm Android, không yêu cầu iOS/Web. Xem [chỉ mục tài liệu](docs/README.md) để phân biệt đề cương, video ban đầu và báo cáo kết quả cần bổ sung.

## 3. Môi trường và cách chạy

### Yêu cầu

- Môi trường đã dùng khi thiết lập: **Flutter 3.47.2 / Dart 3.13.2**; `pubspec.yaml` yêu cầu Dart `>=3.13.0 <4.0.0`.
- Android Studio, Android SDK, **JDK 17**; hoàn tất Android licenses theo `flutter doctor`.
- Emulator hoặc thiết bị **Android 7.0 / API 24 trở lên**.
- Gradle Wrapper 9.3.1 đi kèm dự án, tự tải bản phân phối có kiểm tra SHA-256. Mặc định bản phân phối/cache nằm trong `android/.gradle/` và bị Git bỏ qua; lần build đầu cần mạng, không cần cài Gradle toàn máy.

Chạy từ gốc kho:

```bash
git switch nhom10-65ktpm
cd nhom10-65ktpm/src
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
```

Thay `<device-id>` bằng ID thiết bị Android từ `flutter devices`. Bản hiện tại chỉ có màn hình giới thiệu, chưa cần tài khoản, Firebase hay sinh mã `build_runner`.

### Kết quả kiểm tra khi thiết lập (16/11/2026)

- `flutter pub get`: thành công.
- `flutter analyze`: **No issues found**.
- `flutter test`: **2 widget test thành công**.
- `flutter build apk --debug`: **thành công**, tạo `src/build/app/outputs/flutter-apk/app-debug.apk`.
- Chưa kiểm thử khởi chạy trên Android vì máy kiểm tra chưa có thiết bị kết nối hoặc emulator. Build/analyze/widget test không thay thế kiểm thử thiết bị.

Build lại bằng `flutter build apk --debug` tại `src/`. APK và cache Gradle bị Git bỏ qua, không đưa vào kho nộp bài. Cấu hình release hiện còn dùng debug signing của template, chưa sẵn sàng phát hành.

## 4. Thành viên và phân công

| Thành viên | GitHub | Phụ trách chính | Giai đoạn sau luồng cốt lõi |
| --- | --- | --- | --- |
| **Ngô Quang Tùng – M1, nhóm trưởng** | [tungcorn](https://github.com/tungcorn) | Thư viện, trình phát/LRC, nghe lại câu; khung app và điều phối tích hợp | Phát nền, màn hình khóa, tải offline, lặp A–B |
| **Nguyễn Hải Ninh – M2** | [HaiNinh1](https://github.com/HaiNinh1) | Tra/lưu từ, flashcard SM-2, lưu cục bộ và đồng bộ từ vựng | Quản trị nhập/sửa nội dung bài hát |
| **Đào Ngọc Đình – M3** | [DaoNgocDinh](https://github.com/DaoNgocDinh) | Bài tập nghe, chấm/tổng kết phiên, luyện phát âm | Thử thách đoán tên bài hát |
| **Phạm Ngọc Bách – M4** | [phamngocbach05-debug](https://github.com/phamngocbach05-debug) | Xác thực/hồ sơ, trang chủ, XP/streak/huy hiệu, thống kê và nhắc học | Bạn bè và bảng xếp hạng |

Mỗi người phụ trách cả giao diện, logic, dữ liệu, kiểm thử và phần báo cáo/demo của mình. Cả nhóm chuẩn bị nội dung bài hát và review chéo; nhóm trưởng điều phối tích hợp, không mặc định làm thay các mô-đun. Phạm vi và mốc nghiệm thu chi tiết nằm ở mục 9–10 của đề cương.

## 5. Quy định nộp bài và việc còn thiếu

- Nhánh và thư mục nộp bài: **`nhom10-65ktpm`**; chỉ thay đổi trong thư mục nhóm, không sửa README/`.gitignore` gốc hoặc nhóm khác.
- Nộp theo quy trình Fork/PR trong [README học phần](../README.md); không commit/push trực tiếp vào `main` hoặc đẩy lên kho giảng viên. Chỉ tạo PR khi có yêu cầu.
- Không đưa APK/AAB, thư mục build/cache, `.env`, khóa bí mật, service-account JSON hoặc keystore vào kho.
- Cần bổ sung email thật của Ninh/Đình/Bách và đánh giá đóng góp thực tế trong danh sách nhóm.
- Cần triển khai chức năng, cấu hình Firebase/quyền truy cập, chuẩn bị nội dung có giấy phép và kiểm thử khởi chạy trên Android/thiết bị thật.
- Cần bổ sung báo cáo cuối kỳ, slide và video demo sản phẩm; đề cương TH4 không thay báo cáo kết quả.
