# SingLearn – Nhóm 10 · 65KTPM

Ứng dụng học tiếng Anh qua bài hát, xây dựng bằng Flutter cho Android.

- **Học phần:** Phát triển ứng dụng cho thiết bị di động.
- **Giảng viên hướng dẫn:** ThS. Đỗ Oanh Cường.
- **Thành viên:** [Danh sách nhóm](danhsachnhom.md).
- **Mẫu PR nội bộ nhóm:** [PR template](docs/PR_TEMPLATE.md) — dành cho nhánh tính năng → `nhom10-65ktpm`; sao chép thủ công hoặc dùng `--body-file`, không tự điền trên GitHub.
- **Phân công đợt hoàn thiện:** [Nhiệm vụ, ranh giới file và giao tiếp mô-đun](docs/PHAN_CONG_HOAN_THIEN.md) — đọc trước khi nhận việc hoặc dùng AI sửa code.
- **Quản lý tiến độ:** [Project board](https://github.com/users/tungcorn/projects/2/views/2) (riêng tư, thành viên đã được cấp quyền cập nhật) · [Issues](https://github.com/tungcorn/project-ptuddd/issues).
- **Báo cáo cuối kỳ (DOCX):** [SingLearn – Nhóm 10 · 65KTPM](docs/BaoCaoCuoiKy_SingLearn_Nhom10_65KTPM.docx).
- **Đề cương, phân công chi tiết và kế hoạch:** [TH4 – SingLearn](docs/TH4_DeCuong_Project_SingLearn.md).

## 1. Giới thiệu và trạng thái (cập nhật 27/11/2026)

SingLearn giúp người Việt học tiếng Anh qua bài hát. Thư viện gồm **8 bài kinh điển giữ nguyên và 3 đoạn học pop/acoustic của Josh Woodward**, với giọng hát thật, lời LRC và bản dịch tiếng Việt. Tám bài cũ dùng nguồn thuộc phạm vi công cộng; ba đoạn mới dùng tác phẩm và bản thu **CC BY 4.0**, ghi rõ tác giả, nguồn, giấy phép và phần chỉnh sửa — không trình bày đoạn trích là toàn bộ bài.

Bảng dưới ghi các chức năng đã triển khai và mức kiểm chứng của từng chức năng. Kết quả của bản cũ, test tự động và lượt Android trên bản tích hợp được ghi riêng.

| Chức năng | Code | Test tự động | Đã chạy thật |
| --- | --- | --- | --- |
| Đăng ký/đăng nhập cục bộ, chế độ khách, xếp trình độ 5 câu | ✅ | ✅ | ✅ Android emulator + Chrome |
| Thư viện bài hát, tìm kiếm, lọc, yêu thích | ✅ | ✅ | ✅ emulator + Chrome |
| Trình phát: lời đồng bộ, 0,75x, lặp câu, A–B, mini player | ✅ | ✅ | ✅ emulator (nhạc phát thật, lời chạy đúng câu) + Chrome |
| Tra từ (IPA, nghĩa, ví dụ), lưu flashcard kèm câu hát, +10 XP | ✅ | ✅ | ✅ emulator + Chrome |
| Ôn flashcard SM-2 | ✅ | ✅ | ✅ Android thật, local `94e1ee3`: nhớ 1/1, +5 XP, lịch ôn còn sau mở lại |
| Điền từ 3 mức, sắp xếp câu, sắp xếp từ, trắc nghiệm nghĩa | ✅ | ✅ | ✅ Android thật, local `94e1ee3`: điền từ Dễ 3/3; các dạng khác đã mở trên Chrome |
| Luyện phát âm (điểm xấp xỉ 0–100 từ kết quả nhận dạng văn bản) | ✅ | ✅ với bộ nhận dạng giả lập | ⚠️ Đã thử micro thật trên bản cũ; Home đạt trên giả lập `be084f3`, chưa chốt nút Dừng trên cùng bản |
| XP, cấp, streak, huy hiệu, biểu đồ 7 ngày | ✅ | ✅ | ✅ Chrome; XP và streak còn sau khi mở lại app Android `94e1ee3` |
| Bảng xếp hạng tuần, bạn bè, thử thách đoán bài (cục bộ) | ✅ | ✅ | ✅ Chrome (bảng xếp hạng); bạn bè/thử thách mới qua widget test |
| Quản trị bài hát, căn lại mốc thời gian lời | ✅ | ✅ | ✅ Chrome (danh sách bài hát); chưa thử chọn file thật trên bản demo |
| Phát nền và điều khiển nhạc | ✅ | Test hành vi player | ⚠️ [Đã thử phát nền, media key và nút notification trên bản cũ](docs/kiem-thu/M1.md); chưa chốt điều khiển trực tiếp trên giao diện khóa/Doze dài hạn |
| Nhắc học hằng ngày và tải mô hình dịch ML Kit | ✅ | Chưa có bằng chứng native | ⚠️ Chưa kiểm chứng trên bản demo, không đưa vào kịch bản chính |
| Firebase Auth email/mật khẩu, Firestore và Rules | ✅ project riêng, không liên kết billing | ✅ kiểm thử rules trên Firestore Emulator, hồi quy sync unit/widget | ✅ Android thật, Firebase `94e1ee3`: đăng ký, lưu và đồng bộ từ lên server, khôi phục phiên, logout. Chưa chốt hai máy và đổi tài khoản |
| Đăng nhập Google trên Android | ✅ [#30](https://github.com/tungcorn/project-ptuddd/pull/30) đã merge tại `be084f3`; cần cấu hình Firebase và OAuth phù hợp | Test Auth/config/UI; không thay kiểm thử OAuth | ✅ Bản có Google từ `681478c` đã đăng nhập đến màn xếp trình độ trên điện thoại; APK local `be084f3` không bật Google |
| Email quên mật khẩu, Storage, FCM | Ngoài luồng học cốt lõi | Chưa kiểm chứng đầy đủ | Chưa thử gửi email reset; Storage/FCM chưa triển khai |

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
- Đoạn học bổ sung, đều do Josh Woodward sáng tác và trình bày, giấy phép CC BY 4.0:
  - A2: **Coffee (đoạn học)** — 77 giây, 14 câu; sinh hoạt và công việc.
  - B1: **Learn To Fly (đoạn học)** — 61 giây, 16 câu; động lực, thử lại và kiên trì.
  - B1: **Little Tomcat (đoạn học)** — 47 giây, 10 câu; tình bạn và chăm sóc thú cưng.
  - Mức CEFR là gợi ý biên tập. Có audio, LRC, bản dịch, từ vựng và ảnh bìa; mốc tự động vẫn cần nghe rà khi review. Nguồn, quyền sử dụng, cách tái tạo và giới hạn kiểm tra: [nội dung bài hát](docs/noi-dung-bai-hat.md).
- Với tám bài cũ: bản thu của ban nhạc quân đội Mỹ là tác phẩm của chính phủ liên bang nên thuộc phạm vi công cộng. Bản thu trước năm 1925 đã hết hạn bảo hộ tại Mỹ. Nguồn của từng bài được ghi trong `catalog.json` và hiển thị trong app.
- Lời được chỉnh theo đúng các lời bài mà ca sĩ hát trong bản thu. Mốc thời gian được căn tự động bằng `tools/align_recordings.py` (faster-whisper `small.en`), cấu hình trong `tools/recordings.json`. File gốc để ở `tools/recordings_src/` và không đưa lên Git.
- Thêm bài: xác minh quyền với cả lời/nhạc và bản thu, soạn file `songs/<id>.json`, thêm một mục vào `tools/recordings.json`, rồi chạy `python tools/align_recordings.py <id>`. Script báo tỉ lệ khớp; bài dưới ngưỡng `--min-match` (mặc định 50%, có thể đặt riêng trong manifest) sẽ bị bỏ qua để kiểm tra lại bằng tay. Ba đoạn học mới dùng manifest riêng `tools/learning_clips.json` và `tools/build_learning_clips.py` để tái tạo đúng khoảng cắt/mốc đã lưu, không ghi đè bài cũ.
- `tools/generate_media.py` (giọng TTS) chỉ còn dùng cho bài chưa có bản thu thật và không ghi đè các bài đã có trong `recordings.json`.
- Lời và bản dịch nằm trong `src/assets/content/songs/*.json` (schema ở `tools/SONG_SCHEMA.md`). Từ điển gồm 657 mục (bổ sung 71 mục cho đợt nội dung này), nằm ở `src/assets/content/dictionary.json`.

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

**Android giả lập:** nhóm có script mở AVD đã thiết lập sẵn, test ba đoạn học và driver integration chuẩn. Từ `src/`, chạy `..\tools\start_android_emulator.ps1` rồi `flutter run --no-pub -d emulator-5554`. Đường dẫn ổ D/AVD là cấu hình tham chiếu, có thể truyền tham số theo máy; script không tự cài SDK hay tạo AVD. Xem [hướng dẫn giả lập](docs/chay-android-gia-lap.md) để biết lệnh test, tác động dữ liệu local và giới hạn bằng chứng. Smoke lịch sử không thay thế kết quả integration runner trên bản mới.

**Chế độ Firebase:** project riêng `singlearn-nhom10-65ktpm` dùng Auth email/mật khẩu và Firestore tại Singapore, không liên kết billing. Từ `src/`, chạy `flutter run --dart-define-from-file=firebase.env.json -d <android-device-id>`. Máy khác sao chép `../firebase/firebase.env.example.json` thành `firebase.env.json` rồi điền cấu hình ứng dụng Android. Không commit tệp cấu hình cục bộ. Storage, Functions, FCM chưa triển khai; audio/LRC/ảnh vẫn nằm trong assets. Đăng nhập Google trên Android đã tích hợp qua #30 từ `be084f3`; cần bật cờ Google và đặt Web OAuth client ID phù hợp với cấu hình Android. APK local không bật Firebase hoặc Google. Xem [hướng dẫn Firebase](firebase/README.md).

**Chạy bản build web:** sau `flutter build web`, dùng `python tools/serve_web.py` rồi mở http://127.0.0.1:8765. Không dùng `python -m http.server` vì server này không hỗ trợ HTTP Range, khiến Chrome không tua được nhạc và tự quay về 0:00.

**Giới hạn của bản web:** không có thông báo nhắc học, dịch máy ML Kit hay tải bài offline; app hiện thông báo khi người dùng chạm vào các chức năng này. Bản web chỉ dùng để kiểm thử nhanh, sản phẩm chính vẫn là Android.

### Kết quả bản tích hợp `94e1ee3` (25/11/2026)

- **Local, Android 16 / API 36:** Silent Night → phát và lời song ngữ → lưu và ôn `calm` → điền từ 3/3 → 35 XP, streak 1. Mở lại app vẫn còn thẻ/lịch ôn, XP và điểm bài tập. Đây là lượt thao tác thủ công, không phải kết quả của runner `integration_test`.
- **Firebase, APK khác trên cùng SHA:** đăng ký tài khoản thử, lưu `calm`, đồng bộ 4 thao tác chờ và đọc lại dữ liệu từ Firestore server. Khôi phục phiên và logout đã thử riêng trên một điện thoại.

### Kiểm tra nhanh bản tích hợp `be084f3` (đã gồm #30)

- **Local, điện thoại Android 16 / API 36:** build và cài APK từ đúng commit, đối chiếu SHA-256. Mở app → vào Khách → Trang chủ → phát và tạm dừng Silent Night, có lời bài hát. Không chạy lại toàn bộ luồng học hoặc Google trên APK local này.
- **Home khi đang nhận dạng, giả lập Android 17 / API 37:** [Đình báo ca đạt](https://github.com/tungcorn/project-ptuddd/issues/22#issuecomment-7195030116), có log vòng đời và thử được lượt mới; không phải kiểm tra mic trên điện thoại thật.
- [Biên bản, SHA APK và checklist bàn giao](docs/kiem-thu/demo-tich-hop.md) ghi riêng kết quả từng bản và phần chưa kiểm chứng.

### Kết quả kiểm tra lịch sử (16/11/2026)

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

Mỗi người phụ trách cả giao diện, logic, dữ liệu, kiểm thử và phần báo cáo/demo của mình. Cả nhóm chuẩn bị nội dung bài hát và review chéo; nhóm trưởng điều phối tích hợp, không mặc định làm thay các mô-đun. Phân công nghiệp vụ tổng thể ở mục 9–10 của đề cương; **đợt hoàn thiện hiện tại áp dụng [bốn nhiệm vụ, quyền sửa file và quy tắc phối hợp](docs/PHAN_CONG_HOAN_THIEN.md)**. Đây là kế hoạch công việc, không phải xác nhận đóng góp hoặc kết quả kiểm thử đã hoàn thành.

## 5. Quy định nộp bài và việc còn thiếu

- Nhánh và thư mục nộp bài: **`nhom10-65ktpm`**; chỉ thay đổi trong thư mục nhóm. Nộp theo quy trình Fork/PR trong [README học phần](../README.md).
- Không đưa APK/AAB, thư mục build/cache, `firebase.env.json`, khóa bí mật, service-account hoặc keystore vào kho.

**Giới hạn kiểm thử và việc bàn giao:**

1. Chưa có kết quả Firebase hai Android với thao tác offline gửi muộn (#20), đổi tài khoản để kiểm tra tiến độ theo từng bài (#21) hoặc gửi email reset vào hộp thư được phép.
2. Ca Home đã đạt trên giả lập `be084f3`; chưa có kết quả riêng cho nút Dừng khi đang nhận dạng trên cùng APK (#22). Nhắc học, tải mô hình ML Kit, chọn file quản trị và điều khiển trực tiếp trên màn hình khóa chưa kiểm chứng trên bản demo và không thuộc kịch bản chính.
3. Luồng flashcard thủ công trên `94e1ee3` đã đạt; chưa chạy lại runner `integration_test/app_e2e_test.dart` trên bản tích hợp. Không đồng nhất hai kết quả.
4. Hoàn thành báo cáo cuối kỳ và chuẩn bị vấn đáp theo [checklist bàn giao](docs/kiem-thu/demo-tich-hop.md); xác nhận danh sách nhóm và tỷ lệ đóng góp thực tế. Đối chiếu yêu cầu nộp slide/video riêng. Bản ký release chỉ cần khi phát hành, không phải điều kiện demo debug.

## 6. Quy trình Git nội bộ nhóm

Các lệnh Git dưới đây chạy từ **thư mục gốc kho `project-ptuddd`**. `origin` là
`https://github.com/tungcorn/project-ptuddd.git`. Nhánh tích hợp của nhóm là
`nhom10-65ktpm`; **mọi nhiệm vụ phát triển, kể cả của nhóm trưởng/admin**, làm
trên nhánh tính năng rồi mở PR vào nhánh này và được người khác review.
Trước khi sửa, đọc [phân công đợt hoàn thiện](docs/PHAN_CONG_HOAN_THIEN.md) và issue:
chỉ sửa phần được giao, phối hợp trước khi đụng file chung hoặc đổi giao tiếp.
Không commit/push trực tiếp vào `main`, không sửa tệp gốc hoặc thư mục nhóm khác.

### 6.1. Lấy mã nguồn và tạo nhánh làm việc

Lần đầu, sau khi chấp nhận lời mời cộng tác:

```bash
git clone https://github.com/tungcorn/project-ptuddd.git
cd project-ptuddd
git switch --track origin/nhom10-65ktpm
```

Trước mỗi đầu việc mới, bảo đảm công việc cũ đã được commit hoặc cất riêng;
không bỏ thay đổi chưa lưu chỉ để chuyển nhánh. Nếu đã có nhánh nhóm trên máy:

```bash
git switch nhom10-65ktpm
git pull --ff-only origin nhom10-65ktpm
git switch -c feature/nhom10-65ktpm/on-flashcard
```

Tên nhánh theo mẫu `feature/nhom10-65ktpm/<dau-viec>`, viết thường, không dấu,
không khoảng trắng; ví dụ `feature/nhom10-65ktpm/sua-tim-ban`.
Mỗi đầu việc dùng một nhánh riêng xuất phát từ nhánh nhóm mới nhất, không từ
`main` hoặc nhánh tính năng chưa merge của người khác. Nếu `pull --ff-only`
báo lịch sử phân kỳ, dừng kiểm tra với nhóm trưởng, không dùng reset/force push.

### 6.2. Nội dung commit và kiểm tra trước khi push

**Mọi commit mới của thành viên** dùng mẫu đã thống nhất theo README học phần:

```text
<loai-thay-doi>(nhom10-65ktpm): <mo-ta-ngan-gon>
```

| Loại | Khi dùng | Ví dụ |
| --- | --- | --- |
| `feat` | Thêm chức năng | `feat(nhom10-65ktpm): them loc bai hat theo trinh do` |
| `fix` | Sửa lỗi | `fix(nhom10-65ktpm): sua lich on flashcard` |
| `docs` | Cập nhật tài liệu | `docs(nhom10-65ktpm): huong dan chay Firebase` |

Mô tả rõ việc thực sự thay đổi, không ghi chung chung như `update`, `done`.
Mỗi commit tập trung một đầu việc. Dùng danh tính Git của chính mình và email
đã liên kết GitHub; không mượn danh tính thành viên khác.

Sau khi sửa code, chạy kiểm tra trong thư mục Flutter:

```bash
cd nhom10-65ktpm/src
flutter analyze
flutter test
cd ../..
```

Thêm kiểm thử thiết bị hoặc rules khi thay đổi liên quan. Nếu chỉ sửa tài liệu,
kiểm tra nội dung/liên kết và ghi rõ không chạy kiểm thử ứng dụng.

```bash
git status
git diff
git add -- nhom10-65ktpm/
git diff --cached --check
git diff --cached
git commit -m "fix(nhom10-65ktpm): sua lich on flashcard"
git push -u origin feature/nhom10-65ktpm/on-flashcard
```

Thay tên nhánh và thông điệp ví dụ bằng đầu việc của mình. Chỉ stage tệp liên
quan; có thể chỉ định từng tệp bên trong thư mục nhóm thay vì cả thư mục.
Không dùng `git add .` ở gốc kho, không đưa cấu hình Firebase cục bộ, token,
keystore, APK hoặc build/cache vào commit.

### 6.3. Tạo PR nội bộ

Sau khi push nhánh tính năng, vào kho **`tungcorn/project-ptuddd`** trên GitHub:

1. Chọn **Pull requests → New pull request**.
2. Chọn **base: `nhom10-65ktpm`**, **compare: nhánh tính năng của mình**;
   cả hai đều thuộc kho nhóm, không chọn kho giảng viên hoặc base `main`.
3. Đặt tiêu đề cùng mẫu commit, ví dụ `fix(nhom10-65ktpm): sua lich on flashcard`.
4. Sao chép [mẫu PR nội bộ](docs/PR_TEMPLATE.md) vào phần mô tả, điền mục tiêu,
   thay đổi, ảnh hưởng mô-đun khác, kết quả kiểm thử và cách review; bỏ placeholder.
   GitHub **không tự điền** mẫu đặt trong thư mục nhóm.
5. Kiểm tra **Files changed**: chỉ có tệp liên quan trong `nhom10-65ktpm/`,
   không có khóa/cấu hình riêng hoặc tệp sinh tự động. Tạo PR và nhờ người khác review.

Nếu dùng GitHub CLI, có thể mở trình tạo PR trên trình duyệt bằng lệnh sau
(thay nhánh và tiêu đề cho đúng, rồi điền mô tả bằng mẫu trên):

```bash
gh pr create --repo tungcorn/project-ptuddd --base nhom10-65ktpm --head feature/nhom10-65ktpm/on-flashcard --title "fix(nhom10-65ktpm): sua lich on flashcard" --web
```

### 6.4. Cập nhật PR và merge

- Mọi nhiệm vụ phát triển, **kể cả của nhóm trưởng/admin**, đi qua PR vào
  `nhom10-65ktpm`, có ít nhất **1 người khác duyệt** và giải quyết các trao đổi review.
  Người tạo PR không tự duyệt. Commit mới làm mất hiệu lực lượt duyệt cũ, cần review lại.
- Sửa theo review rồi commit/push tiếp **trên cùng nhánh tính năng**, PR tự cập nhật;
  không cần mở PR mới cho mỗi commit.
- Nếu cần đồng bộ nhánh nhóm vào nhánh tính năng: khi working tree sạch, chạy
  `git fetch origin` rồi `git merge origin/nhom10-65ktpm -m "fix(nhom10-65ktpm): dong bo nhanh nhom vao nhanh tinh nang"`
  ngay trên nhánh tính năng. Không ghi đè code của người khác; sau khi xử lý
  xung đột phải chạy lại kiểm thử ứng dụng trước khi commit hoàn tất merge và push.
- Chỉ nhóm trưởng thực hiện merge vào `nhom10-65ktpm`. Sau khi có đủ review
  và xử lý các góp ý, nhóm trưởng dùng quyền bypass giới hạn cập nhật nhánh qua PR
  để merge; quyền này không thay thế approval của người khác hoặc cho phép push
  trực tiếp lên nhánh nhóm. Không force push hoặc xóa nhánh nhóm.
- Sau khi PR được merge, quay lại nhánh nhóm và `git pull --ff-only origin nhom10-65ktpm`;
  đầu việc tiếp theo tạo nhánh mới. **Đóng (Close) PR không có nghĩa là đã merge**.

PR nội bộ này khác PR **nộp bài cho giảng viên**: việc nộp bài do nhóm trưởng
thực hiện riêng từ nhánh `nhom10-65ktpm` của kho nhóm vào `main` của kho giảng viên,
theo [README học phần](../README.md). Không dùng mẫu nộp bài cho PR giữa các thành viên.
