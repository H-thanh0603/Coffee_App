-- 0002 — Security hardening
-- Chạy sau 0001_init.sql. Chạy lại an toàn (idempotent).
--
-- Nội dung:
-- 1) REVOKE/GRANT + role guard cho 8 RPC compound ops
-- 2) Chặn tin tổng tiền từ client: create_order_v2 tự tính subtotal/discount/points/total
-- 3) Sinh order_code phía server (next_order_seq), RPC kho idempotent
-- 4) RLS tách customer vs staff, khóa points/total_spent/total_orders/rank
-- 5) Xoay mật khẩu demo (123456 -> smartcafe2026)
-- 6) Fix check constraint stock_transactions.type (RPC chèn 'inbound'/'outbound')

create extension if not exists "pgcrypto" with schema extensions;

-- ===== HELPERS =====
create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.active and p.role <> 'customer'
  );
$$;

create or replace function public.has_role(roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.active and p.role = any (roles)
  );
$$;

-- Khách hàng có được thao tác trên customer row này không (map qua email profiles)
create or replace function public.owns_customer(p_customer_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.customers c
    join public.profiles p on p.email = c.email and p.id = auth.uid()
    where c.id = p_customer_id
  );
$$;

create or replace function public.owns_order(p_order_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.orders o
    where o.id = p_order_id and public.owns_customer(o.customer_id)
  );
$$;

-- Cho phép self-update profile nhưng cấm tự đổi role (so với role đang lưu)
create or replace function public.self_profile_ok(p_new_role text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = p_new_role
  );
$$;

-- Predicate functions dùng trong RLS policy -> authenticated phải gọi được
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.has_role(text[]) to authenticated;
grant execute on function public.owns_customer(text) to authenticated;
grant execute on function public.owns_order(text) to authenticated;
grant execute on function public.self_profile_ok(text) to authenticated;

-- next_order_seq chỉ gọi nội bộ trong RPC security definer, không cho gọi trực tiếp
revoke execute on function public.next_order_seq() from public, anon, authenticated;

-- ===== FIX CHECK CONSTRAINT stock_transactions.type =====
-- 0001 chỉ cho ('in','out','consumed') nhưng RPC chèn 'inbound'/'outbound'
alter table public.stock_transactions
  drop constraint if exists stock_transactions_type_check;
alter table public.stock_transactions
  add constraint stock_transactions_type_check
  check (type in ('in','out','consumed','inbound','outbound'));

-- ===== RPC v3 — role guard + server-side money + idempotent =====

-- create_order_v2: KHÔNG tin p_order_code / p_total / p_discount / p_points_discount.
-- Server tự: tính subtotal từ items, re-check voucher, clamp điểm, sinh order_code.
drop function if exists public.create_order_v2(
  text, text, text, text, text, text, text, text, text, jsonb,
  double precision, double precision, text, int, double precision, double precision, text
);
create function public.create_order_v2(
  p_id text, p_order_code text, p_table_id text, p_table_name text,
  p_customer_id text, p_customer_name text, p_cashier_id text, p_cashier_name text,
  p_order_type text, p_items jsonb, p_subtotal double precision, p_discount double precision,
  p_voucher_code text, p_points_used int, p_points_discount double precision,
  p_total double precision, p_note text
) returns text  -- trả về order_code do server sinh
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subtotal double precision := 0;
  v_discount double precision := 0;
  v_points_used int := greatest(coalesce(p_points_used, 0), 0);
  v_points_discount double precision := 0;
  v_total double precision;
  v_code text;
  v_seq int;
  v_inserted text;
