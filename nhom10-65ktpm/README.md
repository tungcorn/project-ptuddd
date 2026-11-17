# SingLearn – Nhóm 10 · 65KTPM

Ứng dụng học tiếng Anh qua bài hát, xây dựng bằng Flutter cho Android.

- **Học phần:** Phát triển ứng dụng cho thiết bị di động.
- **Giảng viên hướng dẫn:** ThS. Đỗ Oanh Cường.
- **Thành viên:** [Danh sách nhóm](danhsachnhom.md).
- **Đề cương, phân công chi tiết và kế hoạch:** [TH4 – SingLearn](docs/TH4_DeCuong_Project_SingLearn.md) · [Bản Word](docs/TH4_DeCuong_Project_SingLearn.docx).

## 1. Giới thiệu và trạng thái (cập nhật 16/11/2026)

SingLearn giúp người Việt học tiếng Anh qua các bài hát kinh điển. Bộ demo gồm 8 bài: lời đã hết bản quyền và **bản thu đều do người hát thật, thuộc phạm vi công cộng**. Mỗi bài có lời LRC đồng bộ theo giọng hát và bản dịch tiếng Việt.

Mọi chức năng trong đề cương đều đã có code. Mức kiểm chứng của từng chức năng khác nhau và được ghi rõ ở bảng dưới.

| Chức năng | Code | Test tự động | Đã chạy thật |
| --- | --- | --- | --- |
| Đăng ký/đăng nhập cục bộ, chế độ khách, xếp trình độ 5 câu | ✅ | ✅ | ✅ Android emulator + Chrome |
| Thư viện bài hát, tìm kiếm, lọc, yêu thích | ✅ | ✅ | ✅ emulator + Chrome |
| Trình phát: lời đồng bộ, 0,75x, lặp câu, A–B, mini player | ✅ | ✅ | ✅ emulator (nhạc phát thật, lời chạy đúng câu) + Chrome |
| Tra từ (IPA, nghĩa, ví dụ), lưu flashcard kèm câu hát, +10 XP | ✅ | ✅ | ✅ emulator + Chrome |
| Ôn flashcard SM-2 | ✅ | ✅ | ✅ Chrome (lật thẻ, chấm "Nhớ", +5 XP) |
| Điền từ 3 mức, sắp xếp câu, sắp xếp từ, trắc nghiệm nghĩa | ✅ | ✅ | ✅ Chrome (điền từ chấm đúng; các màn khác mở và hiển thị đúng) |
| Luyện phát âm (nhận dạng giọng nói, điểm 0–100) | ✅ | ✅ với bộ nhận dạng giả lập | ⚠️ Màn hình hiển thị đúng; chưa thu âm micro thật |
| XP, cấp, streak, huy hiệu, biểu đồ 7 ngày | ✅ | ✅ | ✅ Chrome |
| Bảng xếp hạng tuần, bạn bè, thử thách đoán bài (cục bộ) | ✅ | ✅ | ✅ Chrome (bảng xếp hạng); bạn bè/thử thách mới qua widget test |
| Quản trị bài hát, căn lại mốc thời gian lời | ✅ | ✅ | ✅ Chrome (danh sách bài hát); chọn file chưa thử thật |
| Nhắc học hằng ngày, phát nền và điều khiển ở màn hình khóa | ✅ | ❌ | ❌ chưa kiểm chứng |
| Firebase: Auth, Google, quên mật khẩu, Firestore, Storage, FCM, Rules | ✅ code + `firebase/` | Chỉ đồng bộ (với máy chủ giả lập) | ❌ chưa có project Firebase |

### Lưu ý về nội dung

- Danh sách bài (trình độ: bài – người trình bày):
  - A1: Silent Night – Singing Sergeants, US Air Force Band.
  - A2: My Bonnie Lies Over the Ocean – Haydn Quartet, 1901.
  - B1: America the Beautiful – Singing Sergeants.
  - B1: O Little Town of Bethlehem – Singing Sergeants.
  - B1: Take Me Out to the Ball Game – bản thu khoảng năm 1908, Library of Congress National Jukebox.
  - B2: Amazing Grace – Southern Aire, US Air Force Reserve Band.
  - B2: Danny Boy – Celtic Aire, US Air Force Band.
  - B2: Hark! The Herald Angels Sing – Singing Sergeants.
