# M3 — phần cần người dùng thao tác trên Android

Liên quan [#22](https://github.com/tungcorn/project-ptuddd/issues/22) và #4.
Người thao tác: Đình hoặc người hỗ trợ thiết bị đã thống nhất; reviewer: Tùng.
Phiếu này là kịch bản, không tự đánh dấu các ca đạt.
Đã tiếp nhận [báo cáo Đình ngày 22/11/2026](M3-ket-qua-Android-2026-11-22.md):
A/B có quan sát không treo; C và nguồn APK/lifecycle còn cần xác nhận.
Báo cáo ghi đúng giới hạn, chưa nhận đây là nghiệm thu điện thoại thật.

## Chuẩn bị một lần

1. Chọn lúc sẵn sàng dùng micro, ở nơi yên tĩnh. Chỉ đọc câu kiểm thử có chủ
   đích; không cần thu/lưu/gửi file âm thanh hoặc nội dung riêng trên điện thoại.
2. Ghi model, phiên bản Android, dịch vụ nhận dạng và có/không có mạng. Không
   ghi số điện thoại, email, mã kết nối hay thông tin ngoài vùng app.
3. Ghi đúng bản APK đang cài: SHA nguồn do người build xác nhận. Không dùng SHA
   của một checkout khác để nhận là bản trên máy. Nếu chưa biết thì ghi
   “chưa xác định”, nhờ Tùng xác nhận trước khi chốt nghiệm thu bản tích hợp.
4. Mở SingLearn ở chế độ hiện có, giữ dữ liệu; chọn Silent Night, câu “All is
   calm”. Không cần đăng ký Firebase, gửi email, bật dịch vụ cloud hoặc đổi XP.
5. Bằng chứng Android của Tùng ngày 21/11 đã có grant/deny, transcript/điểm,
   no-speech/retry và smoke đổi câu/Back. Không yêu cầu làm lại toàn bộ các ca
   ấy chỉ để tạo thêm hoạt động. Nếu bản/môi trường khác, ghi rõ khác biệt.

## A — Dừng khi thực sự đang nghe và có nói

1. Bấm micro, xác nhận đã hiện **Đang nghe**, không còn ở bước xin quyền/chuẩn bị.
2. Đọc “All is calm”; bấm **Dừng trong lúc vẫn đang nghe**, trước khi dịch vụ
   tự kết thúc. Nếu dịch vụ đã chấm trước khi bấm thì chưa tính là đã test Dừng.
3. Quan sát liền mạch từ thao tác Dừng tới một trạng thái kết thúc: có điểm,
   không nghe thấy giọng nói, hoặc hết hạn dừng có cách thử lại. Ghi kết quả
   thực tế và thời gian chờ xấp xỉ. Giới hạn chờ UI hiện có là 5 giây; không
   suy ra Future stop trả về đồng nghĩa micro vật lý chắc chắn đã tắt.
4. Chờ thêm vài giây: kết quả không tự đổi/chấm thêm ngoài dự kiến. Thử bắt đầu
   lượt mới, xác nhận có thể nghe tiếp rồi thoát màn khi đã xong.

**Mong đợi:** có trạng thái kết thúc/phục hồi rõ, không treo vô hạn, lượt mới
hoạt động. Không yêu cầu phải được điểm cao hoặc đúng transcript; ghi nguyên
transcript của riêng câu kiểm thử nếu cần phân tích. Chỉ nhìn điểm cao nhất
không đủ để chứng minh ledger/XP không ghi trùng.

## B — Dừng khi không nói

1. Ở môi trường yên tĩnh, bấm micro và xác nhận **Đang nghe**.
2. Không đọc câu, bấm Dừng khi trạng thái nghe còn hiện. Nếu đã tự kết thúc
   thì ghi đây là tự kết thúc/no-speech, chưa tính là một lượt Dừng chủ động.
3. Ghi app đi tới no-speech/timeout phục hồi hoặc kết quả nào khác; thử lại
   một lượt. Nếu môi trường có tiếng nền, ghi giới hạn này, không nhận đây là
   thí nghiệm yên lặng đã được kiểm soát.

**Mong đợi:** có thông báo/cách thử lại, không treo; không tự tạo điểm từ partial
chỉ vì quá hạn Dừng. Không tự coi một UI no-speech là bằng chứng mọi đường lỗi
plugin hoặc chất lượng micro đã được kiểm tra.

## C — Xuống nền đủ lâu rồi quay lại

1. Dùng app toàn màn hình, bấm micro và xác nhận **Đang nghe**. Không để hộp
   thoại quyền đang mở trong ca này.
2. Về Home, giữ app ở nền khoảng **10–15 giây**, rồi mở lại. Không dùng thao tác
   Home → mở ngay làm bằng chứng đã đi qua paused.
3. Xác nhận lifecycle với Tùng khi có thể: log Flutter lifecycle hoặc bằng
   chứng Activity đã dừng trong lúc ở Home. Tránh chia đôi màn hình/PiP vì có
   thể vẫn chỉ inactive hoặc còn hiển thị. Khoảng chờ và ảnh Home là quan sát
   UI; nếu chưa có bằng chứng lifecycle thì ghi “chưa xác nhận paused”, chưa
   chốt tiêu chí này đạt và cũng chưa kết luận là bug.
4. Quay lại: phiên cũ không tiếp tục cập nhật/chấm điểm ngoài dự kiến. Nếu hiện
   vẫn đang nghe, ghi đúng hiện tượng, khoảng chờ và bằng chứng lifecycle.
5. Chủ động bấm micro tạo lượt mới, đọc câu kiểm thử, xác nhận lượt mới hoạt
   động; cuối cùng thoát màn phát âm.

**Mong đợi khi đã xác nhận paused:** màn trở về trạng thái cho bắt đầu lại,
callback cũ không ghi điểm, lượt mới hoạt động. Chỉ thấy chỉ báo micro hoặc
một ảnh chụp UI không đủ kết luận trạng thái native trong toàn bộ khoảng chờ.

## Mẫu kết quả gửi lại

Chỉ cần điền các mục sau, kèm ảnh/video **vùng app** nếu thuận tiện; không cần
gửi âm thanh hay log toàn bộ điện thoại:

```text
Bản APK / SHA đã xác nhận:
Thiết bị / Android / dịch vụ nhận dạng / điều kiện mạng:
A. Dừng khi đang nói: trước bấm có Đang nghe? trạng thái sau? chờ bao lâu? thử lại được?
B. Dừng khi không nói: môi trường yên tĩnh? trạng thái sau? thử lại được?
C. Xuống nền: chờ bao lâu? đã xác nhận paused bằng gì? trạng thái khi quay lại? lượt mới được?
Hiện tượng bất thường / chưa xác nhận:
```

## Phần agent/reviewer làm, không yêu cầu người dùng thử tay thay thế

- Test điều khiển seek còn chờ rồi đổi câu/Back, phản hồi cũ/mới đảo thứ tự,
  bắt đầu micro khi mẫu chờ và kiểm tra replay event với ledger dùng API hiện có.
- Đối chiếu quyền/error/unavailable/no-speech/retry với các test đã merge;
  reviewer chạy analyze/test/format khi môi trường agent không khởi động SDK.
- Cập nhật tài liệu với SHA và nguồn, phân tích kết quả A/B/C; chỉ sửa code nếu
  có lỗi hoặc thiếu sót được xác định. Nếu liên quan player/Android/plugin,
  phối hợp M1; nếu liên quan dữ liệu/XP/Auth–Sync, phối hợp M2/M4.
- Kiểm chứng kết quả học trên thiết bị nếu còn thiếu sẽ chốt với M4 theo đúng
  tài khoản/câu/ngày và quy tắc hiện có. Điểm 45 ở lượt Tùng đã thử không chứng
  minh đường thưởng đạt hoặc idempotency. Test local không chứng minh cloud.

#22 và #4 giữ mở tới khi đủ bằng chứng, review và tích hợp cần thiết.