begin
  if not public.has_role(array['admin','cashier','barista','waiter','customer']) then
    raise exception 'create_order_v2: permission denied';
  end if;

  -- 1) subtotal tính lại 100% từ items (unitPrice * qty + toppingsPrice * qty)
  select coalesce(sum(
      coalesce((e->>'unitPrice')::double precision, 0)
        * greatest(coalesce((e->>'quantity')::double precision, 1), 0)
      + coalesce((e->>'toppingsPrice')::double precision, 0)
        * greatest(coalesce((e->>'quantity')::double precision, 1), 0)
    ), 0)
  into v_subtotal
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e;

  -- 2) voucher re-check trên server (active, còn hạn, đủ min, còn lượt)
  if p_voucher_code is not null then
    select least(
             case v.discount_type
               when 'percent' then v_subtotal * v.discount_value / 100.0
               else v.discount_value end,
             case when v.max_discount > 0 then v.max_discount else v_subtotal end
           )
    into v_discount
    from public.vouchers v
    where v.code = p_voucher_code
      and v.active
      and now() between v.start_date and v.end_date
      and v_subtotal >= v.min_order_value
      and v.used_count < v.usage_limit;
    if not found then
      p_voucher_code := null;  -- voucher không hợp lệ -> bỏ qua thay vì từ chối đơn
    end if;
  end if;

  -- 3) điểm quy đổi 1đ/điểm x100 (100 điểm = 10.000đ), clamp theo điểm đang có
  if p_customer_id is not null then
    select least(v_points_used, c.points) into v_points_used
    from public.customers c where c.id = p_customer_id;
    if not found then v_points_used := 0; end if;
  else
    v_points_used := 0;  -- khách vãng lai không dùng được điểm
  end if;
  v_points_discount := (floor(v_points_used / 100.0) * 10000)::double precision;

  v_total := greatest(v_subtotal - v_discount - v_points_discount, 0);

  -- 4) order_code sinh phía server từ order_seq
  select public.next_order_seq() into v_seq;
  v_code := 'OD' || to_char(now(), 'YYYY') || lpad(v_seq::text, 5, '0');

  insert into public.orders (id, order_code, table_id, table_name, customer_id, customer_name,
      cashier_id, cashier_name, order_type, subtotal, discount, voucher_code, points_used,
      points_discount, total, note)
  values (p_id, v_code, p_table_id, p_table_name, p_customer_id, p_customer_name,
      p_cashier_id, p_cashier_name, p_order_type, v_subtotal, v_discount, p_voucher_code,
      v_points_used, v_points_discount, v_total, p_note)
  on conflict (id) do nothing
  returning id into v_inserted;

  -- replay (đơn đã tồn tại): trả về code hiện có, KHÔNG đếm voucher/bàn lần nữa
  if v_inserted is null then
    select order_code into v_code from public.orders where id = p_id;
    return v_code;
  end if;

  insert into public.order_items (id, order_id, product_id, item)
  select (e->>'id'), p_id, (e->>'productId'), e
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
  on conflict (id) do nothing;

  if p_table_id is not null then
    update public.tables set status = 'serving', current_order_id = p_id
    where id = p_table_id;
  end if;

  if p_voucher_code is not null then
    update public.vouchers set used_count = used_count + 1 where code = p_voucher_code;
  end if;

  return v_code;
end;
$$;

