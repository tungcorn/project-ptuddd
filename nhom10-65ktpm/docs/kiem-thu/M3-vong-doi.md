# M3 — vòng đời, cài đặt micro và ledger

Ngày cập nhật: 21/11/2026. Owner: DaoNgocDinh. Liên quan #4; phối hợp ledger tại #5.

## Review độc lập và cập nhật ngày 21/11/2026

Nguồn: [bình luận của tungcorn trên PR #17](https://github.com/tungcorn/project-ptuddd/pull/17#issuecomment-7054327231),
07:39 giờ Việt Nam ngày 21/11/2026. Đây là kết quả reviewer chạy độc lập,
không phải lượt chạy của agent/owner.

| Phiên bản reviewer kiểm tra | Kết quả reviewer xác nhận |
| --- | --- |
| Head #17 `d4dba7da7e8b36315ece0181c63202ae5a759e2f` | Analyze 4 file No issues found, exit 0; bộ 7 file unit/widget 58/58 đạt, exit 0 |
| Ghép #16 `1afa8d6` + #17 `d4dba7d`, tree `f4ec4415b9f00485f449cdfcbba70d076915110c` | Không xung đột; analyze 5 file sạch; cùng bộ 7 file 68/68 đạt, exit 0 |
| Kiểm tra format hai file test mới trên SDK reviewer | Còn thay đổi cần format; lệnh check trả exit 1 ở bản d4dba7d |

Sau review chỉ chỉnh bố cục hai file test được nêu và tài liệu. Mã production,
test case, assertion, chuỗi dữ liệu và hành vi giữ nguyên. Đã đối chiếu token
trước/sau, bỏ qua whitespace và dấu phẩy cuối tùy chọn: không có thay đổi token
còn lại. Đây là kiểm tra phạm vi chỉnh sửa, không thay thế Dart analyzer/test.

Môi trường agent ngày 21/11 vẫn không chạy được SDK formatter: gọi trực tiếp
Dart AOT runtime dừng trước format với `Failed to canonicalize path ... (5)`;
launcher trước đó lỗi `resolved_executable_name`. Bố cục được chỉnh trực tiếp;
**chưa xác nhận `dart format --output=none --set-exit-if-changed` trả exit 0**
trên bản sau cập nhật. Nhờ reviewer kiểm tra lại đúng hai file trước khi approve.
Không gọi 58/58 hoặc 68/68 là lượt chạy trên commit mới sau chỉnh bố cục.

```powershell
dart format --output=none --set-exit-if-changed test/widget/practice_pronunciation_lifecycle_test.dart test/unit/pronunciation_ledger_test.dart
```

PR #16 đã approve/merge vào nhánh nhóm tại
`0cdeaf304ffba386f2d9d80ef664bc47f4be6fda`. M1 đã nhận phần player và mở
[PR #18](https://github.com/tungcorn/project-ptuddd/pull/18); M3 tiếp tục review
và bổ sung ca UI đổi câu/thoát trong lúc seek chờ theo phối hợp trên #4.
Kết quả trên vẫn là local/unit/widget, chưa chứng minh Android micro, cloud
hoặc crash recovery. Issue #4 tiếp tục In progress.

## Phạm vi và nền lịch sử

Nhánh `feature/nhom10-65ktpm/vong-doi-phat-am` được tạo trực tiếp từ
`f21d04d861e0cecc1bd8d2273527dec63e5c8865` của `nhom10-65ktpm`.
Không lấy lịch sử nhánh cũ hoặc commit sửa `.gitignore` gốc vào nhánh này.
PR #16 xử lý final/done sau Dừng riêng và đã merge; kết quả ghép với phần này
được ghi đúng tree ở trên. Không dùng kết quả 54/54 trên bản cũ của #16 hay
71/71 của nền trước đây làm kết quả của patch này.

Lỗi có thể thấy từ code nền: màn không quan sát vòng đời ứng dụng nên lượt xin
quyền/khởi tạo đang chờ vẫn có thể tiếp tục khi app đã xuống nền; callback đang
nghe vẫn có thể ghi kết quả. Nút mở cài đặt chưa bắt exception, adapter bỏ qua
giá trị `false` của `openAppSettings()` nên người dùng không biết mở thất bại.

## Thay đổi

- Quan sát `paused`/`detached`: tăng phiên, hủy timer chuẩn bị, yêu cầu cancel
  best effort và về idle; callback cũ không được chấm/ghi điểm. Trở lại app
  cần chủ động nhấn micro để tạo lượt mới.
- Không hủy vì `inactive` đơn lẻ, để hộp thoại quyền không làm hỏng lượt chuẩn bị.
- Bắt lỗi mở cài đặt, hướng dẫn mở quyền micro thủ công. Lỗi trả muộn sau khi
  thoát/đổi phiên không hiện thông báo lên màn khác. Adapter chuyển `false`
  thành lỗi để màn xử lý; giao tiếp `Future<void> openSettings()` giữ nguyên.
- Test riêng M3 dùng `ProgressService`/`SyncService` hiện có, giữ event ID/schema
  và XP policy. Không sửa production code M4, player, Android, dependencies
  hoặc helper chung. Đã báo phần phối hợp trước khi làm trên #4/#5.

## Ca hồi quy mới và kết quả thật

`practice_pronunciation_lifecycle_test.dart` có 11 ca widget/adapter;
`pronunciation_ledger_test.dart` có 3 ca unit. Agent chưa tự chạy thành công;
reviewer đã xác nhận bộ liên quan ở đúng SHA/tree trong bảng đầu tài liệu.

| Nhóm ca | Điều kiện cần kiểm chứng |
| --- | --- |
| Permission chờ rồi paused/resumed | Cancel một lần; grant muộn không initialize/listen; lượt mới nghe được |
| Initialize chờ rồi detached/resumed | Kết quả khởi tạo cũ bị bỏ; lượt mới khởi tạo/nghe được |
| Hộp thoại chỉ inactive/resumed | Không cancel; grant vẫn bắt đầu nhận dạng |
| Đang nghe rồi xuống nền | Bỏ partial/final/error/done cũ, không phát event; lượt mới chỉ chấm một lần |
| Đang Dừng rồi xuống nền | Exception stop cũ được chứa, không hiện kết quả; thử lại được |
| Cancel khi xuống nền bị lỗi | Không phát exception ra UI; thử lại được; không kết luận phần cứng đã tắt |
| Mở cài đặt bị lỗi / lỗi muộn sau thoát | Có hướng dẫn phục hồi, còn thử lại được; không có thông báo sau thoát |
| Adapter mở cài đặt | Mock đúng channel permission_handler: false là lỗi, PlatformException được truyền, true hoàn tất |
| Ledger nhiều lượt đạt đồng thời | Cùng daily ID chỉ có một entry/+5 XP và một pending operation |
| 69 điểm rồi 70 điểm | Lượt thấp có `:try:` riêng/+0 XP, chưa chiếm phần thưởng daily; đạt được +5 một lần |
| Đóng/mở Hive khi offline | Ledger và queue còn nguyên, retry không thêm XP/queue; online fake flush đúng một lần |

Lịch sử triển khai ngày 20/11: đã kiểm tra `git diff --check` và rà soát phạm vi.
Flutter launcher không trả
kết quả phân tích; gọi Dart/flutter_tools trực tiếp vẫn lỗi trước khi nạp test:

```text
Empty value for option resolved_executable_name
Setting VM flags failed: Unrecognized flags: resolved_executable_name
```

Tại thời điểm triển khai, analyze/unit/widget/format chưa được agent xác nhận,
nên đã mở Draft. Kết quả reviewer ngày 21/11 và bước chỉnh sau review được ghi
riêng ở đầu tài liệu; không thay lịch sử này thành lượt agent tự chạy đạt.

Chạy lại tại `nhom10-65ktpm/src` và ghi `git rev-parse HEAD` cùng kết quả:

```powershell
flutter analyze --no-pub lib/features/practice/presentation/pronunciation_screen.dart lib/features/practice/presentation/speech_recognizer.dart test/widget/practice_pronunciation_lifecycle_test.dart test/unit/pronunciation_ledger_test.dart
flutter test --no-pub test/unit/pronunciation_test.dart test/unit/exercises_test.dart test/widget/practice_pronunciation_test.dart test/widget/practice_fill_blank_test.dart test/widget/practice_ordering_quiz_test.dart test/widget/practice_pronunciation_lifecycle_test.dart test/unit/pronunciation_ledger_test.dart --reporter expanded
```

Khi kiểm tra cây tích hợp, thêm `practice_pronunciation_test.dart` vào analyze.
Reviewer đã chạy cây `f4ec4415...` trước chỉnh bố cục; khi có thêm thay đổi logic
hoặc tích hợp #18 cần kiểm tra lại trên chính cây mới, không dùng số cũ thay thế.

## Giới hạn còn lại và phối hợp

- Session guard bảo vệ UI/event; cancel là best effort, không hủy được một
  Future native đang chạy và không chứng minh micro vật lý đã tắt. Race khi
  `listen()` native đang khởi động và thiếu callback kết thúc tự nhiên cần
  kiểm chứng/điều tra tiếp; patch này không thay đổi cơ chế native đó.
- Khi ghép #16, lượt Dừng cũ bị vô hiệu theo phiên nhưng waiter có thể còn tới
  timeout 5 giây hoặc lượt mới/dispose. Không mô tả đây là hủy ngay Future stop.
- M1 đã nhận token/cancel continuation player tại #18; M3 không tự sửa chồng
  controller/API chung. Ca UI đổi câu/thoát khi seek chờ và review #18 vẫn là
  phần việc M3 theo phối hợp trên #4, chưa được tính đã nghiệm thu trong #17.
- Ledger test dùng Hive thật và `FakeRemote`, không gọi cloud/email. Việc mở
  lại store trong cùng test chưa chứng minh crash recovery/atomicity, logout
  đa tài khoản, Firestore rules hoặc đồng bộ thiết bị thật.
- ADB chưa khởi động/kết nối được trong môi trường agent. Chưa xác định danh
  sách thiết bị, chưa có kết quả micro Android thật; không kết luận không có
  điện thoại. Không có ảnh/video UI hay số ca Android đạt.

Trước khi đóng #4 cần review/merge các PR liên quan, kiểm tra tích hợp và ghi
một vòng micro thật: model/OS/dịch vụ nhận dạng/điều kiện mạng; cấp quyền nói
một câu, từ chối rồi thử lại, không nói/lỗi, Dừng, đổi câu/thoát, background/resume.
Ghi expected/actual từng ca; nếu thiếu thiết bị/dịch vụ thì giữ blocker rõ ràng.
Issue tiếp tục In progress, chưa chuyển Done.
