-- 0004 — Ca làm việc + đặt bàn trước
-- Chạy sau 0003_move_order.sql. Chạy lại an toàn (idempotent).
--
-- shifts: chấm công vào/ra ca (local-first, sync lên để admin xem).
-- reservations: đặt bàn trước có giờ (chống trùng giờ do client check ±60p,
-- server giữ đơn giản; staff ghi, khách không thấy của người khác).

create table if not exists public.shifts (
  id text primary key,
  user_id uuid not null references public.profiles(id),
  user_name text not null default '',
  clock_in timestamptz not null default now(),
  clock_out timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.reservations (
  id text primary key,
  table_id text not null references public.tables(id),
  table_name text not null default '',
  customer_name text not null default '',
  phone text not null default '',
  guests int not null default 2,
  reserved_at timestamptz not null,
  status text not null default 'upcoming'
    check (status in ('upcoming','seated','cancelled')),
  note text not null default '',
  created_at timestamptz not null default now()
);

alter table public.shifts enable row level security;
alter table public.reservations enable row level security;

-- shifts: staff đọc hết; chỉ admin + chính chủ ghi
drop policy if exists "own or staff read shifts" on public.shifts;
create policy "own or staff read shifts" on public.shifts for select
  to authenticated
  using (public.is_staff() or user_id = auth.uid());
drop policy if exists "own or admin write shifts" on public.shifts;
create policy "own or admin write shifts" on public.shifts for insert
  to authenticated
  with check (public.is_staff());
drop policy if exists "own or admin update shifts" on public.shifts;
create policy "own or admin update shifts" on public.shifts for update
  to authenticated
  using (public.is_staff()) with check (public.is_staff());
drop policy if exists "admin delete shifts" on public.shifts;
create policy "admin delete shifts" on public.shifts for delete
  to authenticated
  using (public.is_admin());

-- reservations: staff full (khách đặt qua nhân viên ghi hộ)
drop policy if exists "staff read reservations" on public.reservations;
create policy "staff read reservations" on public.reservations for select
  to authenticated
  using (public.is_staff());
drop policy if exists "staff insert reservations" on public.reservations;
create policy "staff insert reservations" on public.reservations for insert
  to authenticated
  with check (public.is_staff());
drop policy if exists "staff update reservations" on public.reservations;
create policy "staff update reservations" on public.reservations for update
  to authenticated
  using (public.is_staff()) with check (public.is_staff());
drop policy if exists "staff delete reservations" on public.reservations;
create policy "staff delete reservations" on public.reservations for delete
  to authenticated
  using (public.is_staff());
