# Hướng dẫn AI – SingLearn / Nhóm 10 · 65KTPM

## Phạm vi và tài liệu

- Chỉ thêm/sửa tệp trong `nhom10-65ktpm/`. Không sửa tệp gốc của kho hoặc thư mục nhóm khác.
- Đọc `README.md` của nhóm để biết cách chạy, trạng thái kiểm chứng và quy trình Git ở mục 6. Quy định học phần nằm trong `../README.md`.
- Đọc `docs/PHAN_CONG_HOAN_THIEN.md` và issue được giao trước khi sửa: xác định phạm vi file, người điều phối file chung, giao tiếp và tiêu chí nghiệm thu. Không tự sửa ngoài phạm vi; đề xuất thay đổi và thống nhất một người/PR thực hiện trước.
- PR nội bộ dùng `docs/PR_TEMPLATE.md`. Cấu hình và kiểm thử Firebase xem `firebase/README.md`.
- Các đường dẫn tài liệu ở trên tính từ thư mục chứa file này. Các lệnh Git bên dưới tính từ gốc kho `project-ptuddd`.

## Nhánh làm việc – không tự tạo nhánh cho mọi đầu việc

- Trước khi sửa, kiểm tra `git status` và nhánh hiện tại. Giữ nguyên thay đổi chưa commit của người dùng; không tự reset, stash hoặc ghi đè.
- Không tự tạo/chuyển nhánh chỉ vì bắt đầu một yêu cầu mới. Nếu đang ở nhánh tính năng phù hợp, tiếp tục dùng nhánh đó; không tạo nhánh mới cho mỗi commit.
- Theo yêu cầu phối hợp GitHub mới, mọi nhiệm vụ phát triển, kể cả của nhóm trưởng/admin, dùng nhánh `feature/nhom10-65ktpm/<dau-viec>` từ nhánh nhóm mới nhất rồi PR vào `nhom10-65ktpm`, có người khác review trước merge. Nếu đang ở nhánh nhóm và bắt đầu nhiệm vụ phát triển đã được giao, tạo nhánh tính năng phù hợp; không commit/push trực tiếp lên nhánh nhóm theo quy trình thông thường.
- Không lấy một nhánh tính năng chưa merge khác làm base nếu chưa thống nhất. Quyền admin bypass hiện có là khả năng kỹ thuật, không phải quy trình phát triển; không tự dùng để bỏ qua PR/review.
- Không suy đoán quyền admin từ cấu hình tên/email Git. Nếu cách làm phụ thuộc quyền mà chưa biết, xác minh hoặc hỏi trước khi thay đổi nhánh.
- Không commit/push trực tiếp vào `main`. Không tự viết lại lịch sử, force push hoặc xóa nhánh.

## Commit, push và PR

- Chỉ commit, push, tạo/merge PR, publish hoặc deploy khi người dùng yêu cầu rõ phạm vi. Quyền admin không thay thế sự cho phép của người dùng.
- Mọi commit mới theo mẫu: `<loai>(nhom10-65ktpm): <mo-ta-ngan-gon>`.
  - `feat(nhom10-65ktpm): them loc bai hat theo trinh do`
  - `fix(nhom10-65ktpm): sua lich on flashcard`
  - `docs(nhom10-65ktpm): huong dan chay Firebase`
- Mô tả đúng thay đổi, mỗi commit tập trung một đầu việc. Không tự thay đổi danh tính Git hoặc quy tác giả cho thành viên khác.
- Không dùng `git add .` ở gốc kho. Chỉ stage đường dẫn cụ thể bên trong `nhom10-65ktpm/`, xem lại staged diff và chạy `git diff --cached --check` trước commit.
- Không gộp thay đổi không liên quan hoặc công việc chưa thống nhất của người khác vào commit.
- PR nội bộ: repository `tungcorn/project-ptuddd`, base `nhom10-65ktpm`, head là nhánh tính năng. Điền mẫu nội bộ, ghi kết quả kiểm thử thực tế; mẫu không tự điền trên GitHub.
- Mọi PR nhiệm vụ phát triển cần ít nhất một người khác duyệt và giải quyết các trao đổi review trước merge, áp dụng cả nhóm trưởng/admin. Không tự duyệt, không tạo review/bình luận dưới danh tính thành viên khác. Commit mới làm mất hiệu lực lượt duyệt cũ.
- PR nộp bài cho giảng viên là quy trình riêng, không tự mở khi được yêu cầu tạo PR nội bộ. Đóng PR không có nghĩa đã merge.
- Sau push/merge, kiểm tra trạng thái local và remote rồi báo đúng nhánh, commit và kết quả. Không tự mở PR chỉ vì GitHub in ra liên kết gợi ý sau push.

## Kiểm thử và báo cáo

- Làm trực tiếp các tác vụ vừa sức; không mặc định gọi subagent hoặc nhiều AI cho mỗi bước.
- Với thay đổi Flutter, chạy kiểm tra phù hợp từ `nhom10-65ktpm/src/`: `flutter analyze` và test liên quan; chạy toàn bộ `flutter test` khi phạm vi thay đổi cần thiết.
- Với Firestore Rules, dùng bộ test emulator theo hướng dẫn Firebase. Không tự chạy smoke test lên cloud thật khi chưa được phép.
- Sau khi giải quyết xung đột mã nguồn, phải chạy lại kiểm thử ứng dụng trước khi hoàn tất tích hợp.
- Chỉ sửa tài liệu thì kiểm tra nội dung, liên kết và diff; không cần build ứng dụng nếu không có thay đổi code/cấu hình liên quan.
- Không coi build thành công, test giả lập hoặc smoke test JS SDK là bằng chứng đã chạy ứng dụng Flutter cloud trên Android.
- Báo rõ lệnh đã chạy, kết quả, lỗi/cảnh báo đáng chú ý và phần chưa kiểm chứng. Không bịa bằng chứng hoặc đánh dấu checklist chưa thực hiện.

## Bảo mật và Firebase

- Không commit `firebase.env.json`, token, mật khẩu, service account, keystore, APK/AAB, dependencies hoặc build/cache. Chỉ đưa cấu hình mẫu không có thông tin riêng lên Git.
- Project SingLearn là `singlearn-nhom10-65ktpm`. Không thao tác sang StudyDoc hoặc dự án khác.
- Không tự liên kết billing, đổi gói hoặc bật/triển khai dịch vụ trả phí. Mặc định dùng Auth email/mật khẩu và Firestore; Storage, Functions, FCM và Google sign-in chưa bật.
- Không công khai email trong `publicProfiles`; tìm bạn cloud bằng mã bạn bè. Giữ Security Rules và kiểm thử tương thích khi thay đổi schema.
- Không thay đổi cấu hình toàn máy, model, công cụ hoặc tài khoản dùng chung chỉ để hoàn thành tác vụ thuận tiện hơn khi chưa được phép.
