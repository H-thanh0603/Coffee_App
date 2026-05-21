Bạn là một AI Software Engineer chuyên xây dựng mobile app hoàn chỉnh. 
Hãy giúp tôi phát triển một ứng dụng mobile với đề tài:

SmartCafe — Hệ thống quản lí bán cafe, nước uống thông minh

Mục tiêu: Xây dựng một mobile app quản lí bán cafe/nước uống cho quán cafe nhỏ và vừa. Ứng dụng cần có giao diện hiện đại, dễ dùng, phù hợp để demo đồ án tốt nghiệp hoặc môn học. App tập trung vào quản lí bán hàng, order, bàn, pha chế, kho nguyên liệu, khách hàng, nhân viên, khuyến mãi và báo cáo doanh thu. Không cần phần quản trị AI, nhưng có các chức năng thông minh như cảnh báo tồn kho, gợi ý nhập hàng, thống kê món bán chạy/bán chậm.


YÊU CẦU TỔNG QUAN HỆ THỐNG

Ứng dụng gồm các vai trò chính:

1. Admin / Chủ quán
- Quản lí toàn bộ hệ thống
- Quản lí nhân viên
- Quản lí menu
- Quản lí bàn
- Quản lí kho nguyên liệu
- Quản lí khách hàng
- Quản lí voucher
- Xem báo cáo doanh thu
- Xem dashboard cảnh báo thông minh

2. Thu ngân
- Tạo đơn hàng
- Chọn món, size, topping
- Chọn bàn hoặc đơn mang đi
- Áp dụng khuyến mãi
- Thanh toán
- In/xem hóa đơn
- Xem lịch sử đơn hàng

3. Pha chế / Barista
- Xem danh sách đơn đang chờ pha
- Xem chi tiết món, topping, ghi chú
- Cập nhật trạng thái: Chờ pha, Đang pha, Hoàn thành
- Lọc đơn theo thời gian hoặc trạng thái

4. Nhân viên phục vụ
- Xem sơ đồ bàn
- Tạo order theo bàn
- Theo dõi trạng thái món
- Cập nhật bàn trống/đang phục vụ/chờ thanh toán

5. Khách hàng
- Xem menu
- Đặt món qua giao diện khách hàng
- Chọn size, topping, đường, đá
- Theo dõi trạng thái đơn
- Tích điểm thành viên
- Xem voucher cá nhân

Không cần xây dựng phần quản trị AI hoặc cấu hình API key AI.

CÁC MODULE CHÍNH CẦN XÂY DỰNG

1. Đăng nhập và phân quyền

Chức năng:
- Đăng nhập bằng email/password
- Phân quyền theo role: admin, cashier, barista, waiter, customer
- Sau khi đăng nhập, điều hướng đến giao diện phù hợp với từng role
- Có màn hình quên mật khẩu nếu dùng Firebase Auth
- Có màn hình hồ sơ cá nhân

Yêu cầu:
- Không cho user truy cập màn hình không đúng quyền
- Admin có thể tạo tài khoản nhân viên
- Mỗi user có thông tin: họ tên, email, số điện thoại, vai trò, trạng thái hoạt động, ngày tạo

2. Dashboard Admin

Màn hình dashboard cần hiển thị:
- Doanh thu hôm nay
- Số đơn hôm nay
- Tổng khách hàng
- Số bàn đang phục vụ
- Top 5 món bán chạy
- Nguyên liệu sắp hết
- Đơn hàng gần đây
- Biểu đồ doanh thu 7 ngày gần nhất
- Cảnh báo thông minh

Cảnh báo thông minh gồm:
- Nguyên liệu dưới mức tối thiểu
- Món bán chậm trong tuần
- Doanh thu hôm nay thấp hơn hôm qua
- Có nhiều đơn bị hủy
- Gợi ý nhập hàng dựa trên tồn kho và tốc độ bán

3. Quản lí menu đồ uống

Admin có thể:
- Thêm/sửa/xóa món
- Upload ảnh món
- Tạo danh mục: Cafe, Trà sữa, Trà trái cây, Đá xay, Soda, Bánh ngọt
- Cài giá cơ bản
- Cài giá theo size S/M/L
- Cài topping có thể chọn
- Cài trạng thái: đang bán, hết hàng, tạm ẩn
- Tìm kiếm món
- Lọc theo danh mục

Thông tin sản phẩm:
- id
- name
- description
- imageUrl
- categoryId
- basePrice
- sizes: S, M, L
- priceBySize
- availableToppings
- status
- createdAt
- updatedAt

4. Quản lí topping và size

