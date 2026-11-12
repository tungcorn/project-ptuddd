# Đồ Án Phát Triển Ứng Dụng Di Động - Nhóm 10

## 1. Thông Tin Chung
- **Học phần:** Phát Triển Ứng Dụng Di Động (PTUDDD)
- **Lớp sinh hoạt / Lớp học phần:** 65KTPM
- **Nhóm thực hiện:** Nhóm 10
- **Tên đề tài:** *(Đang cập nhật đề tài Bài tập lớn)*
- **Giảng viên hướng dẫn:** Thầy Đỗ Oanh Cường

Chi tiết thành viên nhóm và phân công công việc xem tại: [danhsachnhom.md](danhsachnhom.md)

---

## 2. Cấu Trúc Thư Mục Nhóm
```text
nhom10-65ktpm/
├── danhsachnhom.md        # Thông tin thành viên và bảng phân công công việc
├── README.md              # Tài liệu hướng dẫn thiết lập và chạy đồ án
├── docs/                  # Tài liệu đặc tả, báo cáo đồ án (PDF/DOCX)
│   └── baocao_doan.pdf
└── src/                   # Toàn bộ mã nguồn ứng dụng (Flutter)
    ├── android/
    ├── ios/
    ├── assets/
    ├── lib/
    │   └── main.dart
    └── pubspec.yaml
```

---

## 3. Hướng Dẫn Cài Đặt & Khởi Chạy Ứng Dụng

### 3.1. Yêu cầu môi trường
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (Khuyến nghị phiên bản `>= 3.0.0`)
- [Dart SDK](https://dart.dev/get-dart)
- Android Studio / VS Code (đã cài đặt Flutter extension)
- Thiết bị thử nghiệm: Android Emulator hoặc thiết bị thật (bật USB Debugging)

### 3.2. Các bước khởi chạy
1. Di chuyển vào thư mục mã nguồn:
   ```bash
   cd nhom10-65ktpm/src
   ```

2. Cài đặt các gói phụ thuộc:
   ```bash
   flutter pub get
   ```

3. Kiểm tra thiết bị kết nối:
   ```bash
   flutter devices
   ```

4. Khởi chạy ứng dụng:
   ```bash
   flutter run
   ```