- Bản thu của ban nhạc quân đội Mỹ là tác phẩm của chính phủ liên bang nên thuộc phạm vi công cộng. Bản thu trước năm 1925 đã hết hạn bảo hộ tại Mỹ. Nguồn của từng bài được ghi trong `catalog.json` và hiển thị trong app.
- Lời được chỉnh theo đúng các lời bài mà ca sĩ hát trong bản thu. Mốc thời gian được căn tự động bằng `tools/align_recordings.py` (faster-whisper `small.en`), cấu hình trong `tools/recordings.json`. File gốc để ở `tools/recordings_src/` và không đưa lên Git.
- Thêm bài: tải bản thu có giấy phép mở, soạn file `songs/<id>.json`, thêm một mục vào `tools/recordings.json`, rồi chạy `python tools/align_recordings.py <id>`. Script báo tỉ lệ khớp; bài dưới 60% sẽ bị bỏ qua để kiểm tra lại bằng tay.
- `tools/generate_media.py` (giọng TTS) chỉ còn dùng cho bài chưa có bản thu thật và không ghi đè các bài đã có trong `recordings.json`.
- Lời và bản dịch nằm trong `src/assets/content/songs/*.json` (schema ở `tools/SONG_SCHEMA.md`). Từ điển gồm 510 mục, nằm ở `src/assets/content/dictionary.json`.

### Quy tắc nghiệp vụ chính

- XP: lưu từ mới +10 (mỗi từ chỉ một lần), ôn đúng +5, điền từ +20, bài tập khác +10, mỗi câu phát âm đạt ≥ 70 điểm +5, thử thách +10 (thắng thêm +10). Mỗi sự kiện có mã riêng nên không bị cộng trùng.
- Cấp độ: lên cấp L cần tổng 50·L·(L−1) XP (cấp 2 = 100, cấp 3 = 300…). Streak tính theo ngày liên tiếp có hoạt động học.
- Lưu lại một từ đã có thì chỉ thêm ngữ cảnh câu hát, không tạo thẻ mới.
- Ở chế độ demo, tài khoản đầu tiên tạo trên máy là quản trị viên nội dung.

## 2. Cấu trúc thư mục

```text
nhom10-65ktpm/
├── README.md, danhsachnhom.md, docs/
├── firebase/              # firestore.rules, storage.rules, functions/ (FCM), mẫu cấu hình
├── tools/                 # schema bài hát, sinh audio/LRC/ảnh bìa, nguồn từ điển
└── src/                   # gốc Flutter
    ├── assets/            # audio, lyrics (LRC), covers, content (bài hát, catalog, từ điển)
    ├── lib/core/          # cấu hình, lưu trữ Hive, đồng bộ, audio, router, giao diện chung
    ├── lib/features/      # auth, songs, player, vocabulary, practice, progress, social, admin, profile, home
    ├── test/unit, test/widget
    ├── integration_test/  # kiểm thử end-to-end trên thiết bị Android
    ├── android/
    └── web/               # chỉ dùng để chạy thử nhanh trên Chrome
```

## 3. Môi trường và cách chạy

Môi trường đã kiểm tra: Flutter 3.47.5, Dart 3.13.4, JDK 21, Android SDK (compileSdk 37, minSdk 24).

```bash
cd nhom10-65ktpm/src
flutter pub get
flutter analyze
flutter test                                   # unit + widget test, chạy trên máy tính
flutter run -d <android-device-id>             # chế độ demo, dữ liệu lưu trên máy
flutter run -d chrome                          # chạy thử nhanh trên Chrome
flutter test integration_test/app_e2e_test.dart -d <android-device-id>
```

**Chế độ Firebase:** tạo project Firebase, sao chép `firebase/firebase.env.example.json` thành `firebase.env.json`, điền giá trị rồi chạy `flutter run --dart-define-from-file=firebase.env.json`. Triển khai `firebase/firestore.rules`, `storage.rules` và `functions/` bằng Firebase CLI. Không commit `firebase.env.json`.

**Chạy bản build web:** sau `flutter build web`, dùng `python tools/serve_web.py` rồi mở http://127.0.0.1:8765. Không dùng `python -m http.server` vì server này không hỗ trợ HTTP Range, khiến Chrome không tua được nhạc và tự quay về 0:00.

**Giới hạn của bản web:** không có thông báo nhắc học, dịch máy ML Kit hay tải bài offline; app hiện thông báo khi người dùng chạm vào các chức năng này. Bản web chỉ dùng để kiểm thử nhanh, sản phẩm chính vẫn là Android.

