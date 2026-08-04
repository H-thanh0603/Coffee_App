# ☕ SmartCafe — Hệ thống quản lý bán cafe thông minh

> Mobile app Flutter quản lý bán hàng, order, bàn, pha chế, kho, khách hàng, voucher và báo cáo cho quán cafe nhỏ và vừa.

![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)

## 📌 Giới thiệu

**SmartCafe** là ứng dụng mobile quản lý quán cafe đa vai trò, được xây dựng phục vụ đồ án tốt nghiệp / môn học. App tập trung vào nghiệp vụ thực tế của quán cafe với UI hiện đại, tông màu nâu cafe / kem / cam ấm, phù hợp demo và mở rộng.

App có **5 vai trò** tách biệt với phân quyền rõ ràng và **các chức năng thông minh** dựa trên logic thống kê (không cần AI).

## 🛠️ Công nghệ sử dụng

| Layer | Công nghệ |
|-------|-----------|
| Framework | Flutter 3.10+ / Dart 3.0+ |
| State management | Provider 6 + ChangeNotifier |
| Routing | go_router 13 (declarative + auth guard + phân quyền theo role) |
| UI | Material 3 + Google Fonts (Inter) + Dark/Light mode |
| Charts | fl_chart 0.66 |
| Data | In-memory store (mô phỏng Firestore) + persist qua shared_preferences |
| Utils | uuid, intl, collection |

> Lưu ý: dữ liệu được giữ trong bộ nhớ qua `DataStore` (ChangeNotifier) và **tự lưu xuống SharedPreferences** sau mỗi thao tác — refresh/đóng app không mất dữ liệu. Kiến trúc sẵn sàng swap sang Firestore / REST / SQLite.

## ✨ Tính năng chính

### 1. Đăng nhập & phân quyền
- Login email/password với mock auth (mật khẩu demo: `123456`)
- 5 role: **Admin / Cashier / Barista / Waiter / Customer**
- Auth guard tự động redirect theo route được phép
- **Phân quyền theo role ở tầng router** (`RouteGuard`): user nhập thẳng URL màn không đúng quyền sẽ bị đẩy về màn hình của role

### 2. Admin Dashboard
- Thẻ thống kê: Doanh thu hôm nay, số đơn, khách, bàn đang phục vụ
- Cảnh báo thông minh: nguyên liệu sắp hết, doanh thu giảm, gợi ý nhập hàng, gợi ý khuyến mãi
- Biểu đồ cột doanh thu 7 ngày gần nhất
- Top 5 món bán chạy + đơn gần đây

### 3. POS (Bán hàng cho thu ngân)
- Grid sản phẩm theo danh mục, tìm kiếm realtime
- Bottom sheet chọn: Size (S/M/L), Topping, Đường (0/30/50/70/100%), Đá (Không/Ít/Bình thường/Nhiều), Ghi chú, Số lượng
- Giỏ hàng: chọn bàn / mang đi, chọn khách hàng, áp voucher
- Tự tính tạm tính / giảm giá / tổng tiền
- Thanh toán: Tiền mặt / Chuyển khoản / Ví điện tử / QR Banking (mô phỏng)
- Sau thanh toán: gửi đơn sang barista, **tự động trừ kho theo công thức**, cộng điểm khách, **hiện hóa đơn** (xem lại được từ chi tiết đơn)

### 4. Quản lý đơn hàng realtime
- 7 trạng thái: pending → confirmed → preparing → ready → served → paid / cancelled
- Lịch sử đơn với filter (Tất cả / Hôm nay / Chưa TT / Đã hủy)
- Chi tiết đơn: thông tin, từng item, hủy đơn

### 5. Quầy pha chế / Barista
- 3 tab: **Chờ pha / Đang pha / Hoàn thành**
- Card hiển thị đầy đủ: mã đơn, bàn, thời gian, món + size + topping + đường + đá + ghi chú
- Cảnh báo đỏ nếu đơn quá 10 phút chưa hoàn thành
- Action: Bắt đầu pha → Hoàn thành → Đánh dấu đã giao

