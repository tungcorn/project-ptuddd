# M3 — kết quả kiểm thử Android cập nhật 28/11/2026

Owner: DaoNgocDinh. Liên quan #22 / #4; reviewer: tungcorn.

## Bấm Dừng khi đang nghe — xác nhận mới của Đình

Nguồn: Đình báo trực tiếp ngày 28/11/2026 trong phiên làm tài liệu M3:
“bấm dừng khi đang nghe … phân tích phần đã ghi âm được và chấm điểm
thành công, đã thử ở giả lập android”.

| Bước | Quan sát do người kiểm thử báo |
| --- | --- |
| Bắt đầu một lượt nói | App ở trạng thái đang nghe; có nội dung đã nói trước khi bấm Dừng. |
| Bấm Dừng | App vẫn nhận được kết quả cho phần đã nói và chấm điểm thành công. |
| Môi trường | Giả lập Android; không phải điện thoại vật lý. |

Kết luận ở mức quan sát: **đạt ca Dừng có nội dung nói trên giả lập**.
Đây là kết quả do Đình cung cấp, không phải lượt agent tự chạy.
Cụm “phần đã ghi âm” mô tả phần người dùng đã nói; không xác nhận ứng dụng
ghi hoặc lưu một tệp âm thanh. App tính điểm xấp xỉ từ văn bản nhận dạng,
không đo trực tiếp chất lượng phát âm ở mức âm vị.

Chưa được cung cấp riêng cho lượt Dừng này: SHA nguồn/APK, thời điểm cài,
model/API, transcript và điểm cụ thể, log stop/final/done, số event/XP hoặc
kết quả lượt kế tiếp. Không tự gán lượt này cho APK `be084f3` hay dùng
SHA-256/log của ca Home bên dưới để chứng minh nguồn của ca Dừng.
Không suy ra micro phần cứng đã tắt từ việc Dừng/chấm điểm thành công.

Xác nhận mới chỉ bổ sung ca Dừng có nói. Ca yên lặng rồi Dừng và thử lại đã
được Đình báo ở [kết quả 22/11](M3-ket-qua-Android-2026-11-22.md); chưa có
xác nhận mới rằng ca đó chạy trên cùng APK với lượt Dừng vừa báo.

## Home / chuyển nền — bằng chứng đã có ngày 26/11

Nguồn: [Đình báo kết quả trên #22](https://github.com/tungcorn/project-ptuddd/issues/22#issuecomment-7195030116).

- Nguồn ứng dụng: `be084f3a5913e2f7550c4e643d6bf5b64755b174`, đã có #29.
  APK debug/local, cài 26/11/2026 lúc 21:20:10.
- SHA-256 file build khớp APK đã cài:
  `B914CB8CAB5AF3ABAA8C07B2C74A8A5F878D64EFCD34BB62B5BC00CFDFEA5ED8`.
- Giả lập `sdk_gphone16k_x86_64`, Android 17 / API 37.
- Log events ghi `onPause` → `onStop` → `onResume`,
  từ 21:26:36.882 tới 21:26:49.474, ở nền khoảng 12,5 giây.
- Khi quay lại: lượt cũ về trạng thái chờ, không tự hiện điểm/no-speech,
  điểm cao nhất không đổi. Lượt nói mới hoạt động bình thường.

**Đạt ca Home trên giả lập**; không yêu cầu lặp ca này từ việc cập nhật tài liệu.
Không suy rộng thành kết quả điện thoại vật lý, micro OS đã ngắt hoặc cloud.

## Đối chiếu và bàn giao

- #16/#17/#18/#26/#29 đã merge; giữ nguyên bằng chứng unit/widget theo
  từng SHA trong [M3.md](M3.md), không nhận là test vừa chạy ngày 28/11.
- Đã bổ sung quan sát Dừng thành công và ca Home có nguồn/log xác định.
  Còn đối chiếu nguồn APK của lượt Dừng và phạm vi bằng chứng A/B trước khi
  reviewer chốt checklist; không tự kết luận hai lượt dùng cùng bản cài.
- Không sửa production, test, Android/plugin, chính sách XP hoặc schema.
  Không kiểm thử Firebase/cloud, không thu/lưu/công khai âm thanh.
- #22/#4 giữ In progress chờ review và đối chiếu toàn bộ tiêu chí;
  tài liệu này không tự đóng issue hoặc chuyển Board sang Done.
