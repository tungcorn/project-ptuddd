# Chạy SingLearn trên Android giả lập

## Phạm vi hiện tại — 21/11/2026

Công cụ và test được chuyển từ thay đổi cục bộ lên nền nhánh nhóm `d910601` (sau #19), phục vụ chuẩn bị #23. Không phải bằng chứng đã nghiệm thu bản Android tích hợp cuối. Các kết quả 18–19/11 ở cuối tài liệu thuộc bản nguồn cũ, không được dùng thay kết quả runner trên nhánh mới.

Script chỉ **mở AVD đã có**, không cài SDK/image, không tạo AVD, không đổi BIOS/hypervisor hay cấu hình toàn máy. Các đường dẫn ổ D bên dưới là ví dụ của máy đã kiểm tra; máy khác truyền tham số phù hợp. Không commit thư mục AVD, log, APK, cấu hình Firebase thật hoặc bằng chứng riêng tư.

## Cấu hình tham chiếu đã thiết lập ngày 18/11/2026

- SDK: `D:\Android\Sdk`; Flutter đo khi thiết lập: 3.47.2 / Dart 3.13.2 tại `D:\flutter`. Không coi số này là phiên bản bắt buộc của mọi máy.
- System image: `system-images;android-35;google_apis;x86_64` (Android 15/API 35, không phải Google Play image).
- AVD: `SingLearn_API35`, dữ liệu ở `D:\Android\SingLearn\avd`.
- 2 lõi, màn hình 720×1280, density 320. Script yêu cầu RAM 2048 MB nhưng image đã nâng tối thiểu lên **2560 MB**; tiến trình Windows có thể dùng nhiều hơn RAM khách.
- Image nâng phân vùng userdata tối thiểu lên **6 GiB** dù yêu cầu 4 GiB; đây không phải toàn bộ dung lượng đã ghi ra đĩa.
- WHPX có sẵn và hoạt động; không đổi cấu hình toàn máy để chạy kiểm tra này.
- Log/temp ở `D:\Android\SingLearn\logs` và `D:\Android\SingLearn\temp`. Temp lúc cài image là `D:\Temp\singlearn-emulator`.

## Mở và chạy app

Từ `nhom10-65ktpm/src/`, dùng PowerShell:

```powershell
..\tools\start_android_emulator.ps1
D:\flutter\bin\flutter.bat run --no-pub -d emulator-5554
```

Nếu đường dẫn hoặc AVD khác, truyền rõ:

```powershell
..\tools\start_android_emulator.ps1 -SdkRoot 'D:\Android\Sdk' -AvdHome 'D:\Android\SingLearn\avd' -AvdName 'SingLearn_API35' -Port 5554
```

Script mở cửa sổ, chờ boot tối đa 6 phút và không mở thêm máy nếu đúng AVD ở cổng đã chọn đã chạy. Lần boot đầu từng vượt 3 phút; không xóa/wipe dữ liệu để chữa timeout. Nếu máy còn đang boot, chờ vào màn hình Android rồi thử lại. `-Headless` bỏ cửa sổ, không thay đổi ý nghĩa kiểm thử.

Luôn chỉ định `-d emulator-5554` (hoặc serial đúng với `-Port`) để không chọn nhầm điện thoại. Cổng console phải chẵn trong khoảng 5554–5682; nếu cổng đã thuộc AVD khác, chọn cổng khác. Script chỉ đặt `ANDROID_AVD_HOME`, `TEMP`, `TMP` cho lúc tạo tiến trình con rồi khôi phục giá trị của bên gọi. Không cần mở Android Studio.

Đóng cửa sổ khi không dùng để trả RAM, hoặc:

```powershell
& D:\Android\Sdk\platform-tools\adb.exe -s emulator-5554 emu kill
```

## Chạy integration test local

**Dùng AVD dành cho kiểm thử, không dùng phiên/dữ liệu cá nhân trên điện thoại.** Test có thể đăng xuất phiên local, tạo tài khoản local mới hoặc chuyển sang khách, lưu từ/tiến độ; không tự xóa dữ liệu. Không chạy đồng thời hai lệnh test/run trên cùng thiết bị.

Không truyền `firebase.env.json` hoặc Firebase defines. Cả hai test kiểm tra cấu hình local **trước bootstrap**, không dùng chúng để kiểm thử cloud thật.

```powershell
flutter test --no-pub integration_test/app_e2e_test.dart -d emulator-5554 --reporter expanded
flutter test --no-pub integration_test/m1_learning_clips_test.dart -d emulator-5554 --reporter expanded
```

Có driver chuẩn để dùng đường `flutter drive` khi cần; đây là runner thay thế, không phải bằng chứng test đã đạt:

```powershell
flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/app_e2e_test.dart -d emulator-5554
flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/m1_learning_clips_test.dart -d emulator-5554
```

- `app_e2e_test.dart`: đăng ký local → xếp trình độ → Silent Night → tốc độ/lặp câu → tra/lưu từ → flashcard/SM-2. Chuyển từ bản cục bộ các thao tác cuộn cho màn hình nhỏ và đóng bàn phím; giữ kiểm tra flashcard đã có trên nhánh nhóm. Cuối test chỉ đọc lại store đang mở, **không phải kiểm thử đóng/mở app hoặc Hive**.
- `m1_learning_clips_test.dart`: ba đoạn học qua thư viện/player, tiến vị trí plugin, lời song ngữ/nghĩa từ, tua và kết thúc; một ca nghe lại đoạn câu trên Little Tomcat. Không coi vị trí tiến là đã nghe rà chất lượng âm thanh hoặc đã thử micro.
- Integration runner cài app có harness. Chạy lại `flutter run` ở trên để quay về app thông thường; không dùng APK test làm bản demo cuối.
- Chỉ nhận PASS khi lệnh kết thúc thành công và các assertion chạy đủ. Build/boot thành công hoặc smoke ADB thủ công không phải PASS của integration runner.

Kiểm tra phần chuẩn bị ngày 21/11/2026 trên nhánh `feature/nhom10-65ktpm/kiem-thu-android-gia-lap`, từ base `d910601`:

| Kiểm tra | Kết quả |
| --- | --- |
| `flutter analyze --no-pub integration_test test_driver` | No issues found, exit 0 |
| Format ba file Dart bằng SDK, rồi `dart format --output=none --set-exit-if-changed ...` | 0 file đổi ở lượt check, exit 0 |
| `flutter test --no-pub test/unit/content_test.dart test/unit/player_controller_test.dart test/widget/player_vocab_test.dart` | 33/33 đạt, exit 0; đây là unit/widget, không phải integration runner |
| Parser PowerShell và guard tham số | Cú pháp hợp lệ; chặn cổng 5555/5552/5684 và SDK không tồn tại trước khi gọi ADB/emulator: 5 kiểm tra đạt |
| Boot/Android integration runner trên nhánh mới | Chưa chạy trong lượt chuẩn bị; không nhận PASS |

Lệnh validation PowerShell đầu tiên dùng kiểu exception không truy cập được nên lỗi ở harness kiểm tra; đổi sang bắt lỗi qua `FullyQualifiedErrorId` rồi chạy lại các guard đạt. Không khởi động emulator để thực hiện các ca validation trên. Chưa có kết quả integration runner mới trên nền `d910601`; cần chạy trên AVD kiểm thử trước khi xác nhận luồng mới. Vòng Android cuối chờ các phần việc tích hợp/kiểm chứng còn lại, không đóng #23 từ PR công cụ.

## Lịch sử smoke trực tiếp ngày 19/11/2026

Phần này giữ bằng chứng cũ, **không mô tả nhánh hiện tại**:

- App thông thường được build/cài bằng `flutter build apk --debug --no-pub --target lib/main.dart` và `adb install -r`, mở `com.gr10.singlearn/.MainActivity`; không phải integration harness.
- Android 15/API 35, `emulator-5554`, 720×1280, density 320. Nguồn `01937ca` cộng thay đổi test/tài liệu cục bộ, chưa có sửa seek #7 tại thời điểm đó; #7 sau này đã được tích hợp. Không Firebase defines; dùng phiên Tester local có sẵn, không tạo tài khoản cloud hay xóa dữ liệu.
- Build thành công, Gradle 390 giây. Có cảnh báo Kotlin tương lai và SDK XML; không nâng dependencies/công cụ. Khi boot, hệ thống giả lập từng hiện `System UI isn't responding`; chọn Wait một lần rồi launcher chạy. Không quy kết đó là lỗi SingLearn.
- Điều khiển bằng ADB và xem ảnh thực tế; XML accessibility đôi lúc chậm hơn hình ảnh nên không dùng XML đơn độc để kết luận trạng thái player.

| Ca | Quan sát ngày 19/11 | Tên ảnh cục bộ |
| --- | --- | --- |
| Tìm Learn To Fly | Thư viện 11 bài; tìm đúng đoạn 1:01 | `05-learn-search.png` |
| Phát/LRC/song ngữ | Vị trí tới 0:17, đang phát, câu được tô và có bản dịch | `07-learn-bilingual.png` |
| Tra/lưu từ | `eagle` → “đại bàng”, có ví dụ/ngữ cảnh; lưu flashcard | `08-learn-eagle-lookup.png`, `09-eagle-saved.png` |
| Tua/kết thúc Learn To Fly | Tua 0:58, hết bài về 0:00; media PAUSED, error=null | `10-learn-near-end.png`, `12-learn-resume.png` |
| Little Tomcat | Đoạn 0:47, vị trí tới 0:30, song ngữ; hết bài về 0:00/dừng | `15-tomcat-bilingual.png`, `17-tomcat-completed.png` |
| Tra từ Little Tomcat | `tomcat` → “mèo đực”, có ví dụ/ngữ cảnh | `16-tomcat-lookup.png` |
| Điền từ/nghe lại | Đoạn câu tự dừng; Nghe lại phát; điền `close` đúng 1/1 | `19-tomcat-cloze.png` đến `22-cloze-graded.png` |
| Flashcard/SM-2 | Ôn `eagle`, chọn Nhớ: xong 1/1, +5 XP, lịch 20/11 | `23-vocabulary.png` đến `27-vocabulary-after-review.png` |
| Restart tiến trình | Force-stop rồi mở lại: từ/nghĩa/ngữ cảnh/lịch còn, phiên Tester và tổng 30 XP còn | `29-vocabulary-persisted.png`, `30-home-persisted-xp.png` |

Ảnh/XML và driver cục bộ lưu ngoài repo tại `D:\Android\SingLearn\evidence\20261119\`, không đính kèm ảnh riêng/build vào Git. Đây là smoke UI thủ công; không phải PASS của hai integration test. Không chạy lại đăng ký/xếp trình độ và toàn bộ bài tập trong lượt smoke này. Không suy ra tính đúng toàn diện của SM-2/XP từ một lượt quan sát.

## Giới hạn

Giả lập phù hợp cho UI, local storage và một số hành vi plugin. Không thay thế điện thoại thật cho micro, nhận dạng giọng nói, chất lượng âm thanh, audio focus/cuộc gọi, màn hình khóa từng hãng hoặc Doze dài hạn. Không bật Google sign-in/Firebase, tải model dịch hay thay cấu hình hệ thống chỉ để chạy các ca trên.