### 6. Quản lý bàn (Sơ đồ bàn)
- 12 bàn (B01–B12) với 5 trạng thái màu hiển thị
- Tap bàn để: tạo đơn (chọn sẵn bàn trong giỏ), **chuyển bàn**, **gộp bàn**, đổi trạng thái
- Tự động cập nhật khi tạo/thanh toán đơn

### 7. Quản lý kho nguyên liệu
- 15 nguyên liệu mẫu (cafe bột, sữa, trà, syrup, ly, ống hút...)
- Filter: Tất cả / Sắp hết / Sắp hết hạn
- Nhập kho / Xuất kho thủ công + ghi log lịch sử
- Cảnh báo trực quan với progress bar màu (xanh/cam/đỏ)
- **Tự động trừ kho theo công thức** khi đơn vào trạng thái "đang pha"

### 8. Quản lý công thức pha chế
- Mỗi món × size có công thức riêng (định lượng từng nguyên liệu)
- **Thêm/sửa/xóa công thức**; cảnh báo sản phẩm chưa có công thức (không trừ kho được)
- Tự tính giá vốn và lợi nhuận ước tính

### 9. Quản lý khách hàng & tích điểm
- Tìm theo tên / SĐT; tap khách để xem **chi tiết**: hạng, điểm, đã chi, **lịch sử đơn**, **món hay dùng**; sửa thông tin
- 4 hạng theo điểm: **Đồng / Bạc / Vàng / Kim cương**
- Quy đổi: 10.000đ = 1 điểm; 100 điểm = giảm 10.000đ
- **Dùng điểm giảm giá ngay tại giỏ hàng** khi đã chọn khách hàng
- Tự cộng điểm và nâng hạng sau thanh toán; khách hàng xem **món bạn hay dùng** ở menu

### 10. Voucher / Khuyến mãi
- Giảm theo phần trăm hoặc số tiền cố định
- Form đầy đủ: ngày bắt đầu/kết thúc (date picker), đơn tối thiểu, giảm tối đa, lượt dùng
- **Sửa / xóa** voucher, toggle hoạt động ngay trong list

### 11. Báo cáo doanh thu
- Bộ lọc: Hôm nay / 7 ngày / 30 ngày (chart đổi theo bộ lọc)
- **Lợi nhuận ước tính** (doanh thu - giá vốn theo công thức) + biên lợi nhuận
- Doanh thu theo phương thức thanh toán, theo nhân viên
- Top món bán chạy / bán chậm
- TB/đơn

### 12. Quản lý nhân viên (Admin)
- Thêm/sửa nhân viên với 4 vai trò (tap để sửa)
- Toggle trạng thái hoạt động, xóa nhân viên

### 13. Giao diện khách hàng
- 3 tab: Menu / Đơn của tôi / Voucher khả dụng
- Mua hàng tương tự POS, theo dõi trạng thái đơn

### 14. Chức năng thông minh (logic-based)
- Cảnh báo nguyên liệu dưới ngưỡng tối thiểu
- Cảnh báo doanh thu giảm > 20% so với hôm qua
- Cảnh báo **nhiều đơn bị hủy** trong 7 ngày
- Gợi ý nhập hàng dựa trên tốc độ tiêu thụ 7 ngày
- Gợi ý khuyến mãi cho món bán chậm
- Cảnh báo đơn pha quá 10 phút (màu đỏ ở quầy barista)
- **Thông báo trong app**: đơn mới cho barista, nguyên liệu sắp hết, voucher sắp hết hạn (<=3 ngày), bàn chờ thanh toán, chuyển/gộp bàn

### 15. Cài đặt & Dark mode
- Màn **Cài đặt** trong drawer (mọi role)
- Chuyển đổi **Light / Dark / Theo hệ thống**, lưu lựa chọn qua SharedPreferences
- Toàn bộ màn hình dùng bảng màu thích ứng theo theme

### 16. Quản lý menu (Admin)
- **Sản phẩm**: thêm/sửa/xóa món, cài **giá theo size S/M/L**, **gắn topping** có thể chọn, toggle hết hàng/tạm ẩn
- **Danh mục**: thêm/sửa/xóa, icon/emoji, bật/tắt hiển thị
- **Topping**: thêm/sửa/xóa, cài giá, toggle còn hàng

