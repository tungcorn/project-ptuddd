# M3 — vòng đời, cài đặt micro và ledger

Ngày cập nhật: 20/11/2026. Owner: DaoNgocDinh. Liên quan #4; phối hợp ledger tại #5.

## Phạm vi và nền lịch sử

Nhánh `feature/nhom10-65ktpm/vong-doi-phat-am` được tạo trực tiếp từ
`f21d04d861e0cecc1bd8d2273527dec63e5c8865` của `nhom10-65ktpm`.
Không lấy lịch sử nhánh cũ hoặc commit sửa `.gitignore` gốc vào nhánh này.
PR #16 xử lý final/done sau Dừng riêng; cần review/merge và chạy kiểm tra tích hợp
hai phần trước khi nghiệm thu M3. Không dùng kết quả 54/54 trên bản cũ của #16
hay 71/71 của nền trước đây làm kết quả của patch này.

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
`pronunciation_ledger_test.dart` có 3 ca unit. Đây là số ca đã viết, **chưa có
kết quả chạy thành công** trong môi trường agent.

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

Đã kiểm tra `git diff --check` và rà soát phạm vi. Flutter launcher không trả
kết quả phân tích; gọi Dart/flutter_tools trực tiếp vẫn lỗi trước khi nạp test:

```text
Empty value for option resolved_executable_name
Setting VM flags failed: Unrecognized flags: resolved_executable_name
```

Vì vậy analyze, unit/widget và định dạng Dart chưa được xác nhận bằng công cụ.
Giữ Draft để reviewer có thể góp ý/chạy trên đúng head; không đánh dấu test đạt.

Chạy lại tại `nhom10-65ktpm/src` và ghi `git rev-parse HEAD` cùng kết quả:

```powershell
flutter analyze --no-pub lib/features/practice/presentation/pronunciation_screen.dart lib/features/practice/presentation/speech_recognizer.dart test/widget/practice_pronunciation_lifecycle_test.dart test/unit/pronunciation_ledger_test.dart
flutter test --no-pub test/unit/pronunciation_test.dart test/unit/exercises_test.dart test/widget/practice_pronunciation_test.dart test/widget/practice_fill_blank_test.dart test/widget/practice_ordering_quiz_test.dart test/widget/practice_pronunciation_lifecycle_test.dart test/unit/pronunciation_ledger_test.dart --reporter expanded
```

Sau khi tích hợp #16 và phần này, thêm `practice_pronunciation_test.dart` vào
analyze và chạy lại cùng bộ test trên chính cây tích hợp. Kiểm tra format các
file đã sửa bằng SDK của dự án trước khi chuyển Ready.

## Giới hạn còn lại và phối hợp

- Session guard bảo vệ UI/event; cancel là best effort, không hủy được một
  Future native đang chạy và không chứng minh micro vật lý đã tắt. Race khi
  `listen()` native đang khởi động và thiếu callback kết thúc tự nhiên cần
  kiểm chứng/điều tra tiếp; patch này không thay đổi cơ chế native đó.
- Khi ghép #16, lượt Dừng cũ bị vô hiệu theo phiên nhưng waiter có thể còn tới
  timeout 5 giây hoặc lượt mới/dispose. Không mô tả đây là hủy ngay Future stop.
- Player đang chờ seek vẫn cần M1 chốt token/cancel continuation trước khi sửa
  `player_controller.dart`; M3 chịu trách nhiệm ca đổi câu/thoát khi seek chờ.
  Đề xuất và người phối hợp đã nêu trên #4, chưa có thống nhất sửa file chung.
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
