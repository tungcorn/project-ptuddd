# SingLearn — rehearsal Android và checklist bàn giao

Liên quan [#23 – nghiệm thu tích hợp](https://github.com/tungcorn/project-ptuddd/issues/23). Cập nhật 27/11/2026. **Luồng học cốt lõi đã chạy trên điện thoại với `94e1ee3`; bản tích hợp `be084f3` đã qua kiểm tra nhanh riêng. Chưa nộp bài.**

## Luồng học cốt lõi trên `94e1ee3`

- Nguồn: `94e1ee37ffc9541d0839b832779218f08ebdc8f7` trên nhánh nhóm, tree `1904817e58706b903bd22edec9a58e17fe38428d` (đã có #27, #28, #29; chưa có #30).
- Android 16 / API 36, điện thoại thật, USB. APK **debug/local**, không truyền Firebase defines; SHA-256 `E028AC8F4D3554B32633A7236981E06C2A13B718DA4626C8163F557A693715B8`, đối chiếu với APK đã cài trên máy.
- Chạy trực tiếp trên giao diện của app bằng ADB, dùng phiên **Khách** cục bộ sẵn có, không xóa dữ liệu. Trước ca: 0 XP, không có thẻ cần ôn, điểm bài tập Silent Night 0%; không giả định đây là một cài đặt mới hoàn toàn. Không dùng phiên Google, không gửi email, không dùng micro.

| Bước | Quan sát trên điện thoại |
| --- | --- |
| Chọn bài → player | Mở **Silent Night** từ gợi ý A1. Media session của app báo `PLAYING`, sau tạm dừng ở khoảng 6,7 giây. Giao diện có lời Anh–Việt và tô câu hiện hành. Không dùng ảnh/media session để khẳng định chất lượng âm thanh qua loa. |
| Tra → lưu | Chạm `calm` trong “All is calm,”, thấy IPA, nghĩa và ví dụ; chọn **Lưu vào flashcard**. Tab Từ vựng hiện 1 từ, 1 cần ôn, kèm ngữ cảnh câu hát. |
| Ôn | **Ôn 1 từ → Xem nghĩa → Nhớ**. App báo nhớ 1/1, +5 XP; số thẻ đến hạn 1 → 0, lịch ôn chuyển sang 26/11. |
| Bài tập | **Luyện tập → Điền từ khi nghe → Dễ → Chọn từ**. Quan sát nhạc dừng ở câu hỏi. Một lượt hoàn chỉnh đạt 3/3, 100%, +20 XP; màn luyện tập hiện điểm tốt nhất 100%. Đề có thể đổi ở lượt khác. |
| Tiến độ và mở lại app | Tổng XP 0 → 35 (+10 lưu từ, +5 ôn đúng, +20 bài tập), streak 0 → 1. Sau force-stop rồi mở lại riêng SingLearn, vẫn là Khách, còn 35 XP/streak 1, thẻ `calm` với lịch 26/11 và điểm tốt nhất 100%. |

Ảnh chỉ chứa phần ứng dụng, lưu ngoài Git: `demo-94e1ee3-local-player.png`, `demo-94e1ee3-local-cloze.png`. Ca trên là rehearsal giao diện thủ công. Đã rà `src/integration_test/app_e2e_test.dart`: ca vào ôn chờ `start-review.hitTestable()`, kiểm tra hoàn thành và đọc lại thẻ từ store đang mở; không đo khôi phục phiên. **Chưa chạy lại runner trên AVD kiểm thử ở SHA này**, không dùng runner thay APK trên điện thoại cá nhân và không nhận kết quả thủ công là PASS của runner.

## Kiểm tra tích hợp và cloud — bằng chứng riêng

- **Unit/widget:** [bản ghép cùng tree của #27/#28/#29](https://github.com/tungcorn/project-ptuddd/issues/23#issuecomment-7161238548) đã được reviewer chạy độc lập 29/29 test hồi quy. Nhóm báo analyze sạch và 223/223 unit/widget trên cùng tree. Đây là kết quả đã ghi nhận trước rehearsal, không phải một lượt chạy mới và không phải test plugin Android.
- **Firebase Android, cùng nguồn `94e1ee3`, APK khác:** [lượt thử đã ghi trên #23](https://github.com/tungcorn/project-ptuddd/issues/23#issuecomment-7162001411), SHA-256 `FB465390AF97C925D1320A92603947A38D3EDC0863D4C71496C30F04503CD3B2`. Đăng ký tài khoản thử, đối chiếu hồ sơ từ server. Lưu `calm`, đồng bộ thủ công 4 → 0 thao tác chờ, server có `syncedAt`. Mở lại còn phiên, từ và 10 XP; đăng xuất về màn đăng nhập. Không chứng minh hai thiết bị, gửi offline muộn hay đổi tài khoản.
- **Google, APK thử từ `681478c`:** [đã xác nhận đến màn xếp trình độ](https://github.com/tungcorn/project-ptuddd/issues/23#issuecomment-7162603086); thao tác đăng xuất/đăng nhập lại do nhóm trưởng báo. [PR #30](https://github.com/tungcorn/project-ptuddd/pull/30) đã merge tại `be084f3`; mã app và cấu hình mẫu Firebase sau merge khớp nội dung đã kiểm tra từ PR. Đây không phải ca OAuth trên APK local `be084f3` hoặc trên bản ký release, và không thay kiểm thử email/mật khẩu.

## Kiểm tra nhanh trên `be084f3`

| Ca | Bản cài và môi trường | Kết quả và giới hạn |
| --- | --- | --- |
| Mở app → Khách → phát/tạm dừng Silent Night | Điện thoại Android 16 / API 36, Wi-Fi ADB. Build `flutter build apk --debug --no-pub`, không Firebase defines. SHA-256 APK đã đối chiếu: `4C5056B212661EF3CB4AC7E10B934145BE824057CAE1F8D5BE2233AF1808C6E8`. | Mở app sau khi cài, vào Trang chủ với lời chào Khách. Media session của bài chuyển `PLAYING` → `PAUSED` ở 3867 ms; lời và điều khiển hiển thị. Không chạy lại ôn thẻ, điền từ, runner E2E hay Firebase/Google trong lượt này. |
| Home khi đang nhận dạng | Giả lập Android 17 / API 37, APK local riêng cùng commit. SHA-256 theo [báo cáo của Đình trên #22](https://github.com/tungcorn/project-ptuddd/issues/22#issuecomment-7195030116): `B914CB8CAB5AF3ABAA8C07B2C74A8A5F878D64EFCD34BB62B5BC00CFDFEA5ED8`. | Đạt ca Home trên giả lập: log `onPause` → `onStop` → `onResume`, ở nền khoảng 12,5 giây. Lượt cũ không tự chấm hoặc báo không nhận được tiếng, điểm cao nhất không đổi; lượt mới hoạt động. Không xác nhận mic phần cứng đã tắt và không thay ca bấm Dừng. |

## Còn mở theo issue

| Issue | Đã có | Cần bổ sung trước khi đóng |
| --- | --- | --- |
| #3 / #20 — Ninh | SM-2 và khôi phục local trong rehearsal; gửi Firestore một máy trên APK `94e1ee3`; [chạy lại trên nguồn `be084f3`](M2.md#chạy-lại-hồi-quy-20-trên-bản-tích-hợp-27112026): 56/56 Flutter unit/widget và 3/3 Firestore Emulator (JS SDK). | Chưa chạy ca Firebase trên hai Android: máy A học offline rồi gửi muộn, máy B pull nhận đủ và không nhân đôi XP. Đổi tài khoản/queue mới kiểm tra ở tầng Flutter test, chưa xác nhận với Firebase Auth trên Android. |
| #4 / #22 — Đình | Test lifecycle đã merge #29; [một lượt thiết bị thật trên nguồn cũ](M3.md) quan sát quyền mic/thử lại/chấm điểm; ca Home đạt trên giả lập `be084f3` | Chưa có kết quả ca bấm Dừng khi đang nghe trên cùng APK. Phân biệt bằng chứng giả lập với micro trên điện thoại thật. |
| #5 / #21 — Bách | Một app/container chạy A → B → A → khách trong widget test #27; một phiên Firebase đã khôi phục và logout trên Android thật | Kiểm tra tiến độ **theo bài hát** khi đổi tài khoản trên Android; tách yêu cầu reset được server chấp nhận khỏi email thực sự đến, chỉ dùng hộp thư được phép. |
| #23 — Tùng | Luồng học local và lượt Firebase riêng trên `94e1ee3`; kiểm tra nhanh bản tích hợp `be084f3` trên điện thoại; câu hỏi luyện vấn đáp bên dưới | Ghi các ca chưa kiểm chứng nếu chưa có kết quả, chốt báo cáo và hồ sơ nộp theo yêu cầu học phần. Issue giữ In progress. |

#2/#8 không mở lại. Không đưa nhắc học/thông báo lên lịch, tải mô hình dịch ML Kit hoặc chọn file quản trị vào kịch bản chính khi chưa kiểm chứng trên bản demo. Không gộp nhắc học với notification điều khiển nhạc. Phát nền/media key có [smoke cũ](M1.md), không phải nghiệm thu dài hạn hay chạm nút trực tiếp khi khóa trên bản này. Storage, FCM, Functions và ký release không cần cho kịch bản học cốt lõi.

## Chuẩn bị vấn đáp và việc bàn giao

Buổi đánh giá là **vấn đáp**, không phải thuyết trình lần lượt. Mỗi người nắm luồng chung, trả lời được phần mình thực sự làm, chỉ được mã nguồn/test và mở app minh họa nếu được hỏi. Câu dưới đây dùng để hỏi thử lẫn nhau, không phải câu hỏi chính thức của giảng viên.

| Người | Câu hỏi luyện vấn đáp | Minh họa nếu được hỏi |
| --- | --- | --- |
| **Tùng — M1 và tích hợp** | App chọn câu LRC theo vị trí phát thế nào? Khi tua nhanh, làm sao tránh phản hồi cũ ghi đè vị trí mới? Bản tích hợp đã kiểm chứng đến đâu? | Mở Silent Night, chỉ lời song ngữ và câu hiện hành. Chỉ ra test tua và bằng chứng local/Firebase theo SHA. |
| **Ninh — M2** | Tại sao lưu cùng một từ không tạo hai thẻ? Lịch SM-2 đổi ra sao khi chọn Nhớ? Dữ liệu học lúc offline được gửi lại theo tài khoản thế nào? | Lưu `calm`, ôn rồi xem lịch mới. Khi nói về sync, phân biệt bằng chứng server một máy với ca hai máy còn thiếu. |
| **Đình — M3** | Bài điền từ chấm thế nào? Điểm phát âm đo điều gì? App xử lý ra sao khi bấm Home lúc đang nhận dạng? | Chạy một ca điền từ trên cùng bài. Nếu hỏi phát âm, giải thích điểm xấp xỉ dựa trên văn bản nhận dạng và nêu rõ ca native còn thiếu. |
| **Bách — M4** | Vì sao đóng/mở app vẫn còn XP và hồ sơ? Đổi tài khoản thì tiến độ theo tài khoản được tách thế nào? XP được chống cộng trùng ra sao? | Chỉ XP/streak sau bài và sau khi mở lại app. Phân biệt bằng chứng widget với kết quả đổi tài khoản Android. |

Nếu cần minh họa +10 XP và tạo thẻ mới, chuẩn bị phiên thử chưa lưu từ đã chọn; không xóa dữ liệu cá nhân để làm lại ca. Ghi nhãn rõ nếu chuyển giữa APK local và Firebase.

- [ ] **Báo cáo cuối kỳ (PDF/DOCX, trong `docs/`):** mục tiêu, luồng học và sơ đồ dữ liệu; bốn phần do từng người viết; bảng kiểm thử ghi thiết bị/SHA/giới hạn; nguồn bài hát và giấy phép; đối chiếu thông tin và đóng góp thực với `danhsachnhom.md`. Không lấy số commit làm tỷ lệ đóng góp.
- [ ] **Slide/video:** đối chiếu yêu cầu bàn giao riêng của giảng viên. Không làm slide thuyết trình chỉ để phục vụ vấn đáp. Nếu cần nộp video, quay app thật, ghi rõ build và che dữ liệu riêng; không dùng video đề cương TH4 thay video kết quả.
- [ ] **Nộp bài:** chốt nguồn sau review, kiểm tra diff chỉ trong thư mục nhóm và đối chiếu [README học phần](../../../README.md). Không đưa APK/AAB, cấu hình Firebase hay khóa ký vào Git. Chưa tạo báo cáo cuối kỳ hoặc PR nộp bài trong lượt này.
