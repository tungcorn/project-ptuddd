# Ba đoạn học bổ sung — 18/11/2026

Liên quan [issue #8](https://github.com/tungcorn/project-ptuddd/issues/8). Owner tích hợp: Tùng / M1. Không thay đổi player, Auth/Firebase, SM-2 hoặc XP; không ghi nhận thành viên khác đã review khi chưa có review thực tế.

## Nội dung

Giữ nguyên tám bài cũ. Ba mục mới đều là **đoạn trích**, không phải bản đầy đủ, do **Josh Woodward** sáng tác và trình bày:

| Mục trong app | Mức gợi ý | Mục tiêu học | Khoảng trong bản gốc | Độ dài / số câu |
| --- | --- | --- | --- | --- |
| Coffee (đoạn học) | A2 | Sinh hoạt, công việc; check my email, routine, spill | 00:12–01:29 | 77 giây / 14 câu |
| Learn To Fly (đoạn học) | B1 | Kiên trì thử lại; try again, see it through, wings | 00:11–01:12 | 61 giây / 16 câu |
| Little Tomcat (đoạn học) | B1 | Tình bạn, chăm sóc thú cưng; stay close, get by, share | 00:14–01:01 | 47 giây / 10 câu |

CEFR là ước lượng biên tập, không phải chứng nhận; một số từ như *thermal*, *calloused* khó hơn mức chung. Các dạng nói *gonna*, *cuz*, *'bout* có giải thích trong từ điển, không khuyến khích dùng trong văn viết trang trọng. Từ vựng bổ sung có nghĩa Việt, IPA và ví dụ tự soạn; không sao chép một bộ từ điển bên ngoài.

## Nguồn và quyền sử dụng

- [Coffee — trang chính thức](https://www.joshwoodward.com/song/Coffee).
- [Learn To Fly — trang chính thức](https://www.joshwoodward.com/song/LearnToFly).
- [Little Tomcat — trang chính thức](https://www.joshwoodward.com/song/LittleTomcat).
- [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Trang từng bài công bố **CC BY 4.0**; metadata JSON-LD của bản thu liên kết tác giả, tác phẩm nhạc và lời. Đây là tác phẩm có bản quyền được cấp phép mở, **không phải public domain**. Ghi công Josh Woodward và liên kết nguồn/giấy phép được lưu trong `catalog.json`, hiển thị ở phần thông tin giấy phép của player và nhúng trong metadata MP3.

Nhóm 10 đã chọn đoạn, cắt phần mở đầu/kết thúc, chuyển mã mono MP3 96 kbps / 44,1 kHz, thêm fade, chuẩn hóa cách viết/dấu câu, dịch tiếng Việt và căn lời. Learn To Fly dùng biến thể lời của bản thu **Here Today Remixed** (ví dụ *gonna*, *see it through*), không ép dùng mọi từ trên trang lời. Những thay đổi này được ghi trong thông tin giấy phép. Bản dịch/phần biên tập mới của ba đoạn được Nhóm 10 cung cấp theo CC BY 4.0. Ảnh bìa được sinh bằng công cụ của dự án, không lấy bìa album của tác giả.

## Dữ liệu và tái tạo

- Nội dung gốc biên tập: `src/assets/content/songs/*-learning-clip.json`.
- Nguồn tải, SHA-256 bản gốc, khoảng cắt và mốc lời: `tools/learning_clips.json`.
- Mốc `lineStartsSec`/`lineEndSec` là giây trong **bản gốc**; LRC trừ `startSec`. Mốc cuối kết thúc câu cuối trước phần nhạc fade.
- Mốc được suy ra từ word timestamps của **faster-whisper small**, CPU int8, ngôn ngữ English, `condition_on_previous_text=False`; với từ đầu bị kéo dài hơn 0,7 giây, dùng `word.end - 0.5` như công cụ căn lời sẵn có. Không coi kết quả tự động là kiểm chứng nghe thủ công.
- Công cụ tái tạo dùng các mốc đã lưu, không cần tải/chạy lại Whisper, không cần TTS và không đụng tám bài cũ.

Từ thư mục `nhom10-65ktpm/`, tải đúng ba bản gốc vào thư mục bị Git bỏ qua (PowerShell; `curl.exe`, không phải alias `curl`):

```powershell
New-Item -ItemType Directory -Force tools/recordings_src
curl.exe -fL -A "Mozilla/5.0" "https://www.joshwoodward.com/mp3/sunny/JoshWoodward-SunnySideOfTheStreet-09-Coffee.mp3" -o tools/recordings_src/josh-woodward-coffee.mp3
curl.exe -fL -A "Mozilla/5.0" "https://www.joshwoodward.com/mp3/HereToday/JoshWoodward-HereTodayRemixed-06-LearnToFly.mp3" -o tools/recordings_src/josh-woodward-learn-to-fly.mp3
curl.exe -fL -A "Mozilla/5.0" "https://www.joshwoodward.com/mp3/TheWake/JoshWoodward-TheWake-09-LittleTomcat.mp3" -o tools/recordings_src/josh-woodward-little-tomcat.mp3
py -3.13 tools/build_learning_clips.py
```

Cần `ffmpeg`/`ffprobe` trên PATH, Python có `numpy` và `Pillow`. Không cài đè vào môi trường Python dùng chung chỉ để chạy công cụ. Script kiểm SHA-256 và biên thời gian trước khi ghi asset; nếu nguồn thay đổi, cần rà soát lại thay vì tự đổi hash cho qua. Không đưa bản gốc đầy đủ, HTML tải về, model hoặc cache lên Git. Không chạy `generate_media.py` để thay giọng hát thật bằng TTS.

## Kiểm tra đã thực hiện và giới hạn

- Tạo thành công ba MP3, LRC và ảnh bìa; MP3 giải mã toàn bộ bằng ffmpeg không báo lỗi, ffprobe xác nhận mono 44,1 kHz và thời lượng 77/61/47 giây.
- Đối chiếu dữ liệu với Git HEAD: tám mục catalog cũ không đổi. Không sửa audio/LRC/ảnh bìa cũ.
- `flutter test --no-pub test/unit/content_test.dart`: **16/16 đạt**, kiểm tra giữ bài cũ, nguồn/ghi công, mốc đoạn, LRC/bản dịch và nghĩa/IPA từ vựng. Lần chạy đầu phát hiện thiếu hai từ gốc *about*, *because*; đã bổ sung rồi chạy lại đạt.
- Sau khi hoàn thiện mốc: `flutter test --no-pub test/unit/content_test.dart test/widget/admin_songs_test.dart`: **18/18 đạt**, gồm 16 kiểm thử nội dung và 2 kiểm thử quản trị bài hát.
- `flutter analyze --no-pub`: **No issues found**.
- Kiểm tra bảo toàn: tám mục catalog, tám audio, tám LRC (đối chiếu có xét LF/CRLF của Windows), tám ảnh bìa và toàn bộ mục/forms từ điển cũ không đổi. `git diff --check` đạt.
- Đã xem ba ảnh bìa sinh ra. Sau đó đã `flutter run --debug --no-pub --no-resident -d <thiết bị Wi-Fi>`: build/cài/mở thành công trên điện thoại Android 25069PTEBG. Mở Coffee từ trang chủ; ảnh màn hình thực tế cho thấy player ở 0:22/1:17, nút tạm dừng, câu hiện tại được tô sáng và bản dịch song ngữ hiển thị. Không coi quan sát này là đã nghe rà từng câu; Learn To Fly/Little Tomcat chưa được mở kiểm tra trên máy. Chưa chứng nhận độ chính xác phát âm/CEFR.

Review nội dung ngắn: mở lần lượt ba mục mới, nghe đầu/cuối mỗi đoạn và chỗ chuyển câu; xem bản dịch, chạm thử từ mới, kiểm tra điền từ/nghe lại câu. Chú ý các dạng nói và bản thu remix của Learn To Fly. Nếu mốc lệch, sửa manifest rồi tái tạo; không sửa thuật toán player để bù lỗi dữ liệu. Đây là kiểm tra cần làm, chưa phải bằng chứng đã thực hiện.