## 📁 Cấu trúc thư mục

```
lib/
├── main.dart                          # Entry point, khởi tạo providers
├── app.dart                           # Root widget + theme
├── core/
│   ├── constants/enums.dart           # UserRole, OrderStatus, TableStatus...
│   ├── theme/                         # AppColors (light/dark), AppTheme, ThemeProvider
│   ├── utils/formatters.dart          # Money, date, time, relative
│   └── widgets/                       # AppDrawer, StatCard, StatusBadge, EmptyState
├── data/
│   ├── models/                        # 13 model: User, Product, Order, Topping...
│   ├── seed/                          # Dữ liệu mẫu (16 món, 12 bàn, 15 NL...)
│   └── services/                      # data_store.dart + persistence.dart (JSON save/load)
├── features/
│   ├── auth/                          # Login, Splash, AuthProvider
│   ├── cart/                          # CartProvider
│   ├── dashboard/                     # Admin dashboard + RevenueChart
│   ├── pos/                           # POS, ProductOptionsSheet, CartPanel, Checkout
│   ├── orders/                        # History + Detail
│   ├── barista/                       # Barista queue (3 tabs)
│   ├── tables/                        # Sơ đồ bàn
│   ├── inventory/                     # Kho NL + nhập/xuất
│   ├── recipes/                       # Công thức + giá vốn/lãi
│   ├── customers/                     # Khách hàng + tích điểm
│   ├── vouchers/                      # Voucher CRUD
│   ├── reports/                       # Báo cáo doanh thu
│   ├── employees/                     # Quản lý NV
│   ├── products/                      # Menu CRUD
│   ├── settings/                      # Cài đặt + Dark mode
│   ├── profile/                       # Hồ sơ
│   └── customer_app/                  # Giao diện khách hàng
└── routes/                            # GoRouter + RoleRouter + RouteGuard
```

`test/` có 22 test: nghiệp vụ DataStore (order, kho, voucher, điểm), phân quyền RouteGuard, smoke test app.

## 🚀 Cài đặt & chạy app

### Yêu cầu
- Flutter SDK >= 3.10
- Dart >= 3.0
- Android Studio / VS Code / Xcode (tùy nền tảng)

### Bước 1: Clone repo
```bash
git clone https://github.com/H-thanh0603/Coffee_App.git
cd Coffee_App
```

### Bước 2: Cài dependencies
```bash
flutter pub get
```

### Bước 3: Chạy app
```bash
# Chạy trên emulator/device đã kết nối
flutter run

# Hoặc chỉ định nền tảng
flutter run -d chrome      # Web
flutter run -d windows     # Windows desktop
flutter run -d android     # Android
```

### Bước 4: Build release
```bash
flutter build apk --release           # Android APK
flutter build appbundle --release     # Android AAB (Play Store)
flutter build ios --release           # iOS
flutter build web --release           # Web
```

## 🔐 Tài khoản demo

Mật khẩu chung: **`123456`**

| Vai trò | Email | Tính năng được dùng |
|---------|-------|---------------------|
| 👨‍💼 Admin | `admin@smartcafe.com` | Toàn quyền hệ thống |
| 🧾 Thu ngân | `cashier@smartcafe.com` | POS, đơn hàng, bàn |
| 🧑‍🍳 Pha chế | `barista@smartcafe.com` | Quầy pha chế |
| 🛎️ Phục vụ | `waiter@smartcafe.com` | Sơ đồ bàn, đơn |
| 🙋 Khách | `customer@smartcafe.com` | Menu, đơn của tôi, voucher |

> Tip: tại màn hình Login có sẵn các nút quick-login cho từng role.

## 📦 Dữ liệu mẫu