Topping gồm:
- Trân châu đen
- Trân châu trắng
- Kem cheese
- Pudding
- Thạch cafe
- Nha đam
- Đào miếng

Admin có thể:
- Thêm/sửa/xóa topping
- Cài giá topping
- Cài trạng thái còn/hết
- Gắn topping cho sản phẩm

5. Quản lí bàn

Chức năng:
- Tạo danh sách bàn
- Mỗi bàn có mã bàn: B01, B02, B03...
- Trạng thái bàn:
  - Trống
  - Đang phục vụ
  - Chờ thanh toán
  - Đã đặt trước
  - Cần dọn
- Chọn bàn khi tạo đơn
- Chuyển bàn
- Gộp bàn nếu cần
- Xem đơn hiện tại của từng bàn

Thông tin bàn:
- id
- tableName
- capacity
- status
- currentOrderId
- qrCodeValue

6. Bán hàng POS cho thu ngân

Đây là màn hình quan trọng nhất.

Yêu cầu giao diện:
- Bên trái/danh sách trên cùng: danh mục món
- Hiển thị grid sản phẩm có ảnh, tên, giá
- Khi chọn món, mở bottom sheet để chọn:
  - Size
  - Topping
  - Mức đường: 0%, 30%, 50%, 70%, 100%
  - Mức đá: không đá, ít đá, bình thường, nhiều đá
  - Ghi chú
- Giỏ hàng hiển thị danh sách món đã chọn
- Có thể tăng/giảm số lượng
- Có thể xóa món khỏi giỏ
- Có thể chọn bàn hoặc chọn mang đi
- Có thể áp dụng voucher
- Tự tính:
  - Tạm tính
  - Giảm giá
  - Tổng tiền
- Nút thanh toán

Phương thức thanh toán:
- Tiền mặt
- Chuyển khoản
- Ví điện tử
- QR banking mô phỏng

Sau khi thanh toán:
- Đơn chuyển sang trạng thái đã thanh toán
- Nếu là order cần pha chế, gửi đơn sang màn hình barista
- Cập nhật doanh thu
- Trừ kho nguyên liệu theo công thức
- Cập nhật điểm khách hàng nếu có

7. Quản lí đơn hàng realtime

Mỗi đơn hàng có trạng thái:
- pending: Chờ xác nhận
- confirmed: Đã xác nhận
- preparing: Đang pha chế
- ready: Hoàn thành
- served: Đã giao
- paid: Đã thanh toán
- cancelled: Đã hủy

Thông tin đơn hàng:
- id
- orderCode
- tableId
- customerId
- cashierId
- orderType: dine_in / takeaway
- items
- subtotal
- discount
- total
- paymentMethod
- paymentStatus
- orderStatus
- note
- createdAt
- updatedAt

Mỗi item trong đơn:
- productId
- productName
- imageUrl
- size
- toppings
- sugarLevel
- iceLevel
- quantity
- unitPrice
- totalPrice
- note
- status

8. Màn hình pha chế / Barista

Yêu cầu:
- Hiển thị các đơn cần pha theo thời gian thực
- Mỗi đơn là một card
- Card hiển thị:
  - Mã đơn
  - Bàn
  - Thời gian tạo
  - Danh sách món
  - Size
  - Topping
  - Đường/đá
  - Ghi chú
- Có nút:
  - Nhận đơn
  - Đang pha
  - Hoàn thành
- Có tab:
  - Chờ pha
  - Đang pha
  - Hoàn thành
- Đơn mới nhất nằm trên cùng
- Nếu đơn quá lâu chưa hoàn thành thì đổi màu cảnh báo

9. QR Order / Giao diện khách hàng

Vì là mobile app, hãy làm giao diện khách hàng trong app hoặc mô phỏng màn hình QR order.

Chức năng:
- Khách chọn bàn hoặc nhập mã bàn
- Xem menu
- Tìm kiếm món
- Lọc theo danh mục
- Xem chi tiết món
- Chọn size, topping, đường, đá
- Thêm vào giỏ
- Gửi đơn
- Theo dõi trạng thái đơn
- Xem điểm tích lũy
- Xem voucher khả dụng

Không cần thanh toán online thật, chỉ cần mô phỏng.

10. Quản lí kho nguyên liệu

Admin có thể:
- Thêm/sửa/xóa nguyên liệu
- Nhập kho
- Xuất kho
- Xem lịch sử nhập/xuất
- Cài mức tồn tối thiểu
- Cảnh báo sắp hết
- Cảnh báo gần hết hạn

Nguyên liệu mẫu:
- Cafe bột
- Sữa đặc
- Sữa tươi
- Trà đen
- Trà xanh
- Đường
- Syrup đào
- Syrup vải
- Trân châu
- Kem cheese
- Ly nhựa size M
- Ly nhựa size L
- Ống hút
- Nắp ly