drop function if exists public.pay_order_v2(text, text);
create function public.pay_order_v2(p_order_id text, p_method text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.orders%rowtype;
begin
  if not public.is_staff() then
    raise exception 'pay_order_v2: permission denied';
  end if;

  select * into o from public.orders where id = p_order_id;
  if not found then return; end if;
  if o.payment_status = 'paid' then return; end if;  -- chống double-pay (idempotent)
  if o.order_status = 'cancelled' then return; end if;  -- đơn hủy không thu tiền

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

drop function if exists public.consume_recipe_v2(text, text, text);
create function public.consume_recipe_v2(
  p_order_id text, p_order_code text, p_cashier_name text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  ord record;
  rit record;
  ing public.ingredients%rowtype;
  used_qty double precision;
begin
  if not public.has_role(array['admin','cashier','barista']) then
    raise exception 'consume_recipe_v2: permission denied';
  end if;

  -- idempotent: đơn đã trừ kho thì bỏ qua
  if exists (
    select 1 from public.stock_transactions
    where type = 'consumed' and note = 'Đơn ' || p_order_code
  ) then
    return;
  end if;

  -- LƯU Ý: biến loop phải khác tên alias bảng trong SQL (plpgsql substitute
  -- biến vào query — trùng tên sẽ lỗi "record not assigned yet")
  for ord in select (it.item->>'productId') as product_id,
                  (it.item->>'size') as size,
                  (it.item->>'quantity')::numeric as qty
           from public.order_items it
           where it.order_id = p_order_id
  loop
    for rit in
      select rti.ingredient_id, rti.quantity, rti.unit
      from public.recipe_items rti
      join public.recipes rr on rr.id = rti.recipe_id
      where rr.product_id = ord.product_id and rr.size = ord.size
    loop
      used_qty := rit.quantity * ord.qty;
      update public.ingredients
        set current_stock = greatest(current_stock - used_qty, 0),
            updated_at = now()
        where id = rit.ingredient_id;
      select * into ing from public.ingredients where id = rit.ingredient_id;
      if found then
        insert into public.stock_transactions
          (id, ingredient_id, ingredient_name, type, quantity, unit, note, created_by)
        values (gen_random_uuid()::text, rit.ingredient_id, ing.name, 'consumed',
                used_qty, rit.unit, 'Đơn ' || p_order_code, p_cashier_name);
      end if;
    end loop;
  end loop;
end;
$$;

drop function if exists public.cancel_order_v2(text);
create function public.cancel_order_v2(p_order_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.orders%rowtype;
begin
  if not public.is_staff() then
    raise exception 'cancel_order_v2: permission denied';
  end if;

  select * into o from public.orders where id = p_order_id;
  if not found then return; end if;
  if o.order_status = 'cancelled' then return; end if;  -- idempotent

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
    and st.type = 'consumed' and st.note = 'Đơn ' || o.order_code;

  insert into public.stock_transactions (id, ingredient_id, ingredient_name, type, quantity, unit, note, created_by)
  select gen_random_uuid()::text, st.ingredient_id, st.ingredient_name, 'inbound',
         st.quantity, st.unit, 'Hoàn kho khi hủy ' || o.order_code, 'system'
  from public.stock_transactions st
  where st.type = 'consumed' and st.note = 'Đơn ' || o.order_code;

  if o.voucher_code is not null then
    update public.vouchers set used_count = greatest(used_count - 1, 0)
    where code = o.voucher_code;
  end if;
end;
$$;

-- stock_in/out: guard + idempotent theo tx id (replay chỉ áp kho đúng 1 lần)
drop function if exists public.stock_in_v2(text, text, double precision, text, text);
create function public.stock_in_v2(
  p_id text, p_ingredient_id text, p_qty double precision, p_note text, p_created_by text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted text;
begin
  if not public.has_role(array['admin','cashier']) then
    raise exception 'stock_in_v2: permission denied';
  end if;

  insert into public.stock_transactions (id, ingredient_id, ingredient_name, type, quantity, unit, note, created_by)
  select p_id, p_ingredient_id, name, 'inbound', p_qty, unit, p_note, p_created_by
  from public.ingredients where id = p_ingredient_id
  on conflict (id) do nothing
  returning id into v_inserted;

  if v_inserted is null then return; end if;  -- tx đã tồn tại -> bỏ qua

  update public.ingredients
    set current_stock = current_stock + p_qty, updated_at = now()
  where id = p_ingredient_id;
end;
$$;

drop function if exists public.stock_out_v2(text, text, double precision, text, text);
create function public.stock_out_v2(
  p_id text, p_ingredient_id text, p_qty double precision, p_note text, p_created_by text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted text;
begin
  if not public.has_role(array['admin','cashier']) then
    raise exception 'stock_out_v2: permission denied';
  end if;

  insert into public.stock_transactions (id, ingredient_id, ingredient_name, type, quantity, unit, note, created_by)
  select p_id, p_ingredient_id, name, 'outbound', p_qty, unit, p_note, p_created_by
  from public.ingredients where id = p_ingredient_id
  on conflict (id) do nothing
  returning id into v_inserted;

  if v_inserted is null then return; end if;

  update public.ingredients
    set current_stock = greatest(current_stock - p_qty, 0), updated_at = now()
  where id = p_ingredient_id;
end;
$$;

drop function if exists public.save_recipe_v2(text, text, text, jsonb);
create function public.save_recipe_v2(
  p_id text, p_product_id text, p_size text, p_items jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_role(array['admin']) then
    raise exception 'save_recipe_v2: permission denied';
  end if;

  insert into public.recipes (id, product_id, size)
  values (p_id, p_product_id, p_size)
  on conflict (id) do update set product_id = excluded.product_id, size = excluded.size;

  delete from public.recipe_items where recipe_id = p_id;
  insert into public.recipe_items (recipe_id, ingredient_id, quantity, unit)
  select p_id, (e->>'ingredientId'), (e->>'quantity')::double precision, (e->>'unit')
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e;
end;
$$;

-- merge_tables_v2: guard staff + sinh code server + replay-safe
drop function if exists public.merge_tables_v2(text, text, text, text, text);
create function public.merge_tables_v2(
  p_merged_id text, p_order_code text, p_from_id text, p_to_id text, p_note text
) returns text  -- order_code do server sinh
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
  v_code text;
  v_seq int;
begin
  if not public.is_staff() then
    raise exception 'merge_tables_v2: permission denied';
  end if;

  -- replay: merged order đã tồn tại -> trả code, không hủy đơn gốc lần nữa
  select order_code into v_code from public.orders where id = p_merged_id;
  if v_code is not null then return v_code; end if;

  select * into f from public.tables where id = p_from_id;
  select * into t from public.tables where id = p_to_id;
  if not found then return null; end if;
  select * into fo from public.orders where id = f.current_order_id and f.current_order_id is not null;
  select * into to_o from public.orders where id = t.current_order_id and t.current_order_id is not null;
  if fo.id is null or to_o.id is null then return null; end if;

  select jsonb_agg(i) into merged_items from (
    select item from public.order_items where order_id = to_o.id
    union all
    select item from public.order_items where order_id = fo.id
  ) i;

  select public.next_order_seq() into v_seq;
  v_code := 'OD' || to_char(now(), 'YYYY') || lpad(v_seq::text, 5, '0');

  insert into public.orders (id, order_code, table_id, table_name, customer_id, customer_name,
    cashier_id, cashier_name, order_type, subtotal, discount, points_used, points_discount,
    voucher_code, total, note, created_at, updated_at)
  values (p_merged_id, v_code, t.id, t.table_name, to_o.customer_id, to_o.customer_name,
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

  insert into public.order_items (id, order_id, product_id, item)
  select (i->>'id'), p_merged_id, (i->>'productId'), i
  from jsonb_array_elements(coalesce(merged_items, '[]'::jsonb)) i
  on conflict (id) do nothing;

  update public.orders set order_status = 'cancelled', updated_at = now() where id in (fo.id, to_o.id);
  update public.tables set status = 'empty', current_order_id = null where id = f.id;
  update public.tables set status = 'serving', current_order_id = p_merged_id where id = t.id;

  return v_code;
end;
$$;

-- ===== EXECUTE: chỉ authenticated gọi được 8 RPC =====
revoke execute on function public.create_order_v2(text,text,text,text,text,text,text,text,text,jsonb,double precision,double precision,text,int,double precision,double precision,text) from public, anon;
revoke execute on function public.pay_order_v2(text,text) from public, anon;
revoke execute on function public.consume_recipe_v2(text,text,text) from public, anon;
revoke execute on function public.cancel_order_v2(text) from public, anon;
revoke execute on function public.stock_in_v2(text,text,double precision,text,text) from public, anon;
revoke execute on function public.stock_out_v2(text,text,double precision,text,text) from public, anon;
revoke execute on function public.save_recipe_v2(text,text,text,jsonb) from public, anon;
revoke execute on function public.merge_tables_v2(text,text,text,text,text) from public, anon;

grant execute on function public.create_order_v2(text,text,text,text,text,text,text,text,text,jsonb,double precision,double precision,text,int,double precision,double precision,text) to authenticated;
grant execute on function public.pay_order_v2(text,text) to authenticated;
grant execute on function public.consume_recipe_v2(text,text,text) to authenticated;
grant execute on function public.cancel_order_v2(text) to authenticated;
grant execute on function public.stock_in_v2(text,text,double precision,text,text) to authenticated;
grant execute on function public.stock_out_v2(text,text,double precision,text,text) to authenticated;
grant execute on function public.save_recipe_v2(text,text,text,jsonb) to authenticated;
grant execute on function public.merge_tables_v2(text,text,text,text,text) to authenticated;

-- ===== RLS: tách customer vs staff =====

-- order_seq: chỉ đọc/ghi qua security definer -> deny all
alter table public.order_seq enable row level security;

-- profiles: khách chỉ đọc được chính mình; staff đọc hết; admin ghi
drop policy if exists "staff read all" on public.profiles;
drop policy if exists "own or staff read" on public.profiles;
create policy "own or staff read" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_staff());
drop policy if exists "admin write profiles" on public.profiles;
drop policy if exists "admin insert profiles" on public.profiles;
create policy "admin insert profiles" on public.profiles for insert to authenticated with check (public.is_admin());
drop policy if exists "admin update profiles" on public.profiles;
create policy "admin update profiles" on public.profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "admin delete profiles" on public.profiles;
create policy "admin delete profiles" on public.profiles for delete to authenticated using (public.is_admin());

-- User tự cập nhật hồ sơ của mình (đổi tên/ảnh), nhưng không được tự đổi role
drop policy if exists "self update profiles" on public.profiles;
create policy "self update profiles" on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and public.self_profile_ok(role));

-- catalog: authenticated đọc (khách cần duyệt menu)
-- (giữ nguyên policy select "staff read all" của categories/toppings/products/tables/vouchers)
drop policy if exists "staff write tables" on public.tables;
drop policy if exists "staff insert tables" on public.tables;
create policy "staff insert tables" on public.tables for insert to authenticated with check (public.is_staff());
drop policy if exists "staff update tables" on public.tables;
create policy "staff update tables" on public.tables for update to authenticated using (public.is_staff()) with check (public.is_staff());
drop policy if exists "staff delete tables" on public.tables;
create policy "staff delete tables" on public.tables for delete to authenticated using (public.is_staff());

-- customers: khách chỉ đọc đúng hồ sơ của mình (map email), staff đọc hết
drop policy if exists "staff read all" on public.customers;
drop policy if exists "own or staff read customers" on public.customers;
create policy "own or staff read customers" on public.customers for select to authenticated
  using (public.is_staff() or public.owns_customer(id));
drop policy if exists "staff write customers" on public.customers;
drop policy if exists "staff insert customers" on public.customers;
create policy "staff insert customers" on public.customers for insert to authenticated
  with check (public.is_staff());
drop policy if exists "staff update customers" on public.customers;
create policy "staff update customers" on public.customers for update to authenticated
  using (public.is_staff()) with check (public.is_staff());
drop policy if exists "admin delete customers" on public.customers;
create policy "admin delete customers" on public.customers for delete to authenticated
  using (public.is_admin());

-- Khóa cột thống kê khách hàng: chỉ RPC security definer (pay_order_v2) được đụng.
-- LƯU Ý: REVOKE mức cột KHÔNG thu hồi privilege cấp mức bảng -> phải revoke
-- toàn bảng rồi grant lại từng cột được phép.
revoke insert, update on public.customers from authenticated, anon, public;
grant insert (id, full_name, phone, email, favorite_products) on public.customers to authenticated;
grant update (full_name, phone, email, favorite_products) on public.customers to authenticated;

-- orders/order_items: staff full, khách chỉ đọc đơn của mình
drop policy if exists "staff read all" on public.orders;
drop policy if exists "own or staff read orders" on public.orders;
create policy "own or staff read orders" on public.orders for select to authenticated
  using (public.is_staff() or public.owns_customer(customer_id));
drop policy if exists "staff write orders" on public.orders;
drop policy if exists "staff insert orders" on public.orders;
create policy "staff insert orders" on public.orders for insert to authenticated
  with check (public.is_staff());
drop policy if exists "staff update orders" on public.orders;
create policy "staff update orders" on public.orders for update to authenticated
  using (public.is_staff()) with check (public.is_staff());
drop policy if exists "admin delete orders" on public.orders;
create policy "admin delete orders" on public.orders for delete to authenticated
  using (public.is_admin());

drop policy if exists "staff read all" on public.order_items;
drop policy if exists "own or staff read order_items" on public.order_items;
create policy "own or staff read order_items" on public.order_items for select to authenticated
  using (public.is_staff() or public.owns_order(order_id));
drop policy if exists "staff write order_items" on public.order_items;
drop policy if exists "staff insert order_items" on public.order_items;
create policy "staff insert order_items" on public.order_items for insert to authenticated
  with check (public.is_staff());
drop policy if exists "staff update order_items" on public.order_items;
create policy "staff update order_items" on public.order_items for update to authenticated
  using (public.is_staff()) with check (public.is_staff());
drop policy if exists "staff delete order_items" on public.order_items;
create policy "staff delete order_items" on public.order_items for delete to authenticated
  using (public.is_staff());

-- Kho: chỉ staff đọc; ghi đã chặn ở RPC
drop policy if exists "staff read all" on public.ingredients;
drop policy if exists "staff read ingredients" on public.ingredients;
create policy "staff read ingredients" on public.ingredients for select to authenticated
  using (public.is_staff());
drop policy if exists "staff read all" on public.recipes;
drop policy if exists "staff read recipes" on public.recipes;
create policy "staff read recipes" on public.recipes for select to authenticated
  using (public.is_staff());
drop policy if exists "staff read all" on public.recipe_items;
drop policy if exists "staff read recipe_items" on public.recipe_items;
create policy "staff read recipe_items" on public.recipe_items for select to authenticated
  using (public.is_staff());
drop policy if exists "staff read all" on public.stock_transactions;
drop policy if exists "staff read stock_transactions" on public.stock_transactions;
create policy "staff read stock_transactions" on public.stock_transactions for select to authenticated
  using (public.is_staff());

-- notifications: staff đọc hết, khách chỉ đọc thông báo dành cho khách
drop policy if exists "staff read all" on public.notifications;
drop policy if exists "own role read notifications" on public.notifications;
create policy "own role read notifications" on public.notifications for select to authenticated
  using (public.is_staff() or target_role is null or target_role = 'customer');
drop policy if exists "staff write notifications" on public.notifications;
drop policy if exists "staff insert notifications" on public.notifications;
create policy "staff insert notifications" on public.notifications for insert to authenticated
  with check (public.is_staff());
drop policy if exists "staff update notifications" on public.notifications;
create policy "staff update notifications" on public.notifications for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

-- ===== XOAY MẬT KHẨU DEMO =====
-- 123456 -> smartcafe2026 (đồng bộ với kDemoPassword trong app)
update auth.users
set encrypted_password = extensions.crypt('smartcafe2026', extensions.gen_salt('bf'))
where id in (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000005'
);
