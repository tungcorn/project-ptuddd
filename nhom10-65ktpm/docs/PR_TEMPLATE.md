<!--
MẪU PR NỘI BỘ NHÓM 10 – SINGLearn

Dùng để đưa công việc của thành viên vào nhánh tích hợp của nhóm:
- Base repository: tungcorn/project-ptuddd
- Base branch: nhom10-65ktpm
- Head branch: feature/nhom10-65ktpm/<tinh-nang>
- Tiêu đề: <loai-thay-doi>(nhom10-65ktpm): <mo-ta-ngan-gon>
  Ví dụ: fix(nhom10-65ktpm): sua lich on flashcard

GitHub không tự điền mẫu từ thư mục nhóm. Sao chép nội dung hoặc dùng
--body-file nhom10-65ktpm/docs/PR_TEMPLATE.md khi tạo PR bằng GitHub CLI.
Chỉ đánh dấu checklist và ghi kết quả kiểm thử thực sự đã thực hiện.
-->

## Mục tiêu

- Tính năng / lỗi / đầu việc cần xử lý: [Điền nội dung hoặc liên kết issue]

## Thay đổi chính

- [Thay đổi thực sự có trong PR]
- [Phần không làm trong PR này, nếu cần giới hạn phạm vi]

## Ảnh hưởng đến phần của thành viên khác

- Mô-đun, API, model, dữ liệu hoặc cấu hình bị ảnh hưởng: [Điền hoặc ghi không có]
- File ngoài phạm vi / file dùng chung theo `docs/PHAN_CONG_HOAN_THIEN.md`: [Liệt kê và ghi người đã phối hợp, hoặc ghi không có]
- Thay đổi cần phối hợp / cách chuyển đổi dữ liệu và thứ tự merge PR phụ thuộc: [Điền hoặc ghi không có]

## Kiểm thử

<!-- Ghi lệnh và kết quả cho đúng phiên bản trong PR. Chưa chạy thì nêu rõ
lý do. PR chỉ sửa tài liệu có thể ghi “Không áp dụng” cho kiểm thử ứng dụng,
kèm kiểm tra nội dung/liên kết đã thực hiện. -->

| Kiểm tra / lệnh chạy | Môi trường / thiết bị | Kết quả thực tế |
| --- | --- | --- |
| [Điền kiểm tra hoặc lệnh] | [Điền môi trường] | [Đạt / lỗi / chưa chạy / không áp dụng + lý do] |

- Cách người review kiểm tra lại: [Các bước thao tác, kết quả mong đợi]
- Ảnh/video minh chứng nếu thay đổi giao diện: [Đính kèm nếu có; che dữ liệu riêng]
- Lỗi hoặc giới hạn còn lại: [Điền hoặc ghi chưa phát hiện trong phạm vi đã kiểm tra]

## Checklist trước khi nhờ review

- [ ] Base là `tungcorn/project-ptuddd:nhom10-65ktpm`, head là nhánh làm việc của mình.
- [ ] PR chỉ chứa thay đổi liên quan đến đầu việc được mô tả.
- [ ] Mọi tệp thay đổi nằm trong `nhom10-65ktpm/`, không sửa tệp gốc hoặc thư mục nhóm khác.
- [ ] Commit mới theo mẫu `<loai-thay-doi>(nhom10-65ktpm): <mo-ta-ngan-gon>`.
- [ ] Không đưa build/cache, APK/AAB, cấu hình Firebase cục bộ, token, mật khẩu hoặc khóa ký vào Git.
- [ ] Đã kiểm tra tương thích với nhánh nhóm; nếu có xung đột mã nguồn thì đã giải quyết và chạy lại kiểm thử ứng dụng.
- [ ] Đã báo rõ thay đổi ảnh hưởng phần của thành viên khác và cập nhật hướng dẫn cần thiết.
- [ ] Kết quả kiểm thử, ảnh minh chứng và giới hạn được ghi đúng thực tế.

## Lưu ý khi merge

- Mọi nhiệm vụ phát triển, **kể cả của nhóm trưởng/admin**, đi qua PR và cần ít nhất **1 người khác duyệt**; người tạo PR không tự duyệt.
- Giải quyết các trao đổi review trước khi merge; thay đổi mới có thể làm mất hiệu lực lượt duyệt cũ.
- Admin vẫn có khả năng bypass theo cấu hình bảo vệ hiện tại, nhưng không dùng làm luồng phát triển thông thường hoặc thay thế review.
