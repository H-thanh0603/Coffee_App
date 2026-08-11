-- SmartCafe RLS policies. Staff = admin/cashier/barista/waiter.
-- Money/order tables: write via RPC only (no direct INSERT/UPDATE/DELETE).

-- ===== reference data (admin writes, staff reads) =====
create policy rp_ref_select on public.categories for select
  to authenticated using (public.app_role() in ('admin','cashier','barista','waiter'));
create policy rp_ref_admin on public.categories for all
  to authenticated using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

create policy rp_ref_select on public.toppings for select
  to authenticated using (public.app_role() in ('admin','cashier','barista','waiter'));
create policy rp_ref_admin on public.toppings for all
  to authenticated using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

create policy rp_ref_select on public.products for select
  to authenticated using (public.app_role() in ('admin','cashier','barista','waiter'));
create policy rp_ref_admin on public.products for all
  to authenticated using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

create policy rp_ref_select on public.ingredients for select
  to authenticated using (public.app_role() in ('admin','cashier','barista','waiter'));
create policy rp_ref_admin on public.ingredients for all
  to authenticated using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

create policy rp_ref_select on public.recipes for select
  to authenticated using (public.app_role() in ('admin','cashier','barista','waiter'));
create policy rp_ref_admin on public.recipes for all
  to authenticated using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

create policy rp_ref_select on public.recipe_items for select
  to authenticated using (public.app_role() in ('admin','cashier','barista','waiter'));
create policy rp_ref_admin on public.recipe_items for all
  to authenticated using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

create policy rp_ref_select on public.vouchers for select
  to authenticated using (public.app_role() in ('admin','cashier','barista','waiter'));
create policy rp_ref_admin on public.vouchers for all
  to authenticated using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

create policy rp_ref_select on public.cafe_tables for select
  to authenticated using (public.app_role() in ('admin','cashier','barista','waiter'));
create policy rp_ref_admin on public.cafe_tables for all
  to authenticated using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ===== app_users: staff read all, admin write; self read own =====
create policy rp_users_select on public.app_users for select
  to authenticated using (
    public.app_role() in ('admin','cashier','barista','waiter')
    or id = auth.uid()
  );
create policy rp_users_admin on public.app_users for all
  to authenticated using (public.app_role() = 'admin') with check (public.app_role() = 'admin');
create policy rp_users_self on public.app_users for update
  to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ===== customers: staff read, admin write, customer reads/updates own =====
create policy rp_cust_select on public.customers for select
  to authenticated using (
    public.app_role() in ('admin','cashier','barista','waiter')
    or auth_uid = auth.uid()
  );
create policy rp_cust_admin on public.customers for all
  to authenticated using (public.app_role() = 'admin') with check (public.app_role() = 'admin');
create policy rp_cust_self on public.customers for update
  to authenticated using (auth_uid = auth.uid())
  with check (auth_uid = auth.uid());

-- ===== orders: staff read, customer reads own; NO direct write (RPC only) =====
create policy rp_order_select on public.orders for select
  to authenticated using (
    public.app_role() in ('admin','cashier','barista','waiter')
    or customer_id in (select id from public.customers where auth_uid = auth.uid())
  );

-- ===== order_items / stock_transactions: staff read; write via RPC =====
create policy rp_oitem_select on public.order_items for select
  to authenticated using (public.app_role() in ('admin','cashier','barista','waiter'));
create policy rp_stocktx_select on public.stock_transactions for select
  to authenticated using (public.app_role() in ('admin','cashier','barista','waiter'));

-- ===== notifications: staff read =====
create policy rp_notif_select on public.notifications for select
  to authenticated using (public.app_role() in ('admin','cashier','barista','waiter'));
create policy rp_notif_admin on public.notifications for all
  to authenticated using (public.app_role() = 'admin') with check (public.app_role() = 'admin');

-- ===== order_seq / audit_log: RPC only =====
-- (no select policies -> RLS denies by default; RPCs are security definer)

-- ===== realtime publication =====
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end
$$;
alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.cafe_tables;
alter publication supabase_realtime add table public.ingredients;
alter publication supabase_realtime add table public.vouchers;
alter publication supabase_realtime add table public.customers;
