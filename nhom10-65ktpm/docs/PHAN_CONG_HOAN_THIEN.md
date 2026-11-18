# Phân công hoàn thiện SingLearn – Nhóm 10 · 65KTPM

Cập nhật: 18/11/2026. Đây là kế hoạch cho đợt ổn định hiện tại, không xác nhận các hạng mục đã hoàn thành và không thay đổi tác giả của phần code đã có.

## 1. Mục tiêu và nguyên tắc

- Giữ phạm vi sản phẩm hiện tại; ưu tiên độ ổn định, dữ liệu theo tài khoản, kiểm thử và bằng chứng phối hợp GitHub.
- Mỗi người sở hữu cả code, test, tài liệu kiểm chứng và demo của nhiệm vụ được giao. Không đánh giá đóng góp theo số dòng hoặc số commit.
- Mọi nhiệm vụ phát triển, kể cả của nhóm trưởng, đi qua nhánh tính năng và PR vào `nhom10-65ktpm`; có người khác review thực chất trước merge.
- Một nhánh cho một đầu việc, không tạo nhánh mới cho mỗi commit. Không tạo lại PR hoặc commit giả cho công việc đã hoàn thành.
- Chưa triển khai thêm giáo viên liên hệ, Google sign-in, Storage, Functions, FCM, chấm âm vị chuyên sâu hoặc mở rộng số bài chỉ để tăng khối lượng. Việc bổ sung nội dung cần được nhóm chốt riêng; đợt này tập trung bộ demo 8 bài hiện có.
- Không thể bảo đảm hoàn toàn không có xung đột. Ranh giới file giảm sửa chồng; giao tiếp mô-đun và kiểm thử tích hợp ngăn xung đột logic dù Git merge sạch.

## 2. Bốn nhiệm vụ chính

Các đường dẫn code/test trong tài liệu tính từ `nhom10-65ktpm/src/`, trừ khi ghi rõ.

| Mã | Người phụ trách chính | Nhiệm vụ | Reviewer dự kiến | Nhánh gợi ý |
| --- | --- | --- | --- | --- |
| M1 | Ngô Quang Tùng (`tungcorn`) | Player, phát nền, màn hình khóa | Đào Ngọc Đình (`DaoNgocDinh`) | `feature/nhom10-65ktpm/on-dinh-player` |
| M2 | Nguyễn Hải Ninh (`HaiNinh1`) | Từ vựng, SM-2, offline và hàng đợi đồng bộ | Phạm Ngọc Bách (`phamngocbach05-debug`) | `feature/nhom10-65ktpm/dong-bo-tu-vung` |
| M3 | Đào Ngọc Đình (`DaoNgocDinh`) | Phát âm, nhận dạng và lỗi/quyền micro | Ngô Quang Tùng (`tungcorn`) | `feature/nhom10-65ktpm/on-dinh-phat-am` |
| M4 | Phạm Ngọc Bách (`phamngocbach05-debug`) | Phiên Firebase và tiến độ theo tài khoản | Nguyễn Hải Ninh (`HaiNinh1`) | `feature/nhom10-65ktpm/phien-cloud-tien-do` |

Reviewer là người kiểm tra, không mặc định là người sửa thay. Thành viên xác nhận nhận việc và cập nhật tiến độ bằng tài khoản của mình. Liên kết issue được ghi ở mục 8 khi đã tạo.

### M1 – Player và hành vi Android

**Được chủ động sửa:**

- `lib/features/player/`, `lib/features/songs/`.
- `lib/core/services/audio_engine.dart`.
- `android/` nếu liên quan player/quyền/service; mọi yêu cầu Android của người khác phải được phối hợp trước.
- Test riêng của player/LRC/nội dung, ví dụ `test/unit/lrc_parser_test.dart`, `test/unit/content_test.dart`; không sửa phần từ vựng trong test kết hợp nếu chưa phối hợp M2.

**Tiêu chí nghiệm thu:**

- [ ] Phát/tạm dừng/chuyển bài/tua không phát chồng hoặc lệch trạng thái; lời đồng bộ theo vị trí mới.
- [ ] Lặp câu/A–B hoạt động theo điều khiển đã hiển thị.
- [ ] Chạy nền và điều khiển màn hình khóa được kiểm tra trên Android, ghi rõ thiết bị/phiên bản và giới hạn quan sát được; không cam kết app sống sau force-stop.
- [ ] Lỗi sửa được có test hồi quy khi khả thi; thiếu khả năng kiểm thử thiết bị phải ghi rõ, không đánh dấu đã đạt.