App được seed sẵn:
- **5 user** (đại diện 5 role)
- **6 danh mục**: Cafe, Trà sữa, Trà trái cây, Đá xay, Soda, Bánh ngọt
- **16 sản phẩm**: Cafe đen, Cafe sữa, Bạc xỉu, Cappuccino, Latte, Trà đào cam sả, Trà vải, Trà chanh, Trà sữa truyền thống, Matcha, Chocolate, Matcha đá xay, Cookies đá xay, Soda việt quất, Tiramisu, Croissant
- **7 topping**: Trân châu đen/trắng, Kem cheese, Pudding, Thạch cafe, Nha đam, Đào miếng
- **12 bàn**: B01–B12
- **15 nguyên liệu** + công thức pha chế cho 14 món
- **5 voucher**: WELCOME10, FREESHIP, HAPPYHOUR, MEMBER50, COMBO20
- **5 khách hàng** mẫu với điểm tích lũy ở các hạng khác nhau
- **~40 đơn hàng** rải đều 7 ngày để dashboard có dữ liệu

## 🎬 Kịch bản demo

### Kịch bản 1: Admin xem dashboard
1. Đăng nhập `admin@smartcafe.com`
2. Xem doanh thu hôm nay, số đơn, top món bán chạy
3. Xem cảnh báo nguyên liệu sắp hết (Trân châu, Ly L)
4. Vào Menu sản phẩm → Thêm món mới

### Kịch bản 2: Cashier tạo đơn
1. Đăng nhập `cashier@smartcafe.com`
2. Tap "Trà đào cam sả" → chọn size L, topping Đào miếng, đường 50%, đá ít → Thêm
3. Tap "Trà sữa truyền thống" → chọn size M, topping Trân châu đen → Thêm
4. Mở giỏ hàng → chọn bàn B03 → áp voucher WELCOME10
5. Thanh toán bằng QR Banking → hoàn thành

### Kịch bản 3: Barista pha đơn
1. Đăng nhập `barista@smartcafe.com`
2. Tab "Chờ pha" → bấm "Bắt đầu pha" trên đơn vừa tạo
3. Đơn chuyển sang "Đang pha" — kho tự trừ nguyên liệu theo công thức
4. Bấm "Hoàn thành" → đơn sẵn sàng giao

### Kịch bản 4: Admin kiểm tra kho
1. Quay lại admin → Kho nguyên liệu
2. Kiểm tra Trà đen, Đào miếng, Sữa đặc, Ly L đã giảm
3. Filter "Sắp hết" → thấy danh sách cần nhập
4. Bấm "Nhập" → nhập thêm 2000g Trân châu

## 🎨 Thiết kế UI/UX

- **Phong cách**: Hiện đại, sạch sẽ, mobile-first
- **Màu chủ đạo**: Nâu cafe `#6F4E37`, Kem `#FAF6F1`, Cam ấm `#D4A574`, Accent `#F59E0B`
- **Bo góc mềm**: 12-16px cho cards, 20-24px cho bottom sheets
- **Font**: Inter (Google Fonts)
- **Icon**: Material Icons + emoji món/topping
- **Dễ thao tác bằng một tay**: action buttons ở dưới, chip filter ngang

## 🔮 Mở rộng

App được thiết kế để dễ thay backend thật:

1. **Firebase/Firestore**: thay `DataStore` bằng repositories gọi `cloud_firestore`. Toàn bộ provider/UI giữ nguyên.
2. **REST API**: bổ sung `services/api_client.dart` với `dio`/`http`, repository pattern.
3. **SQLite (offline-first)**: dùng `sqflite` + sync queue.

## 📝 Notes nghiệp vụ

- **Tính điểm**: 10.000đ = 1 điểm. 100 điểm = giảm 10.000đ
- **Hạng**: Đồng (<100) / Bạc (100-299) / Vàng (300-699) / Kim cương (≥700)
- **Trừ kho**: chỉ trừ khi order chuyển sang `preparing` — đảm bảo đơn cancel chưa pha không bị trừ
- **Voucher**: kiểm tra `isAvailable` (đang trong khoảng ngày, còn lượt, đạt min order)

## 📄 License

MIT

## 👨‍💻 Tác giả

Đồ án xây dựng bởi **Nguyễn Hữu Thanh**.
