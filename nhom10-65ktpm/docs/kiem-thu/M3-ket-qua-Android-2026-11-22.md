# M3 — kết quả Android do người dùng báo ngày 22/11/2026

Người thao tác và báo kết quả: Đào Ngọc Đình (`DaoNgocDinh`).
Ngày tiếp nhận: 22/11/2026, giờ Việt Nam; chưa có giờ thực hiện từng lượt.
Liên quan [#22](https://github.com/tungcorn/project-ptuddd/issues/22),
[#4](https://github.com/tungcorn/project-ptuddd/issues/4) và
[PR #26](https://github.com/tungcorn/project-ptuddd/pull/26).
Đây là báo cáo tiếp nhận quan sát của người dùng; agent không thao tác micro,
không trực tiếp quan sát lượt chạy và chưa nhận log/ảnh/video của ba ca này.

## Kết luận hiện tại

A và B đáp ứng các hành vi UI mà người dùng đã mô tả: Dừng có kết quả,
không treo; khi không có lời nói thì có thông báo và lượt sau hoạt động.
Chưa đủ bằng chứng để xác nhận toàn bộ tiêu chí M3 trên bản tích hợp mới.

C đã ghi nhận app không treo sau Home 10–15 giây, nhưng việc vẫn có chấm điểm
không chứng minh phiên cũ đã bị hủy khi `paused`. Cần xác định bản APK,
lifecycle và kết quả đó thuộc phiên trước Home hay lượt mới sau khi quay lại.
Không đánh dấu C đạt và chưa quy kết là lỗi của bản đã merge.

## Môi trường và nguồn APK

| Mục | Thông tin đã có / còn thiếu |
| --- | --- |
| Loại thiết bị của ba ca đã báo | **Giả lập Android — Đình xác nhận ngày 22/11/2026.** Không ghi là thử trên điện thoại thật. |
| Model, Android/API, recognizer, mạng | Chưa cung cấp cho lượt này; không lấy thông số từ lượt thử của Tùng làm thông số của Đình. |
| APK / SHA nguồn thực sự đã build và cài | Chưa xác nhận. SHA checkout không tự chứng minh nguồn APK đang chạy. |
| Checkout Android Studio trước đó mở | `D:\Mobile\project-ptuddd\nhom10-65ktpm\src`; HEAD đọc từ Git ref là `d39bc2262ed41cb0a4b721c105de1a7d8f07e66b`. |
| Kiểm tra file checkout nói trên | File phát âm hiện tại tại đường dẫn đó không có `didChangeAppLifecycleState`. Native Git bị từ chối truy cập nên chưa xác nhận được cây sạch hoặc toàn bộ thay đổi chưa commit. |
| Nền nhóm mới nhất khi chuẩn bị lượt thử lại C | `174921dfb5a86414da374d9e84d6d497700593a8`, đã có #16/#17/#18/#19 và #12; M3 giữ các thay đổi của PR #26. |
| Nhánh đang sửa báo cáo/fixture | `feature/nhom10-65ktpm/kiem-chung-huy-phat-mau`, PR #26; head trước lượt sửa ngày 22/11 là `1ff9038fa85440b13a56340a1de6190970bcb984`. |

Nếu APK vừa thử được build từ checkout cũ nói trên, hành vi tiếp tục chấm
sau Home chưa kiểm chứng phần lifecycle #17. Cần chạy bản có #17 trước khi
kết luận phải sửa production. Không thay đổi/reset checkout cũ để lập báo cáo.

## Kết quả từng ca

| Ca | Thao tác người dùng báo | Quan sát thực tế được báo | Đánh giá trong phạm vi quan sát |
| --- | --- | --- | --- |
| A — Dừng khi đang nói | Đang nghe → đọc câu → bấm Dừng | “App có nhận và chấm điểm thành công không treo” | Đạt quan sát Dừng → có điểm, không treo. Chưa có thời gian chờ, câu/transcript/điểm cụ thể, xác nhận thử lại sau A hoặc bằng chứng không phát event/XP trùng. |
| B — Dừng khi không nói | Đang nghe → giữ yên lặng → Dừng | “Sau 1 lúc thông báo không nhận được âm thanh, không treo, lượt tiếp theo hoạt động bình thường” | Đạt quan sát có thông báo và thử lại được. Chưa đo thời gian chờ, mức tiếng nền hoặc xác nhận native không thu thêm; không tự gán thời gian 5 giây. |
| C — Home rồi quay lại | Đang nghe → Home 10–15 giây → quay lại | “Nhấn home app vẫn chạy dưới nền, hoạt động bình thường, có chấm thành công không treo” | Đạt quan sát không treo; chưa đạt nghiệm thu hủy phiên khi paused. Chưa có log lifecycle, thời điểm chấm và phân biệt phiên cũ/lượt mới. |

Không suy ra điểm cao/độ chính xác nhận dạng, thưởng một lần, cloud đã đồng bộ
hoặc micro vật lý đã tắt từ các mô tả trên. Điểm phát âm vẫn là xấp xỉ dựa
trên văn bản nhận dạng, không phải đo âm vị hay cao độ.

## Phần cần bổ sung, tách theo người xử lý

### Đình xác nhận / thao tác trên Android

1. Đã xác nhận ba ca trước chạy trên giả lập Android. Còn model/API,
   dịch vụ nhận dạng và có/không có mạng nếu biết. Xác nhận nguồn bản APK
   từ thư mục đã dùng để build; không điền SHA PR #26 thay APK chưa chạy.
2. Chạy lại C trên bản có #17: dùng app toàn màn hình, xác nhận đang nghe
   trước Home; Home 10–15 giây; xác nhận `paused` bằng log lifecycle hoặc
   Activity đã dừng, có thể phối hợp Tùng. Sau quay lại không nói/bấm micro
   ngay: quan sát phiên cũ không tự phát kết quả; sau đó chủ động mở lượt mới
   và xác nhận lượt mới hoạt động.
3. Nếu vẫn chấm từ phiên cũ sau `paused` trên đúng APK mới, ghi thời điểm,
   trạng thái trước/sau và phối hợp debug. Chưa cần thử lại toàn bộ A/B
   chỉ để thêm số ca; chỉ chạy lại khi nguồn build khác, có sửa liên quan,
   hoặc cần bổ sung thời gian chờ/luồng thử lại để chốt nghiệm thu.
4. Ba ca này được ghi là kiểm thử giả lập; bằng chứng điện thoại thật chưa
   được thay thế bởi kết quả đó. Không cần đổi kết quả giả lập thành PASS
   phần cứng khi chưa có lượt điện thoại riêng.

Mẫu bổ sung ngắn:

```text
Thiết bị: giả lập / điện thoại thật; model; Android/API:
Recognizer / mạng:
Thư mục build / SHA nguồn APK đã xác nhận / thay đổi local:
C trên bản có #17: bằng chứng paused:
Có điểm từ phiên cũ trước khi bấm micro lại không:
Chủ động bắt đầu lượt mới sau quay lại có hoạt động không:
```

### Agent / reviewer

- Sửa hai blocker test của PR #26 theo review: giữ listener Auth sống và
  chờ dữ liệu hữu hạn; chờ animation/route Back hoàn tất trước khi trả ack cũ.
  Giữ nguyên assertion pending seek, không play sau dispose, positive control,
  event/ledger; không sửa production, player, Android hoặc XP policy.
- Format SDK, analyze và chạy riêng file mới rồi bộ liên quan trên đúng head.
  Không chuyển kết quả probe hoặc kết quả cũ thành PASS cho bản sửa mới.
- Rà soát kết quả C với nguồn APK/lifecycle trước khi sửa production.
- Giữ #22/#4 In progress và PR Draft tới khi phần sửa được kiểm tra/review
  phù hợp; chỉ đóng issue khi đủ toàn bộ bằng chứng và tích hợp.

## Bằng chứng tự động đã có và giới hạn bản sửa

Review Tùng trên head nguyên bản `1ff9038...`:
[review yêu cầu sửa](https://github.com/tungcorn/project-ptuddd/pull/26#pullrequestreview-6006945453)
và [tổng hợp trên #22](https://github.com/tungcorn/project-ptuddd/issues/22#issuecomment-7066453960).

- Analyzer file mới sạch; formatter báo file cần format.
- File mới kẹt chờ Auth trước UI. Probe giữ Auth có listener và chờ Back
  bằng pumpAndSettle đạt 4/4, sau đó đã hoàn nguyên. **4/4 không phải PASS
  của head nguyên bản hay bản sửa ngày 22/11.**
- Chín file liên quan hiện có đạt 85/85 trên head nguyên bản, không gồm
  file mới bị kẹt; không phải full suite hoặc kiểm thử Android.

Lượt sửa ngày 22/11 đã thay hai điểm fixture theo review. SDK của agent
hiện đọc được phiên bản Dart 3.13.7, nhưng formatter dừng trước khi format
vì `type 'Null' is not a subtype of type 'String'` tại
`_Platform.resolvedExecutable`. Hai lệnh analyze/test bản sửa được khởi động qua flutter_tools.snapshot,
nhưng phiên truy cập máy bị ngắt trước khi nhận kết quả kết thúc. Chưa có
PASS của lượt này; không nhận các số cũ là kết quả bản sửa. Báo cáo và patch
được lưu qua GitHub. Sau khi máy kết nối lại, đã sao lưu file/index/refs và
đồng bộ local đúng 0f54111, rồi đưa nền nhóm 174921d vào cùng nhánh M3 để
chuẩn bị lượt Home tiếp theo. Vẫn cần SDK checks trước khi chốt; không
nhận bản đã chuẩn bị để chạy là APK đã được thử C.

## Bản local chuẩn bị cho lần thử Home tiếp theo

Đã tiếp nhận xác nhận **giả lập Android**; đây là cập nhật môi trường của
ba quan sát cũ, không làm thay đổi trạng thái C chưa đủ bằng chứng.

Mở đúng project trong Android Studio:

```text
D:\Mobile\Daily_You\build\singlearn-m3-issue22\nhom10-65ktpm\src
```

Nhánh `feature/nhom10-65ktpm/kiem-chung-huy-phat-mau` giữ patch M3 và cập nhật
nền nhóm tới `174921dfb5a86414da374d9e84d6d497700593a8`; đã có lifecycle #17.
Checkout cũ tại D:\Mobile\project-ptuddd được giữ nguyên. Ghi lại
`git rev-parse HEAD` trong project này lúc build; chọn emulator rồi chạy
main.dart để cài bản mới. Chỉ ghi kết quả C sau khi người dùng thực hiện.

## Nơi lưu và nhánh đưa kết quả lên

Lưu báo cáo cùng tài liệu M3 trong PR #26 trên nhánh
`feature/nhom10-65ktpm/kiem-chung-huy-phat-mau`; PR đích
`nhom10-65ktpm`. Bổ sung bằng chứng vào cùng PR, không mở nhánh/PR
trùng việc và không đẩy trực tiếp lên nhánh nhóm hoặc nhánh #16 cũ.

Liên kết: [M3 tổng hợp](M3.md) · [kịch bản A/B/C](M3-thu-cong-Android.md).
