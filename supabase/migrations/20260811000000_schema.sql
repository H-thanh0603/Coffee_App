-- SmartCafe schema: 16 tables (15 app + order_seq)
-- Money = numeric(12,2); stock = numeric(12,3). Enums = text + CHECK (matches Dart .name).
-- All updated_at timestamptz default now() for delta sync. RLS enabled; policies in later migration.

create extension if not exists pgcrypto;

-- ===== app_users (maps AppUser; PK = auth.users id) =====
create table if not exists public.app_users (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text not null unique,
  phone text not null default '',
  role text not null default 'customer'
    check (role in ('admin','cashier','barista','waiter','customer')),
  avatar_url text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ===== categories =====
create table if not exists public.categories (
  id text primary key,
  name text not null,
  description text not null default '',
  icon text not null default '☕',
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

-- ===== toppings =====
create table if not exists public.toppings (
  id text primary key,
  name text not null,
  price numeric(12,2) not null default 0 check (price >= 0),
  available boolean not null default true,
  updated_at timestamptz not null default now()
);

-- ===== products =====
create table if not exists public.products (
  id text primary key,
  name text not null,
  description text not null default '',
  image_url text not null default '',
  emoji text not null default '☕',
  category_id text not null references public.categories(id),
  base_price numeric(12,2) not null default 0 check (base_price >= 0),
  price_by_size jsonb not null default '{}'::jsonb,
  available_topping_ids jsonb not null default '[]'::jsonb,
  in_stock boolean not null default true,
  hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_products_category on public.products(category_id);

-- ===== orders (created before cafe_tables which FK-references it) =====
create table if not exists public.orders (
  id text primary key,
  order_code text not null unique,
  table_id text,
  table_name text,
  customer_id text,
  customer_name text,
  cashier_id uuid references public.app_users(id),
  cashier_name text not null default '',
  order_type text not null check (order_type in ('dineIn','takeaway')),
  subtotal numeric(12,2) not null default 0,
  discount numeric(12,2) not null default 0,
  voucher_code text,
  points_used int not null default 0,
  points_discount numeric(12,2) not null default 0,
  total numeric(12,2) not null default 0 check (total >= 0),
  payment_method text check (payment_method in ('cash','transfer','ewallet','qr')),
  payment_status text not null default 'unpaid'
    check (payment_status in ('unpaid','paid','refunded')),
  order_status text not null default 'pending'
    check (order_status in ('pending','confirmed','preparing','ready','served','paid','cancelled')),
  stock_consumed boolean not null default false,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);
create index if not exists idx_orders_paid on public.orders(payment_status, completed_at);
create index if not exists idx_orders_customer on public.orders(customer_id);
create index if not exists idx_orders_table on public.orders(table_id);

-- ===== cafe_tables =====
create table if not exists public.cafe_tables (
  id text primary key,
  table_name text not null,
  capacity int not null default 4 check (capacity between 1 and 20),
  status text not null default 'empty'
    check (status in ('empty','serving','waiting','reserved','needsClean')),
  current_order_id text,
  qr_code_value text not null default '',
  updated_at timestamptz not null default now()
);
-- FK added after both tables exist (circular reference with orders.table_id)
alter table public.cafe_tables
  add constraint fk_cafe_tables_current_order
  foreign key (current_order_id) references public.orders(id);
alter table public.orders
  add constraint fk_orders_table
  foreign key (table_id) references public.cafe_tables(id);

-- ===== customers =====
create table if not exists public.customers (
  id text primary key,
  full_name text not null,
  phone text not null unique,
  email text not null default '',
  points int not null default 0,
  rank text not null default 'bronze'
    check (rank in ('bronze','silver','gold','diamond')),
  total_spent numeric(12,2) not null default 0,
  total_orders int not null default 0,
  favorite_products jsonb not null default '[]'::jsonb,
  auth_uid uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.orders
  add constraint fk_orders_customer
  foreign key (customer_id) references public.customers(id);

-- ===== ingredients =====
create table if not exists public.ingredients (
  id text primary key,
  name text not null,
  unit text not null default '',
  current_stock numeric(12,3) not null default 0 check (current_stock >= 0),
  min_stock numeric(12,3) not null default 0,
  cost_per_unit numeric(12,3) not null default 0,
  supplier text not null default '',
  expired_date date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ===== recipes + recipe_items =====
create table if not exists public.recipes (
  id text primary key,
  product_id text not null references public.products(id) on delete cascade,
  size text not null check (size in ('s','m','l')),
  unique(product_id, size)
);

create table if not exists public.recipe_items (
  id bigint generated always as identity primary key,
  recipe_id text not null references public.recipes(id) on delete cascade,
  ingredient_id text not null references public.ingredients(id),
  quantity numeric(12,3) not null check (quantity > 0),
  unit text not null default '',
  unique(recipe_id, ingredient_id)
);

-- ===== vouchers =====
create table if not exists public.vouchers (
  id text primary key,
  code text not null unique,
  name text not null default '',
  discount_type text not null check (discount_type in ('percent','amount')),
  discount_value numeric(12,2) not null default 0,
  min_order_value numeric(12,2) not null default 0,
  max_discount numeric(12,2) not null default 0,
  start_date timestamptz not null,
  end_date timestamptz not null,
  usage_limit int not null default 1000,
  used_count int not null default 0 check (used_count <= usage_limit),
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

-- ===== order_items =====
create table if not exists public.order_items (
  id bigint generated always as identity primary key,
  order_id text not null references public.orders(id) on delete cascade,
  product_id text references public.products(id),
  product_name text not null,
  emoji text not null default '☕',
  size text not null default 'm' check (size in ('s','m','l')),
  topping_ids jsonb not null default '[]'::jsonb,
  topping_names jsonb not null default '[]'::jsonb,
  toppings_price numeric(12,2) not null default 0,
  sugar text not null default 'full' check (sugar in ('zero','low','half','high','full')),
  ice text not null default 'normal' check (ice in ('none','low','normal','high')),
  quantity int not null check (quantity > 0),
  unit_price numeric(12,2) not null default 0,
  note text not null default '',
  status text not null default 'pending'
    check (status in ('pending','preparing','ready','served'))
);
create index if not exists idx_order_items_order on public.order_items(order_id);

-- ===== stock_transactions =====
create table if not exists public.stock_transactions (
  id text primary key,
  ingredient_id text not null references public.ingredients(id),
  ingredient_name text not null default '',
  type text not null check (type in ('in','out','consumed')),
  quantity numeric(12,3) not null check (quantity > 0),
  unit text not null default '',
  note text not null default '',
  created_by text not null default 'system',
  created_at timestamptz not null default now()
);
create index if not exists idx_stocktx_ingredient on public.stock_transactions(ingredient_id, created_at);

-- ===== notifications =====
create table if not exists public.notifications (
  id text primary key,
  title text not null,
  message text not null,
  type text not null default 'info',
  target_role text check (target_role in ('admin','cashier','barista','waiter','customer')),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- ===== order_seq (order code generator) =====
create table if not exists public.order_seq (
  id int primary key default 1 check (id = 1),
  last_val int not null default 0
);
insert into public.order_seq (id, last_val) values (1, 0)
  on conflict (id) do nothing;

-- ===== audit_log (rubric §9) =====
create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  actor_id text,
  action text not null,
  order_id text,
  reason text,
  created_at timestamptz not null default now()
);
create index if not exists idx_audit_order on public.audit_log(order_id);

-- ===== trigger: new auth.users -> app_users row =====
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.app_users (id, full_name, email, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    'customer'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ===== RLS enable =====
alter table public.app_users enable row level security;
alter table public.categories enable row level security;
alter table public.toppings enable row level security;
alter table public.products enable row level security;
alter table public.cafe_tables enable row level security;
alter table public.customers enable row level security;
alter table public.ingredients enable row level security;
alter table public.recipes enable row level security;
alter table public.recipe_items enable row level security;
alter table public.vouchers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.stock_transactions enable row level security;
alter table public.notifications enable row level security;
alter table public.order_seq enable row level security;
alter table public.audit_log enable row level security;