Thông tin nguyên liệu:
- id
- name
- unit
- currentStock
- minStock
- costPerUnit
- supplier
- expiredDate
- status
- createdAt
- updatedAt

11. Quản lí công thức pha chế

Mỗi sản phẩm có công thức trừ kho.

Ví dụ:
Bạc xỉu size M:
- Cafe bột: 20g
- Sữa đặc: 30ml
- Sữa tươi: 100ml
- Ly nhựa M: 1 cái
- Ống hút: 1 cái

Trà đào size L:
- Trà đen: 150ml
- Syrup đào: 30ml
- Đào miếng: 40g
- Đường: 15ml
- Ly nhựa L: 1 cái
- Ống hút: 1 cái

Chức năng:
- Admin tạo công thức cho từng món
- Khi đơn được thanh toán hoặc hoàn thành, hệ thống tự động trừ kho
- Nếu nguyên liệu không đủ, hệ thống cảnh báo
- Tính giá vốn dựa trên nguyên liệu
- Tính lợi nhuận ước tính theo từng món

12. Quản lí khách hàng và tích điểm

Thông tin khách hàng:
- id
- fullName
- phone
- email
- points
- rank
- totalSpent
- totalOrders
- favoriteProducts
- createdAt

Chức năng:
- Thêm khách hàng
- Tìm khách bằng số điện thoại
- Gán khách hàng vào đơn
- Tích điểm sau khi thanh toán
- Quy đổi điểm:
  - 10.000đ = 1 điểm
  - 100 điểm = giảm 10.000đ
- Xếp hạng:
  - Đồng: dưới 100 điểm
  - Bạc: 100–299 điểm
  - Vàng: 300–699 điểm
  - Kim cương: từ 700 điểm

13. Quản lí voucher / khuyến mãi

Admin có thể:
- Tạo voucher
- Cài mã giảm giá
- Giảm theo phần trăm
- Giảm theo số tiền
- Cài ngày bắt đầu/kết thúc
- Cài điều kiện đơn tối thiểu
- Cài số lượt dùng
- Cài trạng thái hoạt động

Ví dụ:
- WELCOME10: giảm 10%
- FREESHIP: giảm 15.000đ
- HAPPYHOUR: giảm 20% từ 14h đến 16h
- MEMBER50: giảm 50.000đ cho khách thành viên

14. Báo cáo doanh thu

Màn hình báo cáo cần có:
- Doanh thu theo ngày
- Doanh thu theo tuần
- Doanh thu theo tháng
- Số đơn hàng
- Giá trị trung bình mỗi đơn
- Top món bán chạy
- Top món bán chậm
- Doanh thu theo nhân viên
- Doanh thu theo phương thức thanh toán
- Lợi nhuận ước tính
- Biểu đồ doanh thu
- Bộ lọc thời gian

15. Chức năng thông minh, không cần AI phức tạp

Hãy xây dựng bằng logic thống kê, không cần API AI.

Các chức năng:
- Cảnh báo nguyên liệu sắp hết nếu currentStock <= minStock
- Gợi ý nhập hàng dựa trên tốc độ bán trung bình 7 ngày gần nhất
- Thống kê món bán chạy nhất tuần
- Thống kê món bán chậm nhất tuần
- Cảnh báo doanh thu giảm so với hôm qua
- Gợi ý khuyến mãi cho món bán chậm
- Gợi ý món quen thuộc cho khách hàng dựa trên lịch sử mua
- Cảnh báo đơn pha chế quá lâu

Ví dụ logic:
- Nếu nguyên liệu còn dưới minStock thì hiển thị cảnh báo đỏ
- Nếu doanh thu hôm nay thấp hơn hôm qua trên 20% thì hiển thị cảnh báo
- Nếu một món bán dưới 5 ly trong 7 ngày thì gợi ý khuyến mãi
- Nếu khách từng mua một món trên 3 lần thì đưa vào mục “Món bạn hay dùng”

16. Thông báo

Cần có thông báo trong app:
- Đơn mới cho barista
- Nguyên liệu sắp hết
- Đơn quá lâu chưa hoàn thành
- Voucher sắp hết hạn
- Bàn đang chờ thanh toán

17. Thiết kế giao diện UI/UX

Phong cách:
- Hiện đại
- Sạch sẽ
- Mobile-first
- Màu chủ đạo: nâu cafe, kem, trắng, cam nhạt
- Bo góc mềm
- Card rõ ràng
- Icon dễ hiểu
- Có dark/light mode nếu làm được
- Dễ thao tác bằng một tay
- Font rõ ràng
- Dashboard có biểu đồ đẹp