**Ngoài phạm vi:** Auth, thuật toán sync, SM-2, scoring phát âm. Không nhận mặc định lỗi nội bộ của ba mô-đun khác.

### M2 – Từ vựng và offline/sync

**Được chủ động sửa:**

- `lib/features/vocabulary/`.
- `lib/core/sync/sync_service.dart`.
- `test/unit/sm2_test.dart`, `test/unit/sync_service_test.dart`, `test/unit/vocabulary_provider_test.dart` và test mới riêng của từ vựng/sync.
- `test/unit/vocabulary_progress_test.dart`: M2 điều phối sửa file; thay đổi kỳ vọng XP phải thống nhất M4.

**Tiêu chí nghiệm thu:**

- [ ] Lưu trùng chỉ bổ sung ngữ cảnh theo nghiệp vụ hiện có; không tạo thẻ hoặc thưởng trùng.
- [ ] Lịch SM-2 và từ đã lưu được giữ sau khi đóng/mở ứng dụng.
- [ ] Offline → retry/kết nối lại không mất thao tác, không nhân đôi dữ liệu hoặc thưởng.
- [ ] A có thao tác đang chờ → đăng xuất → B đăng nhập không làm lộ dữ liệu A và không để thao tác A chặn vô hạn việc gửi của B.
- [ ] A đăng nhập lại có thể tiếp tục xử lý dữ liệu chờ thuộc A theo chính sách thống nhất với M4; không xóa sạch queue/Hive để che lỗi.

**Phụ thuộc:** thống nhất Auth–sync với M4 trước khi đổi API hoặc hành vi hàng đợi. M2 quản lý queue/dữ liệu, không tự sửa vòng đời Auth hoặc `singlearn_app.dart` trong PR song song.

**Ngoài phạm vi:** quản trị nội dung, ML Kit/TTS, thay đổi quyền tài khoản hoặc XP policy, viết lại toàn bộ storage/kiến trúc.

### M3 – Luyện phát âm và tình huống lỗi

**Được chủ động sửa:**

- `lib/features/practice/`.
- `test/unit/pronunciation_test.dart`, `test/unit/exercises_test.dart`.
- `test/widget/practice_*.dart` và test mới riêng của luyện tập/phát âm.

**Tiêu chí nghiệm thu:**

- [ ] Cho phép/từ chối quyền micro đều có trạng thái và cách xử lý phù hợp, không văng app.
- [ ] Không có tiếng nói, nhận dạng thất bại hoặc dịch vụ không khả dụng không gây treo vô hạn; cho phép thử lại khi có thể.
- [ ] Dừng/thoát màn không để phiên nhận dạng hoạt động ngoài dự kiến.
- [ ] Sự kiện kết quả có định danh theo giao tiếp hiện có, không tự cộng XP trực tiếp hoặc thưởng trùng ngoài quy tắc.
- [ ] UI/tài liệu giải thích điểm là xấp xỉ dựa trên văn bản nhận dạng, không đo độ chính xác âm vị/cao độ.
- [ ] Test giả lập bao phủ trạng thái lỗi; kiểm tra micro thật ghi riêng, không dùng test giả để khẳng định phần cứng đạt.

**Ngoài phạm vi:** thử thách xã hội trong đợt này, player engine thứ hai, XP policy, sửa Android/dependency mà chưa thống nhất M1.

### M4 – Phiên Firebase và tiến độ

**Được chủ động sửa:**

- `lib/features/auth/`, `lib/features/progress/`, `lib/features/profile/`.
- `lib/core/cloud/firebase_services.dart`, `lib/singlearn_app.dart`, `lib/core/events/app_event_bus.dart` theo quy tắc file chung bên dưới.
- `test/unit/progress_rules_test.dart`, `test/widget/app_flow_test.dart`, `test/unit/cloud_config_test.dart` và test mới riêng cho auth/progress.

**Tiêu chí nghiệm thu:**

