-- SmartCafe demo data. Runs after migrations on `supabase db reset` / fresh start.
-- Ids match lib/data/seed/*.dart exactly so the local store and DB agree.

-- ===== categories =====
insert into public.categories (id, name, description, icon) values
  ('cat-cafe', 'Cafe', '', '☕'),
  ('cat-tea-milk', 'Trà sữa', '', '🧋'),
  ('cat-tea-fruit', 'Trà trái cây', '', '🍑'),
  ('cat-ice-blend', 'Đá xay', '', '🧊'),
  ('cat-soda', 'Soda', '', '🥤'),
  ('cat-cake', 'Bánh ngọt', '', '🍰')
on conflict (id) do nothing;

-- ===== toppings =====
insert into public.toppings (id, name, price, available) values
  ('tp-pearl-black', 'Trân châu đen', 7000, true),
  ('tp-pearl-white', 'Trân châu trắng', 7000, true),
  ('tp-cheese', 'Kem cheese', 10000, true),
  ('tp-pudding', 'Pudding', 8000, true),
  ('tp-coffee-jelly', 'Thạch cafe', 8000, true),
  ('tp-aloe', 'Nha đam', 8000, true),
  ('tp-peach', 'Đào miếng', 10000, true)
on conflict (id) do nothing;

-- ===== products =====
insert into public.products (id, name, description, emoji, category_id, base_price, price_by_size, available_topping_ids) values
  ('p-caphe-den','Cafe đen','Cafe phin truyền thống đậm đà, thơm nồng.','☕','cat-cafe',25000,'{"s":25000,"m":30000,"l":35000}','["tp-coffee-jelly","tp-pudding"]'),
  ('p-caphe-sua','Cafe sữa','Cafe phin pha sữa đặc, vị ngọt béo cân bằng.','🥛','cat-cafe',30000,'{"s":30000,"m":35000,"l":40000}','["tp-coffee-jelly","tp-pudding"]'),
  ('p-bac-xiu','Bạc xỉu','Sữa nhiều cafe ít, vị ngọt béo dịu nhẹ.','🤎','cat-cafe',32000,'{"s":32000,"m":38000,"l":42000}','[]'),
  ('p-cappuccino','Cappuccino','Espresso, sữa nóng và lớp foam mịn màng.','☕','cat-cafe',45000,'{"s":45000,"m":50000,"l":55000}','[]'),
  ('p-latte','Latte','Espresso pha sữa nóng, foam mỏng, vị nhẹ.','🍮','cat-cafe',48000,'{"s":48000,"m":52000,"l":58000}','[]'),
  ('p-tra-dao','Trà đào cam sả','Trà đen, đào miếng, cam sả tươi mát.','🍑','cat-tea-fruit',35000,'{"s":35000,"m":40000,"l":45000}','["tp-peach","tp-aloe"]'),
  ('p-tra-vai','Trà vải','Trà đen ngâm vải tươi, ngọt thanh.','🍒','cat-tea-fruit',35000,'{"s":35000,"m":40000,"l":45000}','["tp-aloe"]'),
  ('p-tra-chanh','Trà chanh','Trà đen, chanh tươi, đường, đá nhiều.','🍋','cat-tea-fruit',25000,'{"s":25000,"m":30000,"l":35000}','[]'),
  ('p-trasua-truyenthong','Trà sữa truyền thống','Trà đen pha sữa béo, vị thơm cổ điển.','🧋','cat-tea-milk',35000,'{"s":35000,"m":40000,"l":45000}','["tp-pearl-black","tp-pearl-white","tp-pudding","tp-cheese"]'),
  ('p-trasua-matcha','Trà sữa matcha','Bột matcha Nhật Bản pha sữa béo ngậy.','🍵','cat-tea-milk',42000,'{"s":42000,"m":48000,"l":52000}','["tp-pearl-black","tp-pudding","tp-cheese"]'),
  ('p-trasua-chocolate','Trà sữa chocolate','Cacao đậm pha sữa, vị ngọt nhẹ.','🍫','cat-tea-milk',40000,'{"s":40000,"m":45000,"l":50000}','["tp-pearl-black","tp-pudding","tp-cheese"]'),
  ('p-matcha-dax','Matcha đá xay','Matcha pha kem tươi đá xay mát lạnh.','🥤','cat-ice-blend',50000,'{"s":50000,"m":55000,"l":60000}','["tp-cheese"]'),
  ('p-cookies-dax','Cookies đá xay','Bánh cookies xay nhuyễn với kem tươi và đá.','🍪','cat-ice-blend',52000,'{"s":52000,"m":57000,"l":62000}','["tp-cheese"]'),
  ('p-soda-vietquat','Soda việt quất','Soda mát lạnh kết hợp syrup việt quất.','🫐','cat-soda',38000,'{"s":38000,"m":43000,"l":48000}','[]'),
  ('p-banh-tiramisu','Bánh tiramisu','Bánh tiramisu Ý mềm mịn vị cafe.','🍰','cat-cake',45000,'{"m":45000}','[]'),
  ('p-banh-croissant','Bánh croissant','Bánh sừng bò bơ Pháp giòn tan.','🥐','cat-cake',30000,'{"m":30000}','[]')
on conflict (id) do nothing;

-- ===== ingredients =====
insert into public.ingredients (id, name, unit, current_stock, min_stock, cost_per_unit, supplier, expired_date) values
  ('ing-cafe-bot','Cafe bột','g',5000,2000,0.6,'Trung Nguyên', now() + interval '90 days'),
  ('ing-sua-dac','Sữa đặc','ml',8000,3000,0.08,'Vinamilk', now() + interval '120 days'),
  ('ing-sua-tuoi','Sữa tươi','ml',12000,5000,0.05,'TH True Milk', now() + interval '14 days'),
  ('ing-tra-den','Trà đen','g',1800,1000,0.5,'Phúc Long', now() + interval '180 days'),
  ('ing-tra-xanh','Trà xanh','g',1200,800,0.6,'Phúc Long', now() + interval '180 days'),
  ('ing-duong','Đường','g',10000,3000,0.02,'Biên Hòa', null),
  ('ing-syrup-dao','Syrup đào','ml',1800,1000,0.3,'Monin', now() + interval '365 days'),
  ('ing-syrup-vai','Syrup vải','ml',2000,1000,0.3,'Monin', now() + interval '365 days'),
  ('ing-tran-chau','Trân châu','g',400,1000,0.15,'Royaltea', now() + interval '5 days'),
  ('ing-kem-cheese','Kem cheese','ml',1500,800,0.5,'Anchor', now() + interval '21 days'),
  ('ing-ly-m','Ly nhựa size M','cái',800,200,1500,'Bao bì Phương Nam', null),
  ('ing-ly-l','Ly nhựa size L','cái',150,200,2000,'Bao bì Phương Nam', null),
  ('ing-ong-hut','Ống hút','cái',1500,500,200,'Bao bì Phương Nam', null),
  ('ing-nap-ly','Nắp ly','cái',900,300,500,'Bao bì Phương Nam', null),
  ('ing-dao-mieng','Đào miếng','g',800,500,0.4,'Đào VN', now() + interval '7 days')
on conflict (id) do nothing;

-- ===== recipes + recipe_items =====
insert into public.recipes (id, product_id, size) values
  ('rc-p-caphe-den-m','p-caphe-den','m'),
  ('rc-p-caphe-den-l','p-caphe-den','l'),
  ('rc-p-caphe-sua-m','p-caphe-sua','m'),
  ('rc-p-bac-xiu-m','p-bac-xiu','m'),
  ('rc-p-cappuccino-m','p-cappuccino','m'),
  ('rc-p-latte-m','p-latte','m'),
  ('rc-p-tra-dao-l','p-tra-dao','l'),
  ('rc-p-tra-dao-m','p-tra-dao','m'),
  ('rc-p-tra-vai-m','p-tra-vai','m'),
  ('rc-p-tra-chanh-m','p-tra-chanh','m'),
  ('rc-p-trasua-truyenthong-m','p-trasua-truyenthong','m'),
  ('rc-p-trasua-matcha-m','p-trasua-matcha','m'),
  ('rc-p-soda-vietquat-m','p-soda-vietquat','m'),
  ('rc-p-banh-tiramisu-m','p-banh-tiramisu','m')
on conflict (id) do nothing;

insert into public.recipe_items (recipe_id, ingredient_id, quantity, unit) values
  ('rc-p-caphe-den-m','ing-cafe-bot',20,'g'),('rc-p-caphe-den-m','ing-duong',10,'g'),('rc-p-caphe-den-m','ing-ly-m',1,'cái'),('rc-p-caphe-den-m','ing-ong-hut',1,'cái'),('rc-p-caphe-den-m','ing-nap-ly',1,'cái'),
  ('rc-p-caphe-den-l','ing-cafe-bot',25,'g'),('rc-p-caphe-den-l','ing-duong',12,'g'),('rc-p-caphe-den-l','ing-ly-l',1,'cái'),('rc-p-caphe-den-l','ing-ong-hut',1,'cái'),('rc-p-caphe-den-l','ing-nap-ly',1,'cái'),
  ('rc-p-caphe-sua-m','ing-cafe-bot',18,'g'),('rc-p-caphe-sua-m','ing-sua-dac',25,'ml'),('rc-p-caphe-sua-m','ing-ly-m',1,'cái'),('rc-p-caphe-sua-m','ing-ong-hut',1,'cái'),('rc-p-caphe-sua-m','ing-nap-ly',1,'cái'),
  ('rc-p-bac-xiu-m','ing-cafe-bot',10,'g'),('rc-p-bac-xiu-m','ing-sua-dac',30,'ml'),('rc-p-bac-xiu-m','ing-sua-tuoi',100,'ml'),('rc-p-bac-xiu-m','ing-ly-m',1,'cái'),('rc-p-bac-xiu-m','ing-ong-hut',1,'cái'),('rc-p-bac-xiu-m','ing-nap-ly',1,'cái'),
  ('rc-p-cappuccino-m','ing-cafe-bot',20,'g'),('rc-p-cappuccino-m','ing-sua-tuoi',150,'ml'),('rc-p-cappuccino-m','ing-ly-m',1,'cái'),('rc-p-cappuccino-m','ing-nap-ly',1,'cái'),
  ('rc-p-latte-m','ing-cafe-bot',20,'g'),('rc-p-latte-m','ing-sua-tuoi',180,'ml'),('rc-p-latte-m','ing-ly-m',1,'cái'),('rc-p-latte-m','ing-nap-ly',1,'cái'),
  ('rc-p-tra-dao-l','ing-tra-den',150,'ml'),('rc-p-tra-dao-l','ing-syrup-dao',30,'ml'),('rc-p-tra-dao-l','ing-dao-mieng',40,'g'),('rc-p-tra-dao-l','ing-duong',15,'g'),('rc-p-tra-dao-l','ing-ly-l',1,'cái'),('rc-p-tra-dao-l','ing-ong-hut',1,'cái'),('rc-p-tra-dao-l','ing-nap-ly',1,'cái'),
  ('rc-p-tra-dao-m','ing-tra-den',120,'ml'),('rc-p-tra-dao-m','ing-syrup-dao',25,'ml'),('rc-p-tra-dao-m','ing-dao-mieng',30,'g'),('rc-p-tra-dao-m','ing-duong',12,'g'),('rc-p-tra-dao-m','ing-ly-m',1,'cái'),('rc-p-tra-dao-m','ing-ong-hut',1,'cái'),('rc-p-tra-dao-m','ing-nap-ly',1,'cái'),
  ('rc-p-tra-vai-m','ing-tra-den',120,'ml'),('rc-p-tra-vai-m','ing-syrup-vai',25,'ml'),('rc-p-tra-vai-m','ing-duong',12,'g'),('rc-p-tra-vai-m','ing-ly-m',1,'cái'),('rc-p-tra-vai-m','ing-ong-hut',1,'cái'),('rc-p-tra-vai-m','ing-nap-ly',1,'cái'),
  ('rc-p-tra-chanh-m','ing-tra-den',100,'ml'),('rc-p-tra-chanh-m','ing-duong',15,'g'),('rc-p-tra-chanh-m','ing-ly-m',1,'cái'),('rc-p-tra-chanh-m','ing-ong-hut',1,'cái'),('rc-p-tra-chanh-m','ing-nap-ly',1,'cái'),
  ('rc-p-trasua-truyenthong-m','ing-tra-den',100,'ml'),('rc-p-trasua-truyenthong-m','ing-sua-dac',40,'ml'),('rc-p-trasua-truyenthong-m','ing-tran-chau',30,'g'),('rc-p-trasua-truyenthong-m','ing-duong',10,'g'),('rc-p-trasua-truyenthong-m','ing-ly-m',1,'cái'),('rc-p-trasua-truyenthong-m','ing-ong-hut',1,'cái'),('rc-p-trasua-truyenthong-m','ing-nap-ly',1,'cái'),
  ('rc-p-trasua-matcha-m','ing-tra-xanh',8,'g'),('rc-p-trasua-matcha-m','ing-sua-tuoi',150,'ml'),('rc-p-trasua-matcha-m','ing-duong',12,'g'),('rc-p-trasua-matcha-m','ing-ly-m',1,'cái'),('rc-p-trasua-matcha-m','ing-ong-hut',1,'cái'),('rc-p-trasua-matcha-m','ing-nap-ly',1,'cái'),
  ('rc-p-soda-vietquat-m','ing-syrup-vai',30,'ml'),('rc-p-soda-vietquat-m','ing-duong',10,'g'),('rc-p-soda-vietquat-m','ing-ly-m',1,'cái'),('rc-p-soda-vietquat-m','ing-ong-hut',1,'cái'),('rc-p-soda-vietquat-m','ing-nap-ly',1,'cái'),
  ('rc-p-banh-tiramisu-m','ing-sua-tuoi',50,'ml')
on conflict (recipe_id, ingredient_id) do nothing;

-- ===== tables =====
insert into public.cafe_tables (id, table_name, capacity, qr_code_value)
select 'tb-B' || lpad(i::text, 2, '0'), 'B' || lpad(i::text, 2, '0'),
  case when i <= 4 then 2 when i <= 8 then 4 else 6 end,
  'smartcafe://table/tb-B' || lpad(i::text, 2, '0')
from generate_series(1, 12) as i
on conflict (id) do nothing;

-- ===== customers =====
insert into public.customers (id, full_name, phone, email, points, rank, total_spent, total_orders) values
  ('cu-001','Nguyễn Văn An','0911111111','an@gmail.com',850,'diamond',8500000,45),
  ('cu-002','Trần Thị Bích','0922222222','bich@gmail.com',420,'gold',4200000,28),
  ('cu-003','Lê Minh Cường','0933333333','cuong@gmail.com',180,'silver',1800000,15),
  ('cu-004','Phạm Thu Dung','0944444444','dung@gmail.com',60,'bronze',600000,5),
  ('cu-005','Khách lẻ','0955555555','',0,'bronze',0,0)
on conflict (id) do nothing;

-- ===== vouchers =====
insert into public.vouchers (id, code, name, discount_type, discount_value, min_order_value, max_discount, start_date, end_date, usage_limit, used_count) values
  ('v-welcome10','WELCOME10','Chào mừng khách mới','percent',10,0,30000, now() - interval '30 days', now() + interval '60 days', 1000, 124),
  ('v-freeship','FREESHIP','Giảm phí giao hàng','amount',15000,50000,0, now() - interval '10 days', now() + interval '30 days', 1000, 45),
  ('v-happyhour','HAPPYHOUR','Giảm 20% khung 14h-16h','percent',20,100000,50000, now() - interval '5 days', now() + interval '90 days', 1000, 67),
  ('v-member50','MEMBER50','Giảm 50.000đ cho thành viên','amount',50000,200000,0, now() - interval '15 days', now() + interval '45 days', 1000, 18),
  ('v-combo20','COMBO20','Giảm 20% combo nước + bánh','percent',20,80000,40000, now() - interval '2 days', now() + interval '14 days', 1000, 8)
on conflict (id) do nothing;