Các màn hình cần tạo:
1. Splash Screen
2. Onboarding Screen
3. Login Screen
4. Forgot Password Screen
5. Home theo từng role
6. Admin Dashboard
7. POS Order Screen
8. Product List Screen
9. Product Detail Screen
10. Cart Screen
11. Checkout Screen
12. Order History Screen
13. Order Detail Screen
14. Barista Order Queue Screen
15. Table Management Screen
16. Inventory Screen
17. Ingredient Detail Screen
18. Recipe Management Screen
19. Customer Management Screen
20. Customer Detail Screen
21. Voucher Management Screen
22. Report Screen
23. Employee Management Screen
24. Profile Screen
25. Settings Screen

18. Dữ liệu mẫu cần seed sẵn

Hãy tạo dữ liệu mẫu để demo.

Danh mục:
- Cafe
- Trà sữa
- Trà trái cây
- Đá xay
- Soda
- Bánh ngọt

Sản phẩm mẫu:
- Cafe đen
- Cafe sữa
- Bạc xỉu
- Cappuccino
- Latte
- Trà đào cam sả
- Trà vải
- Trà chanh
- Trà sữa truyền thống
- Trà sữa matcha
- Trà sữa chocolate
- Matcha đá xay
- Cookies đá xay
- Soda việt quất
- Bánh tiramisu
- Bánh croissant

Topping mẫu:
- Trân châu đen
- Trân châu trắng
- Kem cheese
- Pudding
- Thạch cafe
- Nha đam
- Đào miếng

Bàn mẫu:
- B01 đến B12

Nhân viên mẫu:
- Admin
- Thu ngân
- Barista
- Phục vụ

Voucher mẫu:
- WELCOME10
- HAPPYHOUR
- MEMBER50
- COMBO20

19. Cấu trúc database gợi ý với Firestore

Collections:

users
- id
- fullName
- email
- phone
- role
- avatarUrl
- status
- createdAt

categories
- id
- name
- description
- icon
- status

products
- id
- name
- description
- imageUrl
- categoryId
- basePrice
- priceBySize
- availableToppingIds
- status
- createdAt
- updatedAt

toppings
- id
- name
- price
- status

tables
- id
- tableName
- capacity
- status
- currentOrderId
- qrCodeValue

orders
- id
- orderCode
- tableId
- customerId
- cashierId
- orderType
- items
- subtotal
- discount
- total
- paymentMethod
- paymentStatus
- orderStatus
- note
- createdAt
- updatedAt

ingredients
- id
- name
- unit
- currentStock
- minStock
- costPerUnit
- supplier
- expiredDate
- status

recipes
- id
- productId
- size
- items

stock_transactions
- id
- ingredientId
- type
- quantity
- note
- createdBy
- createdAt

customers
- id
- fullName
- phone
- email
- points
- rank
- totalSpent
- totalOrders
- favoriteProducts
- createdAt

vouchers
- id
- code
- name
- discountType
- discountValue
- minOrderValue
- maxDiscount
- startDate
- endDate
- usageLimit
- usedCount
- status

notifications
- id
- title
- message
- type
- targetRole
- isRead
- createdAt

20. Quy trình nghiệp vụ chính

Quy trình 1: Tạo đơn tại quầy
- Thu ngân đăng nhập
- Chọn màn hình bán hàng
- Chọn bàn hoặc chọn mang đi
- Chọn món
- Chọn size/topping/đường/đá
- Thêm vào giỏ
- Áp dụng voucher nếu có
- Chọn khách hàng nếu có
- Thanh toán
- Hệ thống tạo đơn
- Đơn chuyển sang quầy pha chế
- Hệ thống trừ kho theo công thức
- Hệ thống cập nhật doanh thu

Quy trình 2: Pha chế xử lý đơn
- Barista đăng nhập
- Xem danh sách đơn chờ pha
- Chọn một đơn
- Bấm nhận đơn
- Trạng thái chuyển sang đang pha
- Sau khi pha xong bấm hoàn thành
- Nhân viên phục vụ giao món
- Trạng thái chuyển sang đã giao

Quy trình 3: Quản lí kho
- Admin thêm nguyên liệu
- Admin nhập kho
- Hệ thống lưu lịch sử nhập kho
- Khi bán hàng, hệ thống tự trừ kho
- Nếu tồn kho thấp hơn mức tối thiểu, hiển thị cảnh báo
- Dashboard hiển thị nguyên liệu sắp hết