- [ ] Đăng ký/đăng nhập/lỗi xác thực và mất mạng có phản hồi rõ ràng.
- [ ] Đóng/mở app khôi phục đúng phiên; đăng xuất/đổi tài khoản không hiển thị tiến độ hoặc hồ sơ riêng của tài khoản trước.
- [ ] Luồng quên mật khẩu được kiểm chứng đúng mức: request thành công khác với email đã nhận; chỉ dùng địa chỉ/tài khoản thử nghiệm được phép.
- [ ] XP/streak/hồ sơ nhất quán sau đăng nhập lại; kết quả học retry không được thưởng trùng ngoài chính sách đã có.
- [ ] Cùng M2 kiểm chứng ca A còn queue → B đăng nhập → quay lại A; phân biệt lỗi phiên và lỗi queue, không cùng sửa chồng một file.

**Ngoài phạm vi:** toàn bộ bạn bè/bảng xếp hạng/nhắc học, Google OAuth/Storage/FCM, cấp admin đại trà hoặc tự deploy/bật billing.

## 3. File dùng chung và người điều phối

Đây là quy ước phối hợp, không phải quyền bảo mật được GitHub tự động thực thi. Người khác được đề xuất patch/test nhưng phải chốt một người/PR sửa tại một thời điểm.

| File/nhóm file | Người điều phối | Quy tắc |
| --- | --- | --- |
| `lib/core/providers.dart`, `lib/main.dart`, `lib/core/router.dart` | M1 | Thay đổi wiring/provider/API ghi thành yêu cầu cụ thể; tích hợp bằng PR nhỏ trước nếu các nhánh khác phụ thuộc. |
| `lib/singlearn_app.dart` | M4 | M1 đề xuất hook player/lifecycle; M2 đề xuất sync/session. Không có hai PR sửa song song file này nếu chưa chốt thứ tự. |
| `lib/core/cloud/firebase_services.dart` | M4 | File chứa cả Auth và `FirestoreRemoteStore`. M2 đưa yêu cầu transport và test; M4 điều phối một PR sửa. Không tiện tay sửa `CloudMediaUploader`/`CloudMessaging`. |
| `lib/core/events/app_event_bus.dart`, `lib/features/auth/domain/app_user.dart` | M4 | Người dùng giao tiếp review trước khi đổi payload, định danh sự kiện hoặc UID. |
| `lib/core/storage/local_store.dart` | M2 | Không đổi schema/storage/migration toàn app khi chưa phối hợp các mô-đun sử dụng. |
| `lib/core/config/app_config.dart` | M4 | Thay đổi cờ cloud phải phối hợp wiring M1; không tự bật dịch vụ tùy chọn. |
| `lib/core/services/device_services.dart` | Chỉ định theo issue | Chứa TTS/dịch/thông báo/download. M2 đề xuất phần TTS/dịch, M4 thông báo, M1 download; chỉ một người sửa file tại một thời điểm, hiện chưa mở việc riêng. |
| `android/`, `pubspec.yaml`, `pubspec.lock` | M1 | Thành viên gửi nhu cầu quyền/plugin; không nâng cấp hàng loạt hoặc format file không liên quan. |
| `../firebase/firestore.rules`, indexes, test rules, cấu hình Firebase | M4 | Phối hợp M2 khi đổi schema; triển khai cloud vẫn cần cho phép riêng. |
| `test/helpers.dart`, `test/widget/harness.dart`, `test/widget/player_vocab_test.dart`, `integration_test/app_e2e_test.dart` | M1 | Người phụ trách nghiệp vụ chuẩn bị ca test; M1 điều phối chỉnh sửa test/helper liên mô-đun. Không giảm assertion chỉ để test qua. |
| `README.md`, `CLAUDE.md`, tài liệu phân công (tính từ thư mục nhóm) | M1 | Các thành viên ghi kết quả riêng theo issue, sau đó tổng hợp; không cùng sửa cả README. |

## 4. Giao tiếp phải thống nhất trước khi đổi

### Auth–sync: M2 và M4

Trước khi sửa API/hành vi liên mô-đun, ghi trên issue: thời điểm thay UID, cách phân biệt thao tác thuộc từng tài khoản, xử lý request đang chạy khi logout, lịch retry và cách khôi phục queue của A. Chính sách phải giữ dữ liệu, không dùng phiên B để gửi dữ liệu riêng của A. Đây là yêu cầu hành vi, chưa áp đặt một giải pháp triển khai duy nhất.

M4 sở hữu phiên và lifecycle; M2 sở hữu queue và dữ liệu từ vựng. Thay đổi giao tiếp chung đi bằng một PR nhỏ có cả hai người rà soát; nhánh phụ thuộc chỉ tiếp tục sau khi cập nhật thay đổi đó từ nhánh nhóm. Test nội bộ không phụ thuộc thay đổi API có thể làm trước.