### Kết quả kiểm tra (16/11/2026)

- `flutter analyze`: **No issues found**.
- Unit test: **87/87 đạt**. Có test kiểm tra nội dung từng bài: LRC khớp lời, có bản dịch, mọi từ trong lời đều có trong từ điển, có audio và ảnh bìa, giấy phép có ghi nguồn.
- Widget test: **29/29 đạt** (luồng app, trình phát/từ vựng, chuyển bài, kéo thanh tua, luyện tập, phát âm, xã hội, quản trị). Mỗi file được chạy riêng.
- `flutter build apk --debug` và `flutter build web`: **thành công**.
- Trên Android emulator (API 36), test end-to-end đạt các bước: đăng ký → xếp trình độ A2 → tìm bài → **nhạc phát thật, lời chạy theo** → 0,75x → lặp câu → tra và lưu từ → XP ≥ 10, streak 1. Bước ôn flashcard trước đó lỗi do cách test chuyển tab; test đã được sửa nhưng chưa chạy lại trên emulator.
- Trên Chrome (bản build web, chạy thủ công): đăng ký, xếp trình độ, trang chủ, phát nhạc kèm lời, lưu từ, ôn flashcard SM-2, điền từ, các màn luyện tập, thống kê, bảng xếp hạng và quản trị đều chạy, console không có lỗi.

## 4. Thành viên và phân công

| Thành viên | GitHub | Phụ trách chính | Giai đoạn sau luồng cốt lõi |
| --- | --- | --- | --- |
| **Ngô Quang Tùng – M1, nhóm trưởng** | [tungcorn](https://github.com/tungcorn) | Thư viện, trình phát/LRC, nghe lại câu; khung app và điều phối tích hợp | Phát nền, màn hình khóa, tải offline, lặp A–B |
| **Nguyễn Hải Ninh – M2** | [HaiNinh1](https://github.com/HaiNinh1) | Tra/lưu từ, flashcard SM-2, lưu cục bộ và đồng bộ từ vựng | Quản trị nhập/sửa nội dung bài hát |
| **Đào Ngọc Đình – M3** | [DaoNgocDinh](https://github.com/DaoNgocDinh) | Bài tập nghe, chấm/tổng kết phiên, luyện phát âm | Thử thách đoán tên bài hát |
| **Phạm Ngọc Bách – M4** | [phamngocbach05-debug](https://github.com/phamngocbach05-debug) | Xác thực/hồ sơ, trang chủ, XP/streak/huy hiệu, thống kê và nhắc học | Bạn bè và bảng xếp hạng |

Mỗi người phụ trách cả giao diện, logic, dữ liệu, kiểm thử và phần báo cáo/demo của mình. Cả nhóm chuẩn bị nội dung bài hát và review chéo; nhóm trưởng điều phối tích hợp, không mặc định làm thay các mô-đun. Phạm vi và mốc nghiệm thu chi tiết nằm ở mục 9–10 của đề cương.

## 5. Quy định nộp bài và việc còn thiếu

- Nhánh và thư mục nộp bài: **`nhom10-65ktpm`**; chỉ thay đổi trong thư mục nhóm. Nộp theo quy trình Fork/PR trong [README học phần](../README.md).
- Không đưa APK/AAB, thư mục build/cache, `firebase.env.json`, khóa bí mật, service-account hoặc keystore vào kho.

**Chưa kiểm chứng hoặc đang bị chặn (cần nhóm tự làm):**

1. Tạo project Firebase thật, rồi kiểm thử đăng nhập Google, email quên mật khẩu, đồng bộ Firestore, upload Storage, FCM và Security Rules.
2. Trên điện thoại Android thật: quyền micro và chấm phát âm, phát nền và điều khiển ở màn hình khóa, thông báo nhắc học, tải mô hình dịch ML Kit, chọn file trong màn quản trị.
3. Chạy lại `integration_test/app_e2e_test.dart` trên thiết bị sau khi sửa bước ôn flashcard.
4. (Tuỳ chọn) Thay audio TTS bằng bản hát thật có giấy phép.
5. Bổ sung email của Ninh, Đình, Bách; viết báo cáo cuối kỳ, slide và video demo.
6. Cấu hình ký bản release (keystore riêng) trước khi phát hành.