Quy trình 4: Khách hàng tích điểm
- Thu ngân chọn khách hàng bằng số điện thoại
- Sau khi thanh toán, hệ thống cộng điểm
- Điểm được cập nhật vào hồ sơ khách hàng
- Nếu đủ điều kiện, khách được nâng hạng
- Khách có thể dùng điểm để giảm giá

21. Yêu cầu code

Hãy viết code sạch, có cấu trúc rõ ràng.

Nếu dùng Flutter, hãy tổ chức project như sau:

lib/
  main.dart
  app.dart
  core/
    constants/
    themes/
    utils/
    widgets/
  data/
    models/
    repositories/
    services/
  features/
    auth/
    dashboard/
    products/
    pos/
    orders/
    barista/
    tables/
    inventory/
    recipes/
    customers/
    vouchers/
    reports/
    employees/
    profile/
  routes/
  firebase_options.dart

Mỗi feature nên có:
- screens/
- widgets/
- providers/
- services/ nếu cần

Yêu cầu:
- Có model rõ ràng
- Có service kết nối Firebase/Firestore
- Có provider/state management
- Có routing rõ ràng
- Có xử lý loading/error/empty state
- Có dữ liệu mẫu để test
- Có README hướng dẫn chạy project
- Có comment ở những phần quan trọng

22. Yêu cầu bảo mật và phân quyền

- Chỉ admin được quản lí nhân viên, sản phẩm, kho, voucher, báo cáo
- Thu ngân chỉ được tạo đơn và thanh toán
- Barista chỉ được xem và cập nhật đơn pha chế
- Nhân viên phục vụ chỉ được quản lí bàn và đơn phục vụ
- Khách hàng chỉ xem menu, đơn của mình và điểm tích lũy
- Firestore rules cần phân quyền cơ bản nếu dùng Firebase

23. Yêu cầu demo

Hãy chuẩn bị app để demo theo kịch bản:

Kịch bản demo 1:
- Đăng nhập admin
- Xem dashboard
- Xem doanh thu
- Xem cảnh báo nguyên liệu sắp hết
- Thêm một món mới
- Xem báo cáo món bán chạy

Kịch bản demo 2:
- Đăng nhập thu ngân
- Tạo đơn cho bàn B03
- Chọn 2 món
- Chọn topping
- Áp dụng voucher
- Thanh toán
- Kiểm tra đơn xuất hiện ở màn hình barista

Kịch bản demo 3:
- Đăng nhập barista
- Xem đơn mới
- Bấm đang pha
- Bấm hoàn thành
- Kiểm tra trạng thái đơn thay đổi

Kịch bản demo 4:
- Đăng nhập admin
- Xem kho nguyên liệu
- Kiểm tra nguyên liệu đã bị trừ sau khi bán
- Xem cảnh báo nếu nguyên liệu sắp hết

24. Yêu cầu README

Hãy tạo file README.md gồm:
- Giới thiệu đề tài
- Công nghệ sử dụng
- Tính năng chính
- Cấu trúc thư mục
- Cách cài đặt
- Cách chạy app
- Tài khoản demo
- Dữ liệu mẫu
- Kịch bản demo
- Hình ảnh màn hình nếu có

25. Tài khoản demo

Tạo các tài khoản demo:

Admin:
email: admin@smartcafe.com
password: 123456

Thu ngân:
email: cashier@smartcafe.com
password: 123456

Barista:
email: barista@smartcafe.com
password: 123456

Phục vụ:
email: waiter@smartcafe.com
password: 123456

Khách hàng:
email: customer@smartcafe.com
password: 123456

26. Kết quả mong muốn

Sau khi hoàn thành, tôi muốn có:
- Một mobile app Flutter chạy được
- Giao diện đẹp, hiện đại
- Có đăng nhập phân quyền
- Có dữ liệu mẫu
- Có quản lí menu
- Có bán hàng POS
- Có quản lí đơn hàng realtime
- Có màn hình pha chế
- Có quản lí bàn
- Có quản lí kho
- Có tự động trừ kho theo công thức
- Có quản lí khách hàng và tích điểm
- Có voucher
- Có báo cáo doanh thu
- Có dashboard cảnh báo thông minh
- Có README hướng dẫn chạy

Hãy bắt đầu bằng cách:
1. Phân tích yêu cầu
2. Đề xuất kiến trúc app
3. Tạo cấu trúc project
4. Cài đặt dependencies
5. Tạo model dữ liệu
6. Tạo service Firebase/Firestore
7. Tạo dữ liệu mẫu
8. Xây dựng từng màn hình chính
9. Kết nối logic nghiệp vụ
10. Kiểm thử luồng demo
11. Viết README

