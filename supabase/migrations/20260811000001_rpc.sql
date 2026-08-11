-- SmartCafe money/stock RPCs: SECURITY DEFINER, single tx, idempotent.
-- These are the ONLY writers for orders/stock/customer points. Client never writes those tables.

-- ===== order code generator =====
create or replace function public.rpc_next_order_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare v_last int;
begin
  update public.order_seq set last_val = last_val + 1
  where id = 1
  returning last_val into v_last;
  if v_last is null then
    insert into public.order_seq (id, last_val) values (1, 1)
      on conflict (id) do update set last_val = order_seq.last_val + 1
      returning last_val into v_last;
  end if;
  return 'OD' || to_char(now(), 'YYYY') || lpad(v_last::text, 5, '0');
end;
$$;

-- ===== place order =====
create or replace function public.rpc_place_order(
  p_cashier_id uuid,
  p_client_order_id text,
  p_order_type text,
  p_items jsonb,
  p_table_id text,
  p_customer_id text,
  p_voucher_code text,
  p_points_used int,
  p_points_discount numeric,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.orders%rowtype;
  v_table public.cafe_tables%rowtype;
  v_customer public.customers%rowtype;
  v_voucher public.vouchers%rowtype;
  v_code text;
  v_subtotal numeric := 0;
  v_discount numeric := 0;
  v_total numeric := 0;
  v_item jsonb;
  v_cashier public.app_users%rowtype;
begin
  -- idempotency: same client order id -> return existing order
  select * into v_existing from public.orders where id = p_client_order_id;
  if v_existing.id is not null then
    return jsonb_build_object(
      'order_id', v_existing.id,
      'order_code', v_existing.order_code,
      'subtotal', v_existing.subtotal,
      'discount', v_existing.discount,
      'total', v_existing.total
    );
  end if;

  -- cashier must exist (FK enforces; fail fast with clean error)
  select * into v_cashier from public.app_users where id = p_cashier_id;
  if v_cashier.id is null then
    raise exception 'cashier_not_found';
  end if;

  -- lock table row (the "two cashiers same table" arbiter)
  if p_table_id is not null then
    select * into v_table from public.cafe_tables where id = p_table_id for update;
    if v_table.id is null then
      raise exception 'table_not_found';
    end if;
    if v_table.current_order_id is not null then
      perform 1 from public.orders o
        where o.id = v_table.current_order_id and o.payment_status <> 'paid';
      if found then
        raise exception 'table_busy';
      end if;
    end if;
  end if;

  -- lock + validate voucher
  if p_voucher_code is not null then
    select * into v_voucher from public.vouchers
      where code = upper(p_voucher_code) for update;
    if v_voucher.id is null then
      raise exception 'voucher_not_found';
    end if;
    if not (v_voucher.active and v_voucher.used_count < v_voucher.usage_limit
            and now() between v_voucher.start_date and v_voucher.end_date) then
      raise exception 'voucher_unavailable';
    end if;
  end if;

  -- customer
  if p_customer_id is not null then
    select * into v_customer from public.customers where id = p_customer_id;
    if v_customer.id is null then
      raise exception 'customer_not_found';
    end if;
  end if;

  -- recompute subtotal server-side from items
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_subtotal := v_subtotal +
      ((v_item ->> 'unit_price')::numeric + coalesce((v_item ->> 'toppings_price')::numeric, 0)) *
      (v_item ->> 'quantity')::numeric;
  end loop;

  -- recompute discount server-side (mirror Voucher.calcDiscount)
  if v_voucher.id is not null then
    if v_subtotal >= v_voucher.min_order_value then
      if v_voucher.discount_type = 'percent' then
        v_discount := v_subtotal * v_voucher.discount_value / 100;
        if v_voucher.max_discount > 0 and v_discount > v_voucher.max_discount then
          v_discount := v_voucher.max_discount;
        end if;
      else
        v_discount := v_voucher.discount_value;
      end if;
      if v_discount > v_subtotal then
        v_discount := v_subtotal;
      end if;
    end if;
  end if;

  v_total := greatest(v_subtotal - v_discount - coalesce(p_points_discount, 0), 0);

  v_code := public.rpc_next_order_code();

  insert into public.orders (
    id, order_code, table_id, table_name, customer_id, customer_name,
    cashier_id, cashier_name, order_type, subtotal, discount, voucher_code,
    points_used, points_discount, total, note
  ) values (
    p_client_order_id, v_code, v_table.id, v_table.table_name,
    v_customer.id, v_customer.full_name, p_cashier_id, v_cashier.full_name,
    p_order_type, v_subtotal, v_discount, v_voucher.code,
    coalesce(p_points_used, 0), coalesce(p_points_discount, 0), v_total,
    coalesce(p_note, '')
  );

  insert into public.order_items (
    order_id, product_id, product_name, emoji, size, topping_ids, topping_names,
    toppings_price, sugar, ice, quantity, unit_price, note, status
  )
  select
    p_client_order_id,
    (vi ->> 'product_id'),
    (vi ->> 'product_name'),
    coalesce(vi ->> 'emoji', '☕'),
    coalesce(vi ->> 'size', 'm'),
    coalesce(vi->'topping_ids', '[]'::jsonb),
    coalesce(vi->'topping_names', '[]'::jsonb),
    coalesce((vi ->> 'toppings_price')::numeric, 0),
    coalesce(vi ->> 'sugar', 'full'),
    coalesce(vi ->> 'ice', 'normal'),
    (vi ->> 'quantity')::int,
    (vi ->> 'unit_price')::numeric,
    coalesce(vi ->> 'note', ''),
    coalesce(vi ->> 'status', 'pending')
  from jsonb_array_elements(p_items) as vi;

  -- occupy table
  if v_table.id is not null then
    update public.cafe_tables
      set status = 'serving', current_order_id = p_client_order_id, updated_at = now()
      where id = v_table.id;
  end if;

  -- increment voucher usage
  if v_voucher.id is not null then
    update public.vouchers
      set used_count = used_count + 1, updated_at = now()
      where id = v_voucher.id;
  end if;

  insert into public.notifications (id, title, message, type, target_role)
  values (
    gen_random_uuid()::text, 'Đơn mới #' || v_code,
    coalesce(v_table.table_name, 'Mang đi') || ' • ' || jsonb_array_length(p_items)::text || ' món',
    'order_new', 'barista'
  );

  insert into public.audit_log (actor_id, action, order_id, reason)
  values (p_cashier_id::text, 'place_order', p_client_order_id, null);

  return jsonb_build_object(
    'order_id', p_client_order_id,
    'order_code', v_code,
    'subtotal', v_subtotal,
    'discount', v_discount,
    'total', v_total
  );
end;
$$;

-- ===== consume recipe (stock deduction, single per order across devices) =====
create or replace function public.rpc_consume_recipe(p_order_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_item public.order_items%rowtype;
  v_recipe public.recipes%rowtype;
  v_ri public.recipe_items%rowtype;
  v_used numeric;
  v_updated int;
begin
  -- idempotency guard: mark stock_consumed atomically
  update public.orders
    set stock_consumed = true, updated_at = now()
    where id = p_order_id and stock_consumed = false;
  if not found then
    return;
  end if;

  select * into v_order from public.orders where id = p_order_id;
  if v_order.id is null then
    return;
  end if;

  for v_item in
    select * from public.order_items where order_id = p_order_id
  loop
    select * into v_recipe from public.recipes
      where product_id = v_item.product_id and size = v_item.size;
    if v_recipe.id is null then
      continue;
    end if;
    for v_ri in
      select * from public.recipe_items where recipe_id = v_recipe.id
    loop
      v_used := v_ri.quantity * v_item.quantity;
      update public.ingredients
        set current_stock = current_stock - v_used,
            updated_at = now()
        where id = v_ri.ingredient_id and current_stock >= v_used;
      get diagnostics v_updated = row_count;
      if v_updated = 0 then
        raise exception 'insufficient_stock ingredient=%', v_ri.ingredient_id;
      end if;
      insert into public.stock_transactions (
        id, ingredient_id, ingredient_name, type, quantity, unit, note, created_by
      ) values (
        gen_random_uuid()::text, v_ri.ingredient_id,
        (select name from public.ingredients where id = v_ri.ingredient_id),
        'consumed', v_used, v_ri.unit, 'Đơn ' || v_order.order_code,
        v_order.cashier_name
      );
    end loop;
  end loop;

  insert into public.audit_log (actor_id, action, order_id, reason)
  values (v_order.cashier_id::text, 'consume_recipe', p_order_id, null);
end;
$$;

-- ===== pay order (idempotent, first method + completed_at kept) =====
create or replace function public.rpc_pay_order(p_order_id text, p_method text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_earned int;
begin
  update public.orders
    set payment_status = 'paid',
        payment_method = p_method,
        order_status = case when order_status = 'pending' then 'confirmed' else order_status end,
        completed_at = now(),
        updated_at = now()
    where id = p_order_id and payment_status = 'unpaid';
  if not found then
    return; -- already paid -> no-op (double-pay safe)
  end if;

  select * into v_order from public.orders where id = p_order_id;

  if v_order.table_id is not null then
    update public.cafe_tables
      set status = 'needsClean', current_order_id = null, updated_at = now()
      where id = v_order.table_id;
  end if;

  if v_order.customer_id is not null then
    v_earned := floor(v_order.total / 10000);
    update public.customers
      set points = points + v_earned - v_order.points_used,
          total_spent = total_spent + v_order.total,
          total_orders = total_orders + 1,
          updated_at = now()
      where id = v_order.customer_id;
  end if;

  insert into public.audit_log (actor_id, action, order_id, reason)
  values (v_order.cashier_id::text, 'pay_order', p_order_id, p_method);
end;
$$;

-- ===== cancel order (blocked if paid) =====
create or replace function public.rpc_cancel_order(p_order_id text, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if v_order.id is null then
    return;
  end if;
  if v_order.payment_status = 'paid' then
    raise exception 'order_paid';
  end if;

  update public.orders
    set order_status = 'cancelled', updated_at = now()
    where id = p_order_id;

  if v_order.table_id is not null then
    update public.cafe_tables
      set status = 'empty', current_order_id = null, updated_at = now()
      where id = v_order.table_id;
  end if;

  insert into public.audit_log (actor_id, action, order_id, reason)
  values (v_order.cashier_id::text, 'cancel_order', p_order_id, coalesce(p_reason, ''));
end;
$$;

-- ===== move order to another table =====
create or replace function public.rpc_move_order(p_order_id text, p_new_table_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_old_table public.cafe_tables%rowtype;
  v_new_table public.cafe_tables%rowtype;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if v_order.id is null then
    return;
  end if;

  select * into v_old_table from public.cafe_tables where id = v_order.table_id;
  select * into v_new_table from public.cafe_tables where id = p_new_table_id for update;
  if v_new_table.id is null then
    raise exception 'table_not_found';
  end if;
  if v_new_table.current_order_id is not null and v_new_table.current_order_id <> p_order_id then
    raise exception 'table_busy';
  end if;

  update public.orders
    set table_id = v_new_table.id, table_name = v_new_table.table_name, updated_at = now()
    where id = p_order_id;

  if v_old_table.id is not null then
    update public.cafe_tables
      set status = 'empty', current_order_id = null, updated_at = now()
      where id = v_old_table.id;
  end if;

  update public.cafe_tables
    set status = 'serving', current_order_id = p_order_id, updated_at = now()
    where id = v_new_table.id;

  insert into public.audit_log (actor_id, action, order_id, reason)
  values (v_order.cashier_id::text, 'move_order', p_order_id, p_new_table_id);
end;
$$;

-- ===== staff stock adjustment =====
create or replace function public.rpc_adjust_stock(
  p_ingredient_id text,
  p_type text,
  p_quantity numeric,
  p_note text,
  p_actor_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ing public.ingredients%rowtype;
begin
  select * into v_ing from public.ingredients where id = p_ingredient_id for update;
  if v_ing.id is null then
    raise exception 'ingredient_not_found';
  end if;
  if p_quantity <= 0 then
    raise exception 'invalid_quantity';
  end if;

  if p_type = 'in' then
    update public.ingredients
      set current_stock = current_stock + p_quantity, updated_at = now()
      where id = p_ingredient_id;
  elsif p_type = 'out' then
    update public.ingredients
      set current_stock = current_stock - p_quantity, updated_at = now()
      where id = p_ingredient_id and current_stock >= p_quantity;
    if not found then
      raise exception 'insufficient_stock';
    end if;
  else
    raise exception 'invalid_type';
  end if;

  insert into public.stock_transactions (
    id, ingredient_id, ingredient_name, type, quantity, unit, note, created_by
  ) values (
    gen_random_uuid()::text, p_ingredient_id, v_ing.name, p_type, p_quantity,
    v_ing.unit, coalesce(p_note, ''), (select full_name from public.app_users where id = p_actor_id)
  );

  insert into public.audit_log (actor_id, action, order_id, reason)
  values (p_actor_id::text, 'adjust_stock', null, p_ingredient_id || ' ' || p_type || ' ' || p_quantity::text);
end;
$$;

-- ===== app_role() helper for RLS =====
create or replace function public.app_role()
returns text
language sql
security definer
set search_path = public
stable
as $$
  select role from public.app_users where id = auth.uid();
$$;
