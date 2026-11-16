# ĐỀ CƯƠNG PROJECT CUỐI KỲ – Phát Triển Ứng Dụng Cho Thiết Bị Di Động

**Đề tài:** SingLearn – Ứng dụng học tiếng Anh qua bài hát

**Giảng viên hướng dẫn: ThS. Đỗ Oanh Cường**

**Nhóm sinh viên thực hiện: Nhóm 10 – Lớp 65KTPM**

| STT | Họ và tên | MSSV | Vai trò | GitHub |
| :-: | --- | :-: | --- | --- |
| 1 | Ngô Quang Tùng | 2351170631 | Trưởng nhóm | [tungcorn](https://github.com/tungcorn) |
| 2 | Nguyễn Hải Ninh | 2351170609 | Thành viên | Chưa cung cấp |
| 3 | Đào Ngọc Đình | 2351170582 | Thành viên | [DaoNgocDinh](https://github.com/DaoNgocDinh) |
| 4 | Phạm Ngọc Bách | 2351170576 | Thành viên | Chưa cung cấp |

Hà Nội, ngày 14 tháng 11 năm 2026


## 1. GIỚI THIỆU ĐỀ TÀI

Tiếng Anh là môn học bắt buộc và là điều kiện chuẩn đầu ra của hầu hết sinh viên hiện nay. Tuy nhiên, nhiều bạn học từ vựng và ngữ pháp theo kiểu học thuộc lòng, nhanh chán và nhanh quên. Trong khi đó, nghe nhạc tiếng Anh lại là thói quen hằng ngày của rất nhiều người trẻ: nghe khi đi xe buýt, khi làm bài, khi tập thể dục.

Học qua bài hát có nhiều ưu điểm: giai điệu giúp ghi nhớ câu và từ lâu hơn, người học được nghe phát âm, nối âm, ngữ điệu của người bản xứ, và nội dung bài hát gắn với cảm xúc nên tạo hứng thú tự nhiên. Tuy vậy, nếu chỉ nghe nhạc thông thường thì người học thường chỉ “nghe cho vui”, không biết mình đã học được từ nào, không được kiểm tra và không có kế hoạch ôn lại.

Từ lý do đó, nhóm em chọn đề tài **SingLearn – Ứng dụng học tiếng Anh qua bài hát**. Đây là ứng dụng di động viết bằng Flutter, chạy trên Android, có giao diện tiếng Việt, biến mỗi bài hát thành một bài học: nghe nhạc kèm lời chạy đồng bộ, chạm vào từ để tra nghĩa, làm bài tập điền từ khi nghe, luyện hát/đọc theo và được chấm phát âm, lưu từ mới thành flashcard để ôn tập theo thuật toán lặp lại ngắt quãng.

Ứng dụng có hệ thống điểm kinh nghiệm (XP), cấp độ, chuỗi ngày học (streak), huy hiệu và thử thách “Đoán tên bài hát” với bạn bè để duy trì động lực. Dữ liệu được lưu cục bộ trước (offline-first) và đồng bộ lên Firebase khi có mạng.

Đề tài phù hợp với môn Phát triển ứng dụng cho thiết bị di động vì nhóm vận dụng được nhiều kiến thức của môn: xây dựng giao diện Flutter, quản lý trạng thái, điều hướng nhiều màn hình, phát âm thanh, thu âm và nhận dạng giọng nói, thông báo cục bộ, lưu trữ cục bộ, đồng bộ đám mây và xử lý quyền truy cập thiết bị.


## 2. LÝ DO CHỌN ĐỀ TÀI


### 2.1. Tổng hợp các ứng dụng đã phân tích, thiết kế trong học kỳ

Trong học kỳ, nhóm đã lần lượt phân tích, thiết kế và xây dựng các ứng dụng sau:

| Ứng dụng | Lĩnh vực | Chức năng nổi bật | Bài học rút ra |
|---|---|---|---|
| Cashew | Quản lý chi tiêu cá nhân (mã nguồn mở, Flutter) | Ghi thu chi theo danh mục, ngân sách, giao dịch định kỳ, biểu đồ thống kê, lưu cục bộ và sao lưu đám mây. | Offline-first; nhập liệu nhanh, ít thao tác; thống kê trực quan tạo động lực. |
| Daily You (DailyU) | Nhật ký cá nhân (mã nguồn mở, Flutter) | Mỗi ngày một mục nhật ký kèm ảnh và tâm trạng, xem lại theo lịch, chuỗi ngày ghi, nhắc nhở hằng ngày. | Thói quen hằng ngày; chuỗi ngày (streak) và nhắc nhở giữ chân người dùng. |
| SnapLearn | Học từ vựng tiếng Anh bằng camera (nhóm tự xây dựng) | Chụp đồ vật → AI nhận diện → từ, phiên âm, nghĩa; flashcard SM-2; chấm phát âm; trò chơi săn đồ vật; XP, streak, huy hiệu. | Kiến trúc feature-first, Riverpod, Firebase; mô-đun flashcard, chấm phát âm, tiến độ đã chạy ổn định. |

Điểm chung của ba ứng dụng là dùng hằng ngày, dữ liệu cá nhân, ưu tiên hoạt động offline và dùng thống kê, chuỗi ngày để tạo động lực. Khoảng trống còn lại: SnapLearn chỉ dạy **từ đơn lẻ** gắn với đồ vật, chưa luyện **nghe hiểu câu, ngữ điệu và nối âm** – là phần người học tiếng Anh yếu nhất.


### 2.2. Lựa chọn ứng dụng làm Project cuối kỳ

Nhóm cân nhắc ba phương án và chấm điểm theo thang 1–5 có trọng số:

| Tiêu chí | Trọng số | A. Mở rộng Cashew | B. Hoàn thiện SnapLearn | C. SingLearn (học qua bài hát) |
|---|---|---|---|---|
| Tính mới, hấp dẫn người học | 25% | 2 | 3 | 5 |
| Khai thác tính năng thiết bị di động (âm thanh, micro, thông báo) | 20% | 2 | 4 | 5 |
| Khả thi trong thời gian môn học | 20% | 5 | 5 | 4 |
| Đủ khối lượng chia đều cho 4 thành viên | 20% | 3 | 3 | 5 |
| Tái sử dụng kết quả đã làm trong học kỳ | 15% | 2 | 5 | 4 |
| **Tổng điểm** | 100% | **2,80** | **3,90** | **4,65** |

Phương án C – **SingLearn** đạt điểm cao nhất nên được chọn làm Project cuối kỳ.


### 2.3. Lý do chọn đề tài

Thứ nhất, học tiếng Anh qua bài hát là bài toán thực tế, gần gũi với sinh viên và dễ demo: chỉ cần mở một bài hát là thấy ngay toàn bộ luồng học.

Thứ hai, đề tài khai thác tốt phần cứng điện thoại: loa/tai nghe để phát nhạc, micro để luyện hát và chấm phát âm, thông báo để nhắc học, bộ nhớ máy để tải bài hát nghe offline.

Thứ ba, đề tài kế thừa trực tiếp kết quả cả học kỳ: kiến trúc và các mô-đun đăng nhập, flashcard SM-2, chấm phát âm, XP – streak – huy hiệu của SnapLearn; mô hình offline-first và thống kê của Cashew; thói quen hằng ngày và nhắc nhở của DailyU. Nhờ vậy nhóm tập trung thời gian vào phần mới là trình phát nhạc, lời đồng bộ và bài tập nghe.

Thứ tư, khối lượng công việc tách được thành bốn mô-đun độc lập, mỗi thành viên phụ trách một mô-đun trọn vẹn từ giao diện đến dữ liệu.


## 3. MỤC TIÊU ĐỀ TÀI


### 3.1. Mục tiêu tổng quát

Xây dựng ứng dụng di động SingLearn giúp người học Việt Nam học từ vựng, luyện nghe và luyện phát âm tiếng Anh thông qua các bài hát được phân theo trình độ; ứng dụng hoạt động được khi không có mạng, đồng bộ dữ liệu lên Firebase và có cơ chế trò chơi hóa để duy trì thói quen học mỗi ngày.


### 3.2. Mục tiêu cụ thể

- Xây dựng ứng dụng Flutter chạy trên Android (minSdk 24), giao diện tiếng Việt, dễ sử dụng.
- Xây dựng thư viện tối thiểu 30 bài hát, phân theo trình độ A1–B2, chủ đề và thể loại.
- Phát nhạc kèm lời bài hát chạy đồng bộ theo từng câu (định dạng LRC), có bản dịch tiếng Việt.
- Hỗ trợ phát chậm 0,75x, lặp lại một câu, lặp đoạn A–B và tải bài hát để nghe offline.
- Cho phép chạm vào từ trong lời để xem phiên âm IPA, nghĩa, ví dụ, nghe phát âm và lưu từ.
- Tạo bài tập điền từ khi nghe với 3 mức độ khó, bài sắp xếp câu và trắc nghiệm nghĩa.
- Luyện hát/đọc theo từng câu, nhận dạng giọng nói và chấm điểm phát âm thang 0–100.
- Lưu từ mới thành flashcard và ôn tập theo thuật toán lặp lại ngắt quãng SM-2.
- Tính XP, cấp độ, chuỗi ngày học, huy hiệu; có thống kê theo tuần và nhắc học hằng ngày.
- Có thử thách “Đoán tên bài hát” với bạn bè và bảng xếp hạng tuần.
- Lưu dữ liệu cục bộ bằng Hive CE, đồng bộ Cloud Firestore khi có mạng; ảnh bìa, file nhạc và file lời lưu trên Firebase Storage.
- Có chức năng quản trị nội dung bài hát dành cho tài khoản quản trị viên.


### 3.3. Phạm vi đề tài

**Trong phạm vi:**

- Nền tảng: ứng dụng Android (Flutter); chưa làm iOS và Web.
- Nội dung: bài hát thuộc phạm vi công cộng (public domain) hoặc giấy phép Creative Commons, bài hát thiếu nhi, dân ca tiếng Anh; lời và mốc thời gian do nhóm tự soạn.
- Người dùng: người học tiếng Anh trình độ A1–B2, giao diện tiếng Việt.
- Chấm phát âm dựa trên nhận dạng giọng nói (Speech-to-Text) khi người học đọc/hát lại một câu lúc nhạc tạm dừng.
- Chế độ demo: khi chưa cấu hình Firebase, ứng dụng vẫn chạy với dữ liệu mẫu cục bộ.

**Ngoài phạm vi:**

- Phát nhạc thương mại có bản quyền, kết nối Spotify/Apple Music.
- Chấm cao độ, nhịp (pitch/rhythm) như ứng dụng karaoke chuyên nghiệp.
- Thanh toán, gói trả phí, quảng cáo.
- Tự động tách lời từ file nhạc bằng AI (lời được soạn và căn thời gian thủ công).


### 3.4. Đối tượng sử dụng

- Sinh viên cần đạt chuẩn đầu ra tiếng Anh (B1) và muốn ôn luyện nhẹ nhàng mỗi ngày.
- Học sinh, người đi làm thích nghe nhạc và muốn cải thiện nghe – phát âm.
- Quản trị viên nội dung (thành viên nhóm) nhập bài hát, lời và bài tập.


## 4. KIẾN TRÚC TỔNG THỂ HỆ THỐNG

Hệ thống SingLearn được thiết kế theo mô hình gồm bốn phần chính:

- Ứng dụng di động Flutter.
- Firebase (backend đám mây).
- Dịch vụ âm thanh và giọng nói trên thiết bị.
- Kho nội dung bài hát.


### 4.1. Ứng dụng di động Flutter

Ứng dụng tổ chức mã nguồn theo kiến trúc feature-first kết hợp clean architecture rút gọn (presentation → domain ← data), giống SnapLearn. Ứng dụng đảm nhiệm các chức năng:

- Hiển thị giao diện, điều hướng 5 tab bằng go_router.
- Quản lý trạng thái bằng Riverpod 3.
- Phát nhạc, hiển thị lời đồng bộ, xử lý bài tập.
- Lưu dữ liệu cục bộ bằng Hive CE, xếp hàng các thay đổi chờ đồng bộ.
- Gửi sự kiện học tập (học từ, hoàn thành bài, chấm phát âm) qua AppEventBus để mô-đun Tiến độ cộng XP.


### 4.2. Firebase

Firebase được dùng làm backend, không cần tự dựng máy chủ:

- Firebase Authentication: đăng nhập email/mật khẩu và Google.
- Cloud Firestore: dữ liệu bài hát, từ vựng, tiến độ, bạn bè, thử thách, bảng xếp hạng.
- Firebase Storage: file nhạc, file lời LRC, ảnh bìa.
- Firebase Cloud Messaging: thông báo khi có lời mời thử thách.
- Security Rules: mỗi người chỉ đọc/ghi dữ liệu của mình; chỉ quản trị viên được sửa bài hát.


### 4.3. Dịch vụ âm thanh và giọng nói trên thiết bị

- just_audio + audio_service: phát nhạc, tua, đổi tốc độ, chạy nền, điều khiển trên màn hình khóa.
- speech_to_text: nhận dạng câu người học đọc/hát lại để chấm điểm.
- flutter_tts: đọc mẫu từ và câu.
- Google ML Kit Translation: dịch nhanh câu ngoài bản dịch có sẵn, chạy offline.
- flutter_local_notifications: nhắc học hằng ngày.


### 4.4. Kho nội dung bài hát

Mỗi bài hát gồm file nhạc, file lời LRC (mỗi dòng có mốc thời gian), bản dịch, danh sách từ khóa và bài tập. Dữ liệu chính:

| Collection / Box | Nội dung |
|---|---|
| songs/{songId} | Tên bài, ca sĩ, trình độ, chủ đề, thời lượng, link nhạc, link lời, giấy phép, danh sách từ khóa. |
| users/{uid}/words/{wordId} | Từ đã lưu, câu trong bài hát chứa từ, thông số SM-2 (EF, interval, dueAt), updatedAt, isDeleted. |
| users/{uid}/songProgress/{songId} | Số lần nghe, điểm bài tập cao nhất, điểm phát âm, lần học gần nhất. |
| users/{uid}/stats, publicProfiles/{uid} | XP, cấp độ, streak, huy hiệu; hồ sơ công khai cho bảng xếp hạng. |
| challenges/{id} | Thử thách “Đoán tên bài hát”: người mời, người nhận, danh sách câu hỏi, điểm. |
| Hive: songs_cache, words_{uid}, pending_ops | Bản sao cục bộ để dùng offline và hàng đợi thay đổi chờ đồng bộ. |


## 5. LUỒNG HOẠT ĐỘNG CHÍNH

Luồng học một bài hát của người học như sau:

- Người học mở ứng dụng, đăng nhập (hoặc dùng chế độ demo).
- Trang chủ gợi ý bài hát theo trình độ và hiển thị XP, streak, số từ cần ôn hôm nay.
- Người học chọn bài hát trong thư viện (lọc theo trình độ, chủ đề).
- Ứng dụng phát nhạc, lời chạy đồng bộ và tô sáng câu đang hát, có bản dịch tiếng Việt.
- Người học chạm vào từ mới để xem phiên âm, nghĩa, nghe phát âm và lưu thành flashcard.
- Người học làm bài điền từ khi nghe: nhạc dừng sau mỗi câu có chỗ trống để điền.
- Người học luyện hát/đọc theo từng câu, ứng dụng chấm điểm phát âm và chỉ ra từ sai.
- Kết thúc bài, ứng dụng hiển thị kết quả, cộng XP, cập nhật streak và huy hiệu.
- Từ đã lưu xuất hiện trong lịch ôn tập SM-2; ứng dụng gửi thông báo nhắc ôn hằng ngày.
- Dữ liệu được lưu cục bộ ngay, tự đồng bộ lên Firestore khi có mạng.
- Người học có thể thách đấu bạn bè “Đoán tên bài hát” và xem bảng xếp hạng tuần.


## 6. CÔNG NGHỆ SỬ DỤNG


### 6.1. Flutter và Dart

Lý do chọn Flutter:

- Một mã nguồn, giao diện đẹp, hiệu năng tốt trên Android.
- Nhóm đã quen qua các bài thực hành và dự án SnapLearn.
- Hệ sinh thái thư viện âm thanh, giọng nói, Firebase đầy đủ.
- Hot reload giúp làm giao diện nhanh.

Thư viện chính: flutter_riverpod 3 (trạng thái), go_router (điều hướng), just_audio và audio_service (phát nhạc), speech_to_text, flutter_tts, google_mlkit_translation, hive_ce (lưu cục bộ), fl_chart (biểu đồ), flutter_local_notifications, permission_handler, connectivity_plus.


### 6.2. Firebase

- Firebase Authentication để quản lý tài khoản.
- Cloud Firestore để lưu và đồng bộ dữ liệu.
- Firebase Storage để lưu file nhạc, lời, ảnh bìa.
- Firebase Cloud Messaging để gửi thông báo thử thách.


### 6.3. Xử lý âm thanh và giọng nói

- Định dạng lời LRC: mỗi dòng “[mm:ss.xx] câu hát”, ứng dụng so vị trí phát hiện tại để tô sáng câu.
- Chấm phát âm: so khớp kết quả nhận dạng với câu gốc bằng khoảng cách Levenshtein chuẩn hóa, lấy kết quả tốt nhất trong các phương án nhận dạng, nhân 100.
- Thang đánh giá: ≥ 90 Xuất sắc, 70–89 Khá tốt, 50–69 Gần đúng, < 50 Chưa đúng.


### 6.4. Lưu trữ cục bộ và đồng bộ

- Ghi Hive trước, đánh dấu “chờ đồng bộ”, SyncService đẩy lên Firestore khi có mạng.
- Kéo về các bản ghi có updatedAt mới hơn lần đồng bộ trước.
- Xung đột giải quyết theo bản ghi mới nhất (last-write-wins); xóa bằng cờ isDeleted.
- File nhạc tải về được lưu trong bộ nhớ ứng dụng để nghe offline.


### 6.5. Trello và GitHub

Trello được dùng để phân công công việc, theo dõi tiến độ theo tuần và quản lý nhiệm vụ nhóm.

GitHub được dùng để lưu mã nguồn và tài liệu, review code qua Pull Request (nhánh feature → develop → main), chạy flutter analyze và flutter test trước khi gộp.


## 7. CÁC CHỨC NĂNG CHÍNH


### 7.1. Giao diện và điều hướng

Ứng dụng có thanh điều hướng dưới gồm 5 tab:

- Trang chủ.
- Bài hát.
- Luyện tập.
- Từ vựng.
- Hồ sơ.


### 7.2. Đăng ký và đăng nhập

- Đăng ký, đăng nhập bằng email/mật khẩu hoặc tài khoản Google.
- Quên mật khẩu qua email.
- Chọn trình độ ban đầu (A1–B2) bằng bài kiểm tra nhanh 5 câu.
- Chế độ demo khi chưa cấu hình Firebase.


### 7.3. Thư viện bài hát

- Danh sách bài hát có ảnh bìa, tên bài, ca sĩ, trình độ, thời lượng.
- Lọc theo trình độ, chủ đề (gia đình, tình bạn, thiên nhiên, lễ hội…) và thể loại.
- Tìm kiếm theo tên bài hoặc ca sĩ.
- Đánh dấu yêu thích, tải về để nghe offline.
- Hiển thị tiến độ của từng bài (đã nghe, đã làm bài tập, điểm cao nhất).


### 7.4. Trình phát nhạc và lời đồng bộ

- Phát, tạm dừng, tua, chạy nền và điều khiển trên màn hình khóa.
- Lời bài hát chạy đồng bộ, tô sáng câu đang hát, chạm vào câu để nhảy tới.
- Ba chế độ lời: tiếng Anh, song ngữ, ẩn lời (luyện nghe).
- Tốc độ phát 0,75x / 1x, lặp lại một câu, lặp đoạn A–B.


### 7.5. Tra từ và lưu từ vựng

- Chạm vào một từ trong lời để xem từ gốc, phiên âm IPA, nghĩa tiếng Việt, ví dụ.
- Nghe phát âm mẫu bằng TTS.
- Lưu từ thành flashcard kèm câu hát chứa từ đó làm ngữ cảnh.
- Danh sách từ khóa của bài được gợi ý sẵn theo trình độ.


### 7.6. Bài tập điền từ khi nghe

- Ẩn một số từ trong lời theo 3 mức: Dễ (10%), Vừa (25%), Khó (50%).
- Nhạc tự dừng sau mỗi câu có chỗ trống, người học gõ hoặc chọn từ.
- Chấm đúng/sai ngay, cho nghe lại câu, hiển thị đáp án.
- Tổng kết điểm, danh sách từ sai được gợi ý lưu vào flashcard.


### 7.7. Sắp xếp lời và trắc nghiệm

- Sắp xếp các câu hát theo đúng thứ tự sau khi nghe.
- Sắp xếp từ thành câu hoàn chỉnh.
- Trắc nghiệm nghĩa của từ/câu trong bài hát.


### 7.8. Luyện hát và chấm phát âm

- Nghe một câu mẫu, nhạc tạm dừng, người học bấm micro đọc/hát lại.
- Ứng dụng nhận dạng giọng nói, chấm điểm 0–100 và tô màu từ đúng/sai.
- Lưu điểm cao nhất của từng câu, từng bài.
- Xin quyền micro ngay trước khi dùng, có màn hình hướng dẫn khi bị từ chối.


### 7.9. Flashcard và ôn tập SM-2

- Danh sách từ đã lưu, tìm kiếm, xóa, lọc theo bài hát.
- Thẻ lật 2 mặt: mặt trước là từ và câu hát, mặt sau là nghĩa, phiên âm.
- Bốn nút Quên/Khó/Nhớ/Dễ tương ứng chất lượng 1/3/4/5, tính lịch ôn bằng SM-2.
- Phát lại đúng đoạn nhạc chứa từ để nhớ theo giai điệu.


### 7.10. Thử thách “Đoán tên bài hát” và bảng xếp hạng

- Tìm và kết bạn theo email hoặc mã người dùng.
- Nghe một đoạn nhạc 10 giây hoặc một câu lời bị ẩn từ, chọn đúng tên bài/từ còn thiếu.
- Gửi thử thách cho bạn, so sánh điểm, nhận thông báo kết quả.
- Bảng xếp hạng XP theo tuần giữa bạn bè.


### 7.11. Tiến độ học tập

- XP: lưu từ +10, hoàn thành bài điền từ +20, phát âm ≥ 70 điểm +5 mỗi câu, ôn đúng flashcard +5.
- Cấp độ: lên cấp n+1 cần 100·n XP.
- Streak: mỗi ngày có ít nhất một hoạt động học được tính một ngày.
- Huy hiệu: “Bài hát đầu tiên”, “100 từ”, “Chuỗi 7 ngày”, “Giọng ca vàng”…
- Biểu đồ số từ đã học, số phút nghe, điểm phát âm theo tuần.
- Nhắc học hằng ngày vào giờ người học chọn.


### 7.12. Quản trị nội dung bài hát

- Thêm, sửa, ẩn bài hát; tải lên file nhạc, ảnh bìa, file lời LRC.
- Nhập bản dịch, gán trình độ, chủ đề, từ khóa.
- Kiểm tra lời đồng bộ trực tiếp trên máy trước khi xuất bản.


## 8. PHÂN QUYỀN NGƯỜI DÙNG

Hệ thống có ba nhóm người dùng.


### 8.1. Khách (chế độ demo)

- Nghe thử bài hát mẫu, xem lời và bản dịch.
- Dữ liệu chỉ lưu trên máy, không có bạn bè, thử thách, bảng xếp hạng.


### 8.2. Người học

- Dùng toàn bộ chức năng học: nghe, tra từ, bài tập, luyện hát, flashcard.
- Xem tiến độ, XP, huy hiệu, nhận nhắc học.
- Kết bạn, thách đấu, xem bảng xếp hạng.
- Chỉnh sửa hồ sơ, cài đặt giao diện sáng/tối, giờ nhắc học.


### 8.3. Quản trị viên nội dung

- Có toàn bộ quyền của người học.
- Quản lý bài hát, lời, bản dịch, bài tập.
- Quyền được xác định bằng custom claim “admin” và kiểm tra trong Firestore/Storage Rules.


## 9. PHÂN CÔNG CÔNG VIỆC

Phân công được nhóm trưởng chốt ngày 16/11/2026 theo hướng sở hữu nghiệp vụ, triển khai từng luồng nhỏ có nghiệm thu và tích hợp sớm, áp dụng chọn lọc AI Team Playbook. Mỗi người phụ trách giao diện, logic, dữ liệu và kiểm thử của phần mình; giao tiếp qua contract dùng chung. Đây là kế hoạch triển khai, không xác nhận chức năng đã hoàn thành.

| Thành viên | Mô-đun phụ trách | Công nghệ chính (dự kiến) | Nhiệm vụ chính |
|---|---|---|---|
| Ngô Quang Tùng (Trưởng nhóm) | Thư viện & Trình phát; khung tích hợp (M1) | go_router, Riverpod, just_audio, audio_service, Firebase Storage | Khung app/theme/điều hướng tối thiểu; thư viện bài hát, trạng thái phát/tua, parser và đồng bộ lời LRC, nghe lại một câu. Sau luồng cốt lõi: phát nền, điều khiển màn hình khóa, tải offline, lặp A–B. Điều phối tích hợp và đóng gói kiểm tra; không mặc định sửa lỗi nội bộ các mô-đun khác. |
| Nguyễn Hải Ninh | Từ vựng, Flashcard & Quản trị nội dung (M2) | Hive CE, Cloud Firestore, flutter_tts, ML Kit Translation | Tra/lưu từ kèm ngữ cảnh và nguồn bài, định danh và xử lý trùng, flashcard SM-2, lưu offline và đồng bộ dữ liệu từ vựng. Sau luồng cốt lõi: nhập/sửa nội dung bài hát và kiểm tra quyền quản trị; phối hợp schema bài hát với M1, danh tính/quyền với M4. |
| Đào Ngọc Đình | Luyện tập, Phát âm & Thử thách (M3) | speech_to_text, permission_handler, Cloud Firestore, FCM | Ưu tiên điền từ và chấm/tổng kết phiên; tiếp theo sắp xếp lời, trắc nghiệm, nhận dạng giọng nói và điểm phát âm gần đúng. Sau luồng cốt lõi: thử thách “Đoán tên bài hát”. Dùng contract player của M1, gửi kết quả cho M4; không tự ghi XP hoặc làm bạn bè/bảng xếp hạng. |
| Phạm Ngọc Bách | Tài khoản, Tiến độ & Kết nối (M4) | Firebase Auth, Cloud Firestore, fl_chart, flutter_local_notifications | Xác thực/hồ sơ và dữ liệu theo người dùng; trang chủ, quy tắc XP/cấp độ/streak/huy hiệu, thống kê và nhắc học. Ưu tiên xác thực tối thiểu và XP/streak; sau luồng cốt lõi: bạn bè và bảng xếp hạng, nhận kết quả thử thách từ M3. |

Công việc chung: chuẩn bị tối thiểu 30 bài hát, lời LRC, bản dịch và bài tập có giấy phép phù hợp cho cả bản ghi và lời. Phân bổ ban đầu Tùng/Ninh/Đình/Bách: 8/8/7/7 bài; cân lại theo độ khó thực tế. Mỗi thành viên tự viết phần báo cáo/slide, kiểm thử và demo của mình; người tổng hợp chỉ ghép và chuẩn hóa, không viết thay cả nhóm.

Phối hợp: Tùng ↔ Đình, Ninh ↔ Bách review/dự phòng; thay đổi ranh giới phải có người dùng contract cùng rà soát. Owner sửa lỗi phần mình; nhóm trưởng điều phối, không nhận mặc định mọi lỗi sau tích hợp. Phối hợp trước khi sửa router, bootstrap, pubspec/lock, schema và contract. Mỗi đầu việc nhỏ phải ghi phạm vi, kết quả quan sát được, ca lỗi và lệnh/kết quả kiểm tra thật; dùng AI không thay thế việc hiểu và giải thích mã nguồn.

Nghiệm thu và bảo vệ: M1 demo phát/tua/lời đúng thời điểm; M2 demo lưu từ → ôn → lịch SM-2 đổi và mở lại còn dữ liệu; M3 demo bài tập/phát âm, giải thích giới hạn chấm gần đúng; M4 demo đăng nhập → kết quả học → XP/streak/thống kê. Mỗi người giải thích ít nhất một quyết định kỹ thuật và một ca lỗi/biên đã kiểm thử, không đánh giá đóng góp theo số dòng, commit hay prompt.

Contract tối thiểu cần thống nhất trước triển khai: ID bài/câu lời và đơn vị thời gian; đầu vào/kết quả tra/lưu từ; kết quả phiên học và định danh xử lý gửi lại; dữ liệu tiến độ chỉ đọc. Các chính sách từ trùng, XP khi làm lại, chống thưởng trùng khi retry/sync, múi giờ streak và lỗi lưu chưa được chốt trong bước phân công này. Fake hỗ trợ phát triển song song nhưng không thay kiểm thử tích hợp thật; event bus trong bộ nhớ không tự bảo đảm thưởng đúng một lần.


## 10. KẾ HOẠCH THỰC HIỆN


### 10.1. Tiến độ theo tuần

Khung kế hoạch dự kiến là 10 tuần, mỗi 2 tuần có một mốc kiểm tra và demo nội bộ; chưa phải lịch ngày đã chốt hoặc báo cáo tiến độ thực tế. Ưu tiên nền Android chạy được và luồng một bài hát → lưu từ → ôn → tiến độ trước khi mở rộng; cân tải sau từng mốc, không tự cắt yêu cầu đề cương.

| Tuần | Giai đoạn | Công việc chính | Kết quả / Mốc |
|---|---|---|---|
| 1 | Khởi động, phân tích | Chốt yêu cầu, vẽ use case, wireframe các màn hình, chọn 30 bài hát và kiểm tra giấy phép, lập bảng Trello. | Tài liệu yêu cầu, wireframe |
| 2 | Thiết kế | Cả nhóm chốt model/contract và quy tắc nghiệp vụ. M1 điều phối khung app, xử lý nền Android; M4 chuẩn bị xác thực tối thiểu. Build/chạy Android; CI nếu có đặt ở kho phát triển nội bộ, không thêm workflow ở gốc kho học phần. | Mốc 1: khung app chạy được |
| 3–4 | Phát triển vòng 1 | M1: thư viện/player/LRC/nghe lại câu. M2: tra/lưu từ và ôn SM-2 tối thiểu. M3: điền từ, chấm/tổng kết phiên. M4: xác thực/hồ sơ tối thiểu, XP/streak. Tích hợp thật luồng một bài → lưu → ôn → tiến độ, rồi bài tập; chuẩn bị 15 bài đầu. | Mốc 2: luồng học cốt lõi liên thông |
| 5–6 | Phát triển vòng 2 | M1: phát nền/màn hình khóa, tải offline, A–B. M2: hoàn thiện SM-2/lưu offline/đồng bộ từ vựng. M3: sắp xếp lời/trắc nghiệm/phát âm gần đúng. M4: dữ liệu theo người dùng, huy hiệu/thống kê/nhắc học. Kiểm thử lại luồng thật, retry và lỗi lưu. | Mốc 3: đủ chức năng học |
| 7–8 | Phát triển vòng 3 | M2: quản trị nhập/sửa bài hát, phối hợp schema M1 và quyền M4. M3: thử thách đoán bài. M4: bạn bè/bảng xếp hạng. M1 ổn định phát nhạc, hỗ trợ tích hợp player. Cả nhóm hoàn thiện 30 bài và trạng thái sáng/tối/lỗi/rỗng/offline; cân tải theo kết quả mốc trước. | Mốc 4: bản beta đầy đủ |
| 9 | Kiểm thử | Unit test (SM-2, chấm điểm, XP, parser LRC), widget test, thử trên 3 máy thật, sửa lỗi, tối ưu hiệu năng. | Báo cáo kiểm thử |
| 10 | Hoàn thiện, bàn giao | Đóng gói APK, viết báo cáo, slide, quay video demo, thuyết trình. | Mốc 5: nộp sản phẩm |


### 10.2. Rủi ro và phương án xử lý

| Rủi ro | Ảnh hưởng | Phương án xử lý |
|---|---|---|
| Bản quyền bài hát | Không được phát nhạc thương mại trong ứng dụng. | Chỉ dùng bài public domain / Creative Commons, ghi nguồn; nhạc thương mại để ở hướng phát triển. |
| Nhận dạng giọng nói kém khi có nhạc nền | Điểm phát âm thiếu chính xác. | Tạm dừng nhạc khi thu âm, dùng nhiều phương án nhận dạng, khuyến nghị đeo tai nghe. |
| Soạn lời LRC mất nhiều thời gian | Chậm tiến độ nội dung. | Phân bổ ban đầu Tùng/Ninh/Đình/Bách: 8/8/7/7 bài, cân lại theo độ khó; dùng công cụ căn thời gian sẵn có, không phụ thuộc việc xây thêm công cụ trong app quản trị. |
| Xung đột mã nguồn giữa các mô-đun | Lỗi tích hợp. | Kiến trúc feature-first, contract dùng chung, PR có review, flutter analyze + test bắt buộc. |
| Thành viên chậm tiến độ | Trễ mốc kiểm tra. | Họp ngắn 2 lần/tuần, theo dõi Trello, hỗ trợ chéo; ưu tiên chức năng cốt lõi trước. |


## 11. KẾT QUẢ MONG ĐỢI

Sau khi hoàn thành, nhóm mong muốn đạt được các kết quả sau:

- Ứng dụng SingLearn chạy ổn định trên Android, giao diện tiếng Việt, hỗ trợ sáng/tối.
- Thư viện 30 bài hát có lời đồng bộ, bản dịch và bài tập, phân theo trình độ.
- Người học nghe nhạc kèm lời, tra từ, lưu từ chỉ với một chạm.
- Có bài điền từ khi nghe, sắp xếp lời, trắc nghiệm và luyện hát có chấm điểm.
- Flashcard ôn tập theo SM-2, nhắc học hằng ngày.
- Có XP, cấp độ, streak, huy hiệu, thống kê, thử thách bạn bè và bảng xếp hạng.
- Hoạt động được khi không có mạng và tự đồng bộ khi có mạng.
- Mã nguồn trên GitHub, flutter analyze sạch, có unit test cho các phần logic chính.
- Bàn giao: file APK, mã nguồn, báo cáo, slide và video demo.


## 12. KẾT LUẬN

Đề tài SingLearn giúp nhóm áp dụng kiến thức của môn Phát triển ứng dụng cho thiết bị di động vào một bài toán thực tế, gần gũi với chính sinh viên. Đề tài được chọn sau khi tổng hợp các ứng dụng đã phân tích, thiết kế trong học kỳ (Cashew, DailyU, SnapLearn) và so sánh có tiêu chí giữa các phương án.

Flutter được dùng để xây dựng ứng dụng Android; just_audio và speech_to_text xử lý phần nghe nhạc và luyện phát âm; Hive CE và Firebase đảm bảo ứng dụng hoạt động offline và đồng bộ dữ liệu. Kiến trúc mô-đun cho phép bốn thành viên làm việc song song với khối lượng cân bằng.

Với mục tiêu rõ ràng, phạm vi phù hợp, chức năng được mô tả chi tiết và kế hoạch 10 tuần có mốc kiểm tra cụ thể, nhóm tin rằng đề tài khả thi, có thể demo trực quan và tiếp tục mở rộng trong tương lai, ví dụ thêm iOS, chấm cao độ khi hát hoặc liên kết các nền tảng nghe nhạc.
