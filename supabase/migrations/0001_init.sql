-- SmartCafe Supabase schema + seed
-- Chạy một lần trên Supabase SQL editor hoặc `supabase db push`.
-- Demo password: 123456 cho mọi user (seed qua crypt).

-- ===== EXTENSIONS =====
create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- ===== PROFILES (auth.users -> role) =====
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null,
  phone text not null default '',
  role text not null check (role in ('admin','cashier','barista','waiter','customer')),
  avatar_url text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ===== CATALOG =====
create table if not exists public.categories (
  id text primary key,
  name text not null,
  description text not null default '',
  icon text not null default '☕',
  active boolean not null default true
);

create table if not exists public.toppings (
  id text primary key,
  name text not null,
  price double precision not null default 0,
  available boolean not null default true
);

create table if not exists public.products (
  id text primary key,
  name text not null,
  description text not null default '',
  image_url text not null default '',
  emoji text not null default '☕',
  category_id text not null references public.categories(id),
  base_price double precision not null default 0,
  price_by_size jsonb not null default '{}',
  available_topping_ids jsonb not null default '[]',
  in_stock boolean not null default true,
  hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tables (
  id text primary key,
  table_name text not null,
  capacity int not null default 2,
  status text not null default 'empty'
    check (status in ('empty','serving','waiting','reserved','needs_clean')),
  current_order_id text,
  qr_code_value text
);

create table if not exists public.customers (
  id text primary key,
  full_name text not null,
  phone text not null,
  email text not null default '',
  points int not null default 0,
  rank text not null default 'bronze'
    check (rank in ('bronze','silver','gold','diamond')),
  total_spent double precision not null default 0,
  total_orders int not null default 0,
  favorite_products jsonb not null default '[]',
  created_at timestamptz not null default now()
);

-- ===== INVENTORY =====
create table if not exists public.ingredients (
  id text primary key,
  name text not null,
  unit text not null,
  current_stock double precision not null default 0,
  min_stock double precision not null default 0,
  cost_per_unit double precision not null default 0,
  supplier text not null default '',
  expired_date timestamptz,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.recipes (
  id text primary key,
  product_id text not null references public.products(id),
  size text not null check (size in ('s','m','l')),
  unique (product_id, size)
);

create table if not exists public.recipe_items (
  id uuid primary key default uuid_generate_v4(),
  recipe_id text not null references public.recipes(id) on delete cascade,
  ingredient_id text not null references public.ingredients(id),
  quantity double precision not null default 0,
  unit text not null default '',
  unique (recipe_id, ingredient_id)
);

create table if not exists public.stock_transactions (
  id text primary key,
  ingredient_id text not null references public.ingredients(id),
  ingredient_name text not null default '',
  type text not null check (type in ('in','out','consumed')),
  quantity double precision not null default 0,
  unit text not null default '',
  note text not null default '',
  created_by text not null default 'system',
  created_at timestamptz not null default now()
);

-- ===== SALES =====
create table if not exists public.vouchers (
  id text primary key,
  code text not null unique,
  name text not null default '',
  discount_type text not null check (discount_type in ('percent','amount')),
  discount_value double precision not null default 0,
  min_order_value double precision not null default 0,
  max_discount double precision not null default 0,
  start_date timestamptz not null,
  end_date timestamptz not null,
  usage_limit int not null default 1000,
  used_count int not null default 0,
  active boolean not null default true
);

create table if not exists public.orders (
  id text primary key,
  order_code text not null,
  table_id text references public.tables(id),
  table_name text,
  customer_id text references public.customers(id),
  customer_name text,
  cashier_id text not null,
  cashier_name text not null,
  order_type text not null check (order_type in ('dine_in','takeaway')),
  subtotal double precision not null default 0,
  discount double precision not null default 0,
  voucher_code text,
  points_used int not null default 0,
  points_discount double precision not null default 0,
  total double precision not null default 0,
  payment_method text check (payment_method in ('cash','transfer','ewallet','qr')),
  payment_status text not null default 'unpaid'
    check (payment_status in ('unpaid','paid','refunded')),
  order_status text not null default 'pending'
    check (order_status in ('pending','confirmed','preparing','ready','served','paid','cancelled')),
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.order_items (
  id text primary key,
  order_id text not null references public.orders(id) on delete cascade,
  product_id text not null,
  item jsonb not null
);

-- ===== NOTIFICATIONS =====
create table if not exists public.notifications (
  id text primary key,
  title text not null default '',
  message text not null default '',
  type text not null default 'info',
  target_role text check (target_role in ('admin','cashier','barista','waiter','customer')),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- ===== ORDER SEQUENCE (server-side code gen) =====
create table if not exists public.order_seq (
  id boolean primary key default true check (id),
  current int not null default 0
);
insert into public.order_seq (current) values (0);

create or replace function public.next_order_seq()
returns int
language sql
security definer
set search_path = public
as $$
  update public.order_seq set current = current + 1 where id = true returning current;
$$;

-- ===== RLS =====
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.toppings enable row level security;
alter table public.products enable row level security;
alter table public.tables enable row level security;
alter table public.customers enable row level security;
alter table public.ingredients enable row level security;
alter table public.recipes enable row level security;
alter table public.recipe_items enable row level security;
alter table public.stock_transactions enable row level security;
alter table public.vouchers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.notifications enable row level security;
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin' and p.active);
$$;


-- catalog + staff data: authenticated staff read; anonymous read for customer catalog
drop policy if exists "staff read all" on public.profiles;
create policy "staff read all" on public.profiles for select to authenticated using (true);
drop policy if exists "staff read all" on public.categories;
create policy "staff read all" on public.categories for select to authenticated using (true);
drop policy if exists "staff read all" on public.toppings;
create policy "staff read all" on public.toppings for select to authenticated using (true);
drop policy if exists "staff read all" on public.products;
create policy "staff read all" on public.products for select to authenticated using (true);
drop policy if exists "staff read all" on public.tables;
create policy "staff read all" on public.tables for select to authenticated using (true);
drop policy if exists "staff read all" on public.customers;
create policy "staff read all" on public.customers for select to authenticated using (true);
drop policy if exists "staff read all" on public.ingredients;
create policy "staff read all" on public.ingredients for select to authenticated using (true);
drop policy if exists "staff read all" on public.recipes;
create policy "staff read all" on public.recipes for select to authenticated using (true);
drop policy if exists "staff read all" on public.recipe_items;
create policy "staff read all" on public.recipe_items for select to authenticated using (true);
drop policy if exists "staff read all" on public.stock_transactions;
create policy "staff read all" on public.stock_transactions for select to authenticated using (true);
drop policy if exists "staff read all" on public.vouchers;
create policy "staff read all" on public.vouchers for select to authenticated using (true);
drop policy if exists "staff read all" on public.orders;
create policy "staff read all" on public.orders for select to authenticated using (true);
drop policy if exists "staff read all" on public.order_items;
create policy "staff read all" on public.order_items for select to authenticated using (true);
drop policy if exists "staff read all" on public.notifications;
create policy "staff read all" on public.notifications for select to authenticated using (true);

drop policy if exists "admin write categories" on public.categories;
create policy "admin write categories" on public.categories for insert to authenticated with check (is_admin());
drop policy if exists "admin write categories" on public.categories;
create policy "admin write categories" on public.categories for update to authenticated using (is_admin()) with check (is_admin());
drop policy if exists "admin write categories" on public.categories;
create policy "admin write categories" on public.categories for delete to authenticated using (is_admin());
drop policy if exists "admin write toppings" on public.toppings;
create policy "admin write toppings" on public.toppings for insert to authenticated with check (is_admin());
drop policy if exists "admin write toppings" on public.toppings;
create policy "admin write toppings" on public.toppings for update to authenticated using (is_admin()) with check (is_admin());
drop policy if exists "admin write toppings" on public.toppings;
create policy "admin write toppings" on public.toppings for delete to authenticated using (is_admin());
drop policy if exists "admin write products" on public.products;
create policy "admin write products" on public.products for insert to authenticated with check (is_admin());
drop policy if exists "admin write products" on public.products;
create policy "admin write products" on public.products for update to authenticated using (is_admin()) with check (is_admin());
drop policy if exists "admin write products" on public.products;
create policy "admin write products" on public.products for delete to authenticated using (is_admin());
drop policy if exists "admin write ingredients" on public.ingredients;
create policy "admin write ingredients" on public.ingredients for insert to authenticated with check (is_admin());
drop policy if exists "admin write ingredients" on public.ingredients;
create policy "admin write ingredients" on public.ingredients for update to authenticated using (is_admin()) with check (is_admin());
drop policy if exists "admin write ingredients" on public.ingredients;
create policy "admin write ingredients" on public.ingredients for delete to authenticated using (is_admin());
drop policy if exists "admin write recipes" on public.recipes;
create policy "admin write recipes" on public.recipes for insert to authenticated with check (is_admin());
drop policy if exists "admin write recipes" on public.recipes;
create policy "admin write recipes" on public.recipes for update to authenticated using (is_admin()) with check (is_admin());
drop policy if exists "admin write recipes" on public.recipes;
create policy "admin write recipes" on public.recipes for delete to authenticated using (is_admin());
drop policy if exists "admin write recipe_items" on public.recipe_items;
create policy "admin write recipe_items" on public.recipe_items for insert to authenticated with check (is_admin());
drop policy if exists "admin write recipe_items" on public.recipe_items;
create policy "admin write recipe_items" on public.recipe_items for update to authenticated using (is_admin()) with check (is_admin());
drop policy if exists "admin write recipe_items" on public.recipe_items;
create policy "admin write recipe_items" on public.recipe_items for delete to authenticated using (is_admin());
drop policy if exists "admin write vouchers" on public.vouchers;
create policy "admin write vouchers" on public.vouchers for insert to authenticated with check (is_admin());
drop policy if exists "admin write vouchers" on public.vouchers;
create policy "admin write vouchers" on public.vouchers for update to authenticated using (is_admin()) with check (is_admin());
drop policy if exists "admin write vouchers" on public.vouchers;
create policy "admin write vouchers" on public.vouchers for delete to authenticated using (is_admin());
drop policy if exists "staff write tables" on public.tables;
create policy "staff write tables" on public.tables for insert to authenticated with check (true);
drop policy if exists "staff write tables" on public.tables;
create policy "staff write tables" on public.tables for update to authenticated using (true) with check (true);
drop policy if exists "staff write customers" on public.customers;
create policy "staff write customers" on public.customers for insert to authenticated with check (true);
drop policy if exists "staff write customers" on public.customers;
create policy "staff write customers" on public.customers for update to authenticated using (true) with check (true);
drop policy if exists "staff write orders" on public.orders;
create policy "staff write orders" on public.orders for insert to authenticated with check (true);
drop policy if exists "staff write orders" on public.orders;
create policy "staff write orders" on public.orders for update to authenticated using (true) with check (true);
drop policy if exists "staff write order_items" on public.order_items;
create policy "staff write order_items" on public.order_items for insert to authenticated with check (true);
drop policy if exists "staff write notifications" on public.notifications;
create policy "staff write notifications" on public.notifications for insert to authenticated with check (true);

-- ===== SEED DATA =====

-- Demo users: password 123456 cho tất cả (demo)
insert into auth.users (id, email, encrypted_password, email_confirmed_at, created_at)
values
  ('00000000-0000-0000-0000-000000000001', 'admin@smartcafe.com',
   crypt('123456', gen_salt('bf')), now(), now()),
  ('00000000-0000-0000-0000-000000000002', 'cashier@smartcafe.com',
   crypt('123456', gen_salt('bf')), now(), now()),
  ('00000000-0000-0000-0000-000000000003', 'barista@smartcafe.com',
   crypt('123456', gen_salt('bf')), now(), now()),
  ('00000000-0000-0000-0000-000000000004', 'waiter@smartcafe.com',
   crypt('123456', gen_salt('bf')), now(), now()),
  ('00000000-0000-0000-0000-000000000005', 'customer@smartcafe.com',
   crypt('123456', gen_salt('bf')), now(), now())
on conflict (id) do nothing;

insert into public.profiles (id, full_name, email, phone, role, avatar_url, active, created_at) values
  ('00000000-0000-0000-0000-000000000001', 'Nguyễn Hữu Thanh', 'admin@smartcafe.com', '0901234567', 'admin', null, true, now()),
  ('00000000-0000-0000-0000-000000000002', 'Trần Thị Thu Ngân', 'cashier@smartcafe.com', '0902345678', 'cashier', null, true, now()),
  ('00000000-0000-0000-0000-000000000003', 'Lê Pha Chế', 'barista@smartcafe.com', '0903456789', 'barista', null, true, now()),
  ('00000000-0000-0000-0000-000000000004', 'Phạm Phục Vụ', 'waiter@smartcafe.com', '0904567890', 'waiter', null, true, now()),
  ('00000000-0000-0000-0000-000000000005', 'Khách Vãng Lai', 'customer@smartcafe.com', '0905678901', 'customer', null, true, now());

-- Categories
insert into public.categories (id, name, description, icon) values
  ('cat-cafe', 'Cafe', '', '☕'),
  ('cat-tea-milk', 'Trà sữa', '', '🧋'),
  ('cat-tea-fruit', 'Trà trái cây', '', '🍑'),
  ('cat-ice-blend', 'Đá xay', '', '🧊'),
  ('cat-soda', 'Soda', '', '🥤'),
  ('cat-cake', 'Bánh ngọt', '', '🍰');

-- Toppings
insert into public.toppings (id, name, price, available) values
  ('tp-tran-chau', 'Trân châu', 5000, true),
  ('tp-thach-cafe', 'Thạch cafe', 5000, true),
  ('tp-pudding', 'Pudding', 5000, true),
  ('tp-kem-cheese', 'Kem cheese', 8000, true),
  ('tp-coffee-jelly', 'Coffee jelly', 5000, true);

-- Ingredients
insert into public.ingredients (id, name, unit, current_stock, min_stock, cost_per_unit) values
  ('ing-cafe-bot', 'Cafe bột', 'g', 2000, 200, 200),
  ('ing-sua-dac', 'Sữa đặc', 'ml', 3000, 500, 150),
  ('ing-sua-tuoi', 'Sữa tươi', 'ml', 3000, 500, 120),
  ('ing-tra-den', 'Trà đen', 'g', 2000, 300, 80),
  ('ing-tra-xanh', 'Trà xanh', 'g', 2000, 300, 80),
  ('ing-duong', 'Đường', 'g', 5000, 500, 30),
  ('ing-syrup-dao', 'Syrup đào', 'ml', 1500, 200, 90),
  ('ing-syrup-vai', 'Syrup vải', 'ml', 1500, 200, 90),
  ('ing-tran-chau', 'Trân châu', 'g', 2000, 200, 60),
  ('ing-kem-cheese', 'Kem cheese', 'ml', 1000, 100, 300),
  ('ing-ly-m', 'Ly M', 'cái', 500, 50, 1000),
  ('ing-ly-l', 'Ly L', 'cái', 500, 50, 1200),
  ('ing-ong-hut', 'Ống hút', 'cái', 800, 100, 200),
  ('ing-nap-ly', 'Nắp ly', 'cái', 800, 100, 300);

-- Tables
insert into public.tables (id, table_name, capacity, status) values
  ('tb-01', 'Bàn 01', 2, 'empty'), ('tb-02', 'Bàn 02', 2, 'empty'),
  ('tb-03', 'Bàn 03', 4, 'empty'), ('tb-04', 'Bàn 04', 4, 'empty'),
  ('tb-05', 'Bàn 05', 6, 'empty'), ('tb-06', 'Bàn 06', 2, 'empty'),
  ('tb-07', 'Bàn 07', 2, 'empty'), ('tb-08', 'Bàn 08', 4, 'empty'),
  ('tb-09', 'Bàn 09', 4, 'empty'), ('tb-10', 'Bàn 10', 6, 'empty');

-- Vouchers
insert into public.vouchers (id, code, name, discount_type, discount_value, min_order_value, max_discount, start_date, end_date, usage_limit) values
  ('v-km10', 'KM10', 'Giảm 10%', 'percent', 10, 50000, 30000, now() - interval '7 days', now() + interval '23 days', 200),
  ('v-g30', 'G30', 'Giảm 30k', 'amount', 30000, 100000, 0, now() - interval '7 days', now() + interval '53 days', 150),
  ('v-hs', 'HELLOSUMMER', 'Chào hè', 'percent', 20, 100000, 50000, now() - interval '7 days', now() + interval '83 days', 100);

-- Products (subset đủ demo; đủ data seed trong app)
insert into public.products (id, name, emoji, category_id, base_price, price_by_size, available_topping_ids) values
  ('p-caphe-den', 'Cafe đen', '☕', 'cat-cafe', 25000, '{"s":25000,"m":30000,"l":35000}', '["tp-coffee-jelly","tp-pudding"]'),
  ('p-caphe-sua', 'Cafe sữa', '🥛', 'cat-cafe', 30000, '{"s":30000,"m":35000,"l":40000}', '["tp-coffee-jelly","tp-pudding"]'),
  ('p-bac-xiu', 'Bạc xỉu', '🤎', 'cat-cafe', 28000, '{"s":28000,"m":33000,"l":38000}', '["tp-coffee-jelly","tp-pudding"]');

-- Recipes
insert into public.recipes (id, product_id, size) values
  ('r-caphe-den-m', 'p-caphe-den', 'm'),
  ('r-caphe-den-l', 'p-caphe-den', 'l'),
  ('r-caphe-sua-m', 'p-caphe-sua', 'm');

insert into public.recipe_items (recipe_id, ingredient_id, quantity, unit) values
  ('r-caphe-den-m', 'ing-cafe-bot', 20, 'g'),
  ('r-caphe-den-m', 'ing-duong', 10, 'g'),
  ('r-caphe-den-m', 'ing-ly-m', 1, 'cái'),
  ('r-caphe-den-m', 'ing-ong-hut', 1, 'cái'),
  ('r-caphe-den-m', 'ing-nap-ly', 1, 'cái'),
  ('r-caphe-den-l', 'ing-cafe-bot', 30, 'g'),
  ('r-caphe-den-l', 'ing-duong', 12, 'g'),
  ('r-caphe-den-l', 'ing-ly-l', 1, 'cái'),
  ('r-caphe-den-l', 'ing-ong-hut', 1, 'cái'),
  ('r-caphe-den-l', 'ing-nap-ly', 1, 'cái'),
  ('r-caphe-sua-m', 'ing-cafe-bot', 20, 'g'),
  ('r-caphe-sua-m', 'ing-sua-dac', 40, 'ml'),
  ('r-caphe-sua-m', 'ing-ly-m', 1, 'cái'),
  ('r-caphe-sua-m', 'ing-ong-hut', 1, 'cái'),
  ('r-caphe-sua-m', 'ing-nap-ly', 1, 'cái');

-- Customers (demo)
insert into public.customers (id, full_name, phone, email, points, rank, total_spent, total_orders) values
  ('c-khach-01', 'Nguyễn Văn An', '0912345678', 'an@mail.com', 850, 'gold', 8500000, 42),
  ('c-khach-02', 'Trần Thị Bích', '0912345679', 'bich@mail.com', 420, 'silver', 4200000, 20),
  ('c-khach-03', 'Lê Hoàng Cường', '0912345680', 'cuong@mail.com', 180, 'bronze', 1800000, 9),
  ('c-khach-04', 'Phạm Minh Dung', '0912345681', 'dung@mail.com', 60, 'bronze', 600000, 3);

-- ===== RPC v2 — compound ops (mirror Dart methods, re-check guards) =====

create or replace function public.create_order_v2(
  p_id text, p_order_code text, p_table_id text, p_table_name text,
  p_customer_id text, p_customer_name text, p_cashier_id text, p_cashier_name text,
  p_order_type text, p_items jsonb, p_subtotal double precision, p_discount double precision,
  p_voucher_code text, p_points_used int, p_points_discount double precision,
  p_total double precision, p_note text
) returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.orders (id, order_code, table_id, table_name, customer_id, customer_name,
    cashier_id, cashier_name, order_type, subtotal, discount, voucher_code, points_used,
    points_discount, total, note)
  values (p_id, p_order_code, p_table_id, p_table_name, p_customer_id, p_customer_name,
    p_cashier_id, p_cashier_name, p_order_type, p_subtotal, p_discount, p_voucher_code,
    p_points_used, p_points_discount, p_total, p_note)
  on conflict (id) do nothing;

  -- items
  insert into public.order_items (id, order_id, product_id, item)
  select (e->>'id'), p_id, (e->>'productId'), e
  from jsonb_array_elements(p_items) e
  on conflict (id) do nothing;

  -- table status
  if p_table_id is not null then
    update public.tables set status = 'serving', current_order_id = p_id
    where id = p_table_id;
  end if;

  -- voucher usage
  if p_voucher_code is not null then
    update public.vouchers set used_count = used_count + 1 where code = p_voucher_code;
  end if;

  return p_id;
end;
$$;

create or replace function public.pay_order_v2(
  p_order_id text, p_method text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.orders%rowtype;
begin
  select * into o from public.orders where id = p_order_id;
  if not found then return; end if;
  if o.payment_status = 'paid' then return; end if; -- chống double-pay

  update public.orders
    set payment_status = 'paid', payment_method = p_method,
        order_status = case when order_status = 'pending' then 'confirmed' else order_status end,
        completed_at = coalesce(completed_at, now()), updated_at = now()
  where id = p_order_id;

  if o.table_id is not null then
    update public.tables set status = 'needs_clean', current_order_id = null
    where id = o.table_id;
  end if;

  if o.customer_id is not null then
    update public.customers
      set points = points + floor(o.total / 10000) - least(o.points_used, points),
          total_spent = total_spent + o.total,
          total_orders = total_orders + 1,
          rank = case
            when points + floor(o.total / 10000) - least(o.points_used, points) >= 700 then 'diamond'
            when points + floor(o.total / 10000) - least(o.points_used, points) >= 300 then 'gold'
            when points + floor(o.total / 10000) - least(o.points_used, points) >= 100 then 'silver'
            else 'bronze' end
      where id = o.customer_id;
  end if;
end;
$$;

create or replace function public.consume_recipe_v2(
  p_order_id text, p_order_code text, p_cashier_name text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  ri record;
  ing public.ingredients%rowtype;
  used_qty double precision;
begin
  -- lặp từng item -> recipe theo size -> recipe_items -> trừ kho
  for r in select (it.item->>'productId') as product_id,
                  (it.item->>'size') as size,
                  (it.item->>'quantity')::numeric as qty
           from public.order_items it
           where it.order_id = p_order_id
  loop
    for ri in
      select ri.ingredient_id, ri.quantity, ri.unit
      from public.recipe_items ri
      join public.recipes rr on rr.id = ri.recipe_id
      where rr.product_id = r.product_id and rr.size = r.size
    loop
      used_qty := ri.quantity * r.qty;
      update public.ingredients
        set current_stock = greatest(current_stock - used_qty, 0),
            updated_at = now()
        where id = ri.ingredient_id;
      select * into ing from public.ingredients where id = ri.ingredient_id;
      if found then
        insert into public.stock_transactions
          (id, ingredient_id, ingredient_name, type, quantity, unit, note, created_by)
        values (uuid_generate_v4()::text, ri.ingredient_id, ing.name, 'consumed',
                used_qty, ri.unit, 'Đơn ' || p_order_code, p_cashier_name);
      end if;
    end loop;
  end loop;
end;
$$;

create or replace function public.cancel_order_v2(
  p_order_id text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.orders%rowtype;
begin
  select * into o from public.orders where id = p_order_id;
  if not found then return; end if;
  if o.order_status = 'cancelled' then return; end if; -- chống cancel 2 lần

  update public.orders set order_status = 'cancelled', updated_at = now()
  where id = p_order_id;

  if o.table_id is not null then
    update public.tables set status = 'empty', current_order_id = null
    where id = o.table_id;
  end if;

  -- hoàn kho: cộng lại consumed cho order này
  update public.ingredients i
    set current_stock = i.current_stock + st.quantity, updated_at = now()
  from public.stock_transactions st
  where st.ingredient_id = i.id
    and st.type = 'consumed' and st.note like '%' || o.order_code || '%';

  -- ghi tx hoàn kho (inbound)
  insert into public.stock_transactions (id, ingredient_id, ingredient_name, type, quantity, unit, note, created_by)
  select uuid_generate_v4()::text, st.ingredient_id, st.ingredient_name, 'inbound',
         st.quantity, st.unit, 'Hoàn kho khi hủy ' || o.order_code, 'system'
  from public.stock_transactions st
  where st.type = 'consumed' and st.note like '%' || o.order_code || '%';

  -- hoàn voucher
  if o.voucher_code is not null then
    update public.vouchers set used_count = greatest(used_count - 1, 0)
    where code = o.voucher_code;
  end if;
end;
$$;

create or replace function public.stock_in_v2(
  p_id text, p_ingredient_id text, p_qty double precision, p_note text, p_created_by text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.ingredients
    set current_stock = current_stock + p_qty, updated_at = now()
  where id = p_ingredient_id;
  insert into public.stock_transactions (id, ingredient_id, ingredient_name, type, quantity, unit, note, created_by)
  select p_id, p_ingredient_id, name, 'inbound', p_qty, unit, p_note, p_created_by
  from public.ingredients where id = p_ingredient_id;
end;
$$;

create or replace function public.stock_out_v2(
  p_id text, p_ingredient_id text, p_qty double precision, p_note text, p_created_by text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.ingredients
    set current_stock = greatest(current_stock - p_qty, 0), updated_at = now()
  where id = p_ingredient_id;
  insert into public.stock_transactions (id, ingredient_id, ingredient_name, type, quantity, unit, note, created_by)
  select p_id, p_ingredient_id, name, 'outbound', p_qty, unit, p_note, p_created_by
  from public.ingredients where id = p_ingredient_id;
end;
$$;

create or replace function public.save_recipe_v2(
  p_id text, p_product_id text, p_size text, p_items jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.recipes (id, product_id, size)
  values (p_id, p_product_id, p_size)
  on conflict (id) do update set product_id = excluded.product_id, size = excluded.size;

  delete from public.recipe_items where recipe_id = p_id;
  insert into public.recipe_items (recipe_id, ingredient_id, quantity, unit)
  select p_id, (e->>'ingredientId'), (e->>'quantity')::double precision, (e->>'unit')
  from jsonb_array_elements(p_items) e;
end;
$$;

create or replace function public.merge_tables_v2(
  p_merged_id text, p_order_code text, p_from_id text, p_to_id text, p_note text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  f public.tables%rowtype;
  t public.tables%rowtype;
  fo public.orders%rowtype;
  to_o public.orders%rowtype;
  merged_items jsonb;
begin
  select * into f from public.tables where id = p_from_id;
  select * into t from public.tables where id = p_to_id;
  if not found then return; end if;
  select * into fo from public.orders where id = f.current_order_id and f.current_order_id is not null;
  select * into to_o from public.orders where id = t.current_order_id and t.current_order_id is not null;
  if fo.id is null or to_o.id is null then return; end if;

  -- gộp items: to-order trước, from-order sau
  select jsonb_agg(i) into merged_items from (
    select item from public.order_items where order_id = to_o.id
    union all
    select item from public.order_items where order_id = fo.id
  ) i;

  insert into public.orders (id, order_code, table_id, table_name, customer_id, customer_name,
    cashier_id, cashier_name, order_type, subtotal, discount, points_used, points_discount,
    voucher_code, total, note, created_at, updated_at)
  values (p_merged_id, p_order_code, t.id, t.table_name, to_o.customer_id, to_o.customer_name,
    to_o.cashier_id, to_o.cashier_name, to_o.order_type,
    to_o.subtotal + fo.subtotal,
    to_o.discount + fo.discount,
    to_o.points_used + fo.points_used,
    to_o.points_discount + fo.points_discount,
    to_o.voucher_code,
    greatest(to_o.subtotal + fo.subtotal - to_o.discount - fo.discount
              - to_o.points_discount - fo.points_discount, 0),
    p_note, now(), now())
  on conflict (id) do nothing;

  -- items merge
  insert into public.order_items (id, order_id, product_id, item)
  select (i->>'id'), p_merged_id, (i->>'productId'), i
  from jsonb_array_elements(merged_items) i
  on conflict (id) do nothing;

  -- cancel 2 đơn gốc, bàn nguồn trống, bàn đích serving
  update public.orders set order_status = 'cancelled', updated_at = now() where id in (fo.id, to_o.id);
  update public.tables set status = 'empty', current_order_id = null where id = f.id;
  update public.tables set status = 'serving', current_order_id = p_merged_id where id = t.id;
end;
$$;
