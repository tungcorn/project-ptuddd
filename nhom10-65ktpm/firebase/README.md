# Firebase cho SingLearn

## Phạm vi cấu hình

- Project ID: `singlearn-nhom10-65ktpm` – tách biệt với dự án StudyDoc.
- [Firebase Console](https://console.firebase.google.com/project/singlearn-nhom10-65ktpm/overview).
- Android package: `com.gr10.singlearn`.
- Firestore `(default)`: Standard, vùng `asia-southeast1` (Singapore), có bảo vệ xóa database.
- Authentication: email/mật khẩu. Google sign-in chưa bật.
- Không liên kết billing; không triển khai Storage, Functions, Hosting hoặc gửi SMS.
- Audio, ảnh và LRC có sẵn trong assets; Hive vẫn là kho lưu cục bộ.

Gói Spark có giới hạn sử dụng. Không coi đây là hạ tầng miễn phí không giới hạn;
không tự chuyển sang Blaze hoặc liên kết tài khoản thanh toán khi chạm quota.
Tên bucket trong cấu hình SDK không có nghĩa bucket đã được tạo hoặc Storage đã bật.

## Kết quả kiểm tra backend (18/11/2026)

- API xác nhận không liên kết tài khoản thanh toán, `billingEnabled: false`.
- Firestore được tạo với `freeTier: true`; Auth email/mật khẩu đã bật.
- 15/15 kiểm thử rules đạt trên Firestore Emulator.
- Smoke test cloud đạt: đăng ký hai tài khoản giả, lưu/đọc dữ liệu từ server,
  chặn tài khoản khác đọc/ghi dữ liệu riêng, không cho ghi email vào hồ sơ
  công khai, đăng xuất/đăng nhập vẫn đọc lại được từ đã lưu.
- Tài khoản và document giả của smoke test đã được dọn sạch.
- `flutter analyze --no-pub`: không có lỗi; `flutter test --no-pub`: 98/98 đạt.
- Build APK debug với `--dart-define-from-file=firebase.env.json` thành công.
  Có cảnh báo tương thích KGP của plugin và phiên bản SDK XML; không làm build thất bại.
- Chưa kiểm chứng Flutter cloud trên Android, offline hoặc đồng bộ hai máy.

## Chạy ứng dụng Android

Từ `nhom10-65ktpm/src/`:

```bash
flutter run --dart-define-from-file=firebase.env.json -d <android-device-id>
```

`firebase.env.json` là cấu hình cục bộ đã được `.gitignore` loại trừ. Máy khác
sao chép `../firebase/firebase.env.example.json` thành `firebase.env.json`, rồi
lấy cấu hình Android từ Firebase Console → Project settings → Your apps.
Không đưa service account, OAuth token, mật khẩu hoặc khóa ký vào tệp này.
Firebase API key của ứng dụng không thay thế Security Rules.

Không truyền tệp cấu hình thì ứng dụng chạy ở chế độ tài khoản local. Tài khoản
local không tự chuyển thành Firebase account; hai loại tài khoản có UID và dữ
liệu riêng. Không xóa dữ liệu Hive cũ khi đổi chế độ.

Các cờ tùy chọn mặc định là `false`:

- `FIREBASE_ENABLE_STORAGE`: chỉ bật sau khi đã thống nhất chi phí và cấu hình Storage.
- `FIREBASE_ENABLE_MESSAGING`: chỉ bật khi đã có cấu hình FCM và bên gửi phù hợp.
- `FIREBASE_ENABLE_GOOGLE_SIGN_IN`: cần bật provider Google, cấu hình OAuth và SHA cho Android trước.

Admin cloud dùng custom claim `admin: true`, không dùng danh sách admin local.
Không tự gán admin cho mọi người đăng ký và không triển khai Functions để gán quyền
chỉ nhằm hoàn tất bước setup.

## Rules và dữ liệu

- `users/{uid}/...`: chỉ chính tài khoản đó đọc/ghi dữ liệu học riêng.
- `songs`: người đã đăng nhập được đọc; chỉ admin có custom claim được ghi.
- `publicProfiles`: người đã đăng nhập được đọc; cấm trường email và các trường ngoài danh sách cho phép.
- Tìm bạn trong cloud bằng mã 6 ký tự, không công khai email để tìm kiếm.
- Lời mời kết bạn chỉ người nhận được chấp nhận, không được thay người gửi hoặc thành viên.
- Thử thách chỉ tạo giữa bạn bè đã chấp nhận; người nhận chỉ trả lời một lần,
  không được sửa câu hỏi, người tham gia hoặc điểm người gửi.

XP và điểm thử thách vẫn do client báo cáo. Rules chặn truy cập trái phép và
thay đổi ngoài phạm vi, nhưng không biến điểm thành kết quả chống gian lận đã
được server xác minh.

## Triển khai có giới hạn

Chỉ thực hiện khi được nhóm trưởng cho phép. Từ `nhom10-65ktpm/firebase/`:

```bash
npm exec --yes --package=firebase-tools@15.36.0 --call "firebase deploy --only auth,firestore --project singlearn-nhom10-65ktpm --config firebase.json"
```

`firebase.json` mặc định không chứa cấu hình triển khai Storage hoặc Functions.
Mã tham khảo trong `functions/` và `storage.rules` được giữ lại nhưng chưa bật.
Không chạy lệnh triển khai sang dự án StudyDoc hoặc dự án khác.

## Kiểm thử rules trên emulator

Yêu cầu Node tương thích thư viện kiểm thử, Java 21 trở lên và các cổng
8080/9099 không bị ứng dụng khác chiếm. Các phiên bản thư viện được khóa trong
`package-lock.json`; không thay đổi Node/Java toàn máy chỉ để chạy kiểm thử.

Từ `nhom10-65ktpm/firebase/`:

```bash
npm ci --ignore-scripts
npm exec --yes --package=firebase-tools@15.36.0 --call "firebase emulators:exec --only firestore --project demo-singlearn --config firebase.json \"node --test test/firestore.rules.test.cjs\""
```

Bộ test dùng `demo-singlearn` và host emulator tường minh, không chạy lên dữ
liệu cloud thật. Bao phủ phân quyền giữa tài khoản, email trong hồ sơ công khai,
quyền quản trị nội dung, lời mời kết bạn và tính bất biến của thử thách.

## Smoke test cloud có chủ đích

Chỉ chạy khi được phép kiểm tra dự án thật. Từ thư mục `firebase/`:

```bash
node test/cloud_smoke.cjs ../src/firebase.env.json
```

Script chỉ chấp nhận Project ID SingLearn ở trên, tạo hai tài khoản giả và một
ít document riêng để kiểm tra đăng nhập, lưu/đọc từ, tách biệt tài khoản và
quyền riêng tư email. Nó xóa tài khoản/document đã tạo trong `finally` và báo
lỗi nếu dọn dẹp không hoàn tất. Không gửi email hoặc ghi token ra log.

Smoke test này kiểm tra backend qua Firebase JS SDK, không thay thế kiểm thử
Flutter trên điện thoại, offline, khởi động lại tiến trình hoặc đồng bộ hai máy.