### Kết quả học–XP: M1/M2/M3 → M4

Các mô-đun phát sự kiện theo định danh/payload đã thống nhất; `ProgressService` xử lý thưởng, streak và chống trùng. Không thêm một cơ chế cộng XP độc lập ở màn player, từ vựng hoặc phát âm. Khi đổi sự kiện, M4 cập nhật phần dùng chung trước và liệt kê bên cần chuyển đổi; không tự thay chính sách XP chỉ để làm test qua.

### Player–luyện tập: M1 và M3

M3 dùng API player hiện có, không khởi tạo player thứ hai. Nếu thiếu thao tác phát/dừng/nghe lại, ghi yêu cầu cho M1. Đơn vị thời gian, ID bài/câu và hành vi thoát màn phải thống nhất trước khi sửa bên gọi.

## 5. Quy trình tránh sửa chồng

1. Bắt đầu từ nhánh nhóm mới nhất, đọc issue và ranh giới file; xác nhận nhận việc trên issue.
2. Trước khi sửa file dùng chung/ngoài phạm vi: comment đường dẫn, lý do, API/dữ liệu ảnh hưởng và người cần phối hợp.
3. Chốt người sửa, PR thực hiện và thứ tự merge. Nếu cần, tách thay đổi giao tiếp thành PR nhỏ; không để hai người âm thầm sửa hai phiên bản.
4. Không đổi format toàn bộ file/thư mục, sửa dependency hoặc refactor ngoài nhiệm vụ.
5. Mỗi người thêm/sửa test thuộc phần mình; helper/test liên mô-đun theo bảng điều phối. Test tích hợp có một người viết chính và người dùng giao tiếp review.
6. PR ghi issue, phạm vi file thực tế, thay đổi đã phối hợp, test và phần chưa kiểm chứng. Reviewer kiểm tra cả xung đột logic, không chỉ khả năng merge của Git.
7. Sau giải quyết xung đột mã nguồn phải chạy lại kiểm thử ứng dụng. Sau tích hợp chạy kiểm tra toàn bộ phù hợp trước demo.

Ví dụ thay đổi dùng chung cần comment:

```text
File cần sửa:
Lý do / hành vi hiện tại:
API hoặc dữ liệu bị ảnh hưởng:
Người điều phối và bên sử dụng:
Ai sửa / PR nào / thứ tự merge:
Ca kiểm thử để xác nhận tương thích:
```

## 6. Project, review và bằng chứng

### Chia issue thành các PR nhỏ

- Áp dụng cho cả M1–M4: **một issue có thể được giải quyết qua nhiều PR**, không cần chờ hoàn thành toàn bộ issue mới mở PR. Owner ghi phần việc nhỏ dự định làm trên issue trước khi triển khai.
- Mỗi PR tập trung một phần việc có ý nghĩa, có thể review và kiểm thử riêng, ví dụ sửa một tình huống lỗi kèm test hồi quy. Không chia vụn theo số dòng hoặc tạo PR chỉ để đủ số lượng; không tách test cần thiết khỏi bản sửa để merge code chưa được kiểm chứng.
- PR giải quyết một phần ghi `Liên quan #<issue>`, liệt kê tiêu chí/phần việc đã xử lý, kết quả kiểm thử, phần còn lại và PR phụ thuộc nếu có. **Không dùng `Closes`, `Fixes`, `Resolves` cho issue chưa hoàn thành.** Chỉ đóng issue khi toàn bộ tiêu chí có bằng chứng và các PR cần thiết đã merge.
- Nếu muốn nhận góp ý sớm khi phần việc chưa sẵn sàng, mở Draft PR và ghi rõ điều còn thiếu; chỉ chuyển sẵn sàng review khi phạm vi PR đã đủ điều kiện kiểm tra. Có thể còn phần khác của issue chưa làm.
- Mỗi PR nhỏ dùng nhánh tính năng có tên theo phần việc; tiếp tục commit trên cùng nhánh khi sửa theo review. Sau merge, phần việc tiếp theo tạo nhánh từ `nhom10-65ktpm` mới nhất; không mặc định lấy nhánh chưa merge làm base.

### Theo dõi tiến độ và bằng chứng

