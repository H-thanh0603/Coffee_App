# Spec: Dark Mode cho Coffee App

## Tổng quan
Thêm chế độ Dark Mode (giao diện tối) vào ứng dụng Coffee App, cho phép người dùng chuyển đổi giữa Light/Dark theme.

## Yêu cầu chức năng
- [ ] Toggle Dark/Light mode từ Settings screen
- [ ] Hỗ trợ System theme (theo cài đặt iOS/Android)
- [ ] Lưu lựa chọn của người dùng (SharedPreferences)
- [ ] Tất cả màn hình hiện có phải tương thích Dark mode
- [ ] Transition mượt khi chuyển theme

## Yêu cầu kỹ thuật
- Dùng `ThemeMode` của Flutter (system/light/dark)
- Dùng `MaterialTheme` với `darkTheme` property
- Màu sắc: dùng `ColorScheme.fromSeed()` hoặc custom scheme
- Test trên cả Light và Dark mode

## Ràng buộc
- Flutter 3.44 — không dùng API mới hơn
- Không làm vỡ giao diện hiện tại
- Không thêm package nếu Flutter đã có sẵn