- Board: **Todo → In progress → In review → Done**. Tạo issue không đồng nghĩa đã bắt đầu hoặc hoàn thành.
- Todo: đã có phạm vi/assignee; In progress: người làm xác nhận bắt đầu; In review: phần việc hiện tại có PR sẵn sàng review, không có nghĩa toàn bộ issue đã xong. PR một phần được merge mà issue còn việc thì giữ/mở lại In progress và ghi tiến độ; Done: toàn bộ tiêu chí nghiệm thu có bằng chứng và các PR cần thiết đã merge. Không đóng issue chỉ vì một PR thành phần đã merge.
- Người bị chặn ghi comment nêu trở ngại và phụ thuộc; không chuyển Done để làm đẹp tiến độ.
- Reviewer dự kiến theo bảng M1–M3, M2–M4. Người tạo PR không tự duyệt; phản hồi phải có kiểm tra thực tế, không tạo bình luận giả.
- Mỗi người tự cập nhật issue/PR và phản hồi review bằng tài khoản của mình; AI hỗ trợ không thay thế hiểu code và trách nhiệm kiểm chứng.
- Khi không có thiết bị, làm unit/widget/backend emulator trước; ghi rõ phần Android còn chờ. Người khác có thể chạy hộ kịch bản nhưng owner vẫn phân tích và sửa lỗi.
- Mỗi người có thể ghi bằng chứng riêng tại `docs/kiem-thu/M1.md`, `M2.md`, `M3.md`, `M4.md` (tính từ thư mục nhóm); chỉ tạo khi có kết quả thật. M1 tổng hợp cuối đợt, không viết thay báo cáo/demo của cả nhóm.
- Không chạy smoke test lên cloud, gửi email thử, commit/push/merge/deploy hoặc thay đổi cấu hình dùng chung ngoài phạm vi được cho phép.

## 7. Thứ tự thực hiện và việc để sau

1. Chuẩn hóa tài liệu, issues và Project; thành viên đọc và xác nhận phạm vi.
2. M2/M4 chốt Auth–sync và PR giao tiếp nếu cần. M1/M3 có thể làm phần riêng không phụ thuộc; không yêu cầu mọi người chờ thiết bị mới viết test.
3. Bốn owner hoàn thiện nhiệm vụ, mở PR và review chéo; nhận lỗi về đúng owner, không chuyển hết về nhóm trưởng.
4. Kiểm tra bản tích hợp trên Android và cập nhật tài liệu bằng kết quả thực tế.
5. Sau đợt chính mới mở issue quản trị/ML Kit/TTS (M2), thử thách (M3), bạn bè/bảng xếp hạng/nhắc học (M4), đóng gói/demo (M1). Chốt lại ranh giới, đặc biệt `features/social/` và `device_services.dart`, trước khi bắt đầu đợt đó.

## 8. Liên kết quản lý

- Repository: https://github.com/tungcorn/project-ptuddd
- Issues: https://github.com/tungcorn/project-ptuddd/issues
- [M1 – Player và hành vi Android (#2)](https://github.com/tungcorn/project-ptuddd/issues/2).
- [M2 – Từ vựng, offline và sync (#3)](https://github.com/tungcorn/project-ptuddd/issues/3).
- [M3 – Phát âm và micro (#4)](https://github.com/tungcorn/project-ptuddd/issues/4).
- [M4 – Phiên Firebase và tiến độ (#5)](https://github.com/tungcorn/project-ptuddd/issues/5).
- [Project SingLearn – Tiến độ nhóm 10](https://github.com/users/tungcorn/projects/2), [board theo trạng thái](https://github.com/users/tungcorn/projects/2/views/2): đã có Todo, In progress, In review, Done và liên kết với repository.
- Project để riêng tư; đã cấp quyền WRITER cho ba thành viên còn lại để tự cập nhật tiến độ, không cấp quyền admin. Project không tên có sẵn trên tài khoản không bị thay đổi.
- Tại thời điểm khởi tạo, bốn issue đã được thêm vào Project, gán đúng owner và đặt Todo; reviewer trong kế hoạch là đề xuất. Tiến độ hiện tại, xác nhận nhận việc và các PR/review liên quan được theo dõi trực tiếp trên issue và Project, không suy ra từ trạng thái khởi tạo này.

Tài liệu này bổ sung phân công nghiệp vụ ở mục 9 của đề cương. Nếu hướng dẫn cũ mâu thuẫn về cách làm của đợt hiện tại, dùng tài liệu này và yêu cầu GitHub mới; các thay đổi ranh giới tiếp theo phải được ghi lại trước khi triển khai.
