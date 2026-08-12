-- Scaling: delta-sync indexes + catalog realtime publication

-- Indexes for WHERE updated_at >= $watermark queries
create index if not exists idx_orders_updated_at on public.orders(updated_at);
create index if not exists idx_cafe_tables_updated_at on public.cafe_tables(updated_at);
create index if not exists idx_customers_updated_at on public.customers(updated_at);
create index if not exists idx_ingredients_updated_at on public.ingredients(updated_at);
create index if not exists idx_vouchers_updated_at on public.vouchers(updated_at);
create index if not exists idx_products_updated_at on public.products(updated_at);
create index if not exists idx_categories_updated_at on public.categories(updated_at);
create index if not exists idx_toppings_updated_at on public.toppings(updated_at);

-- Add catalog tables to realtime publication for instant menu sync
alter publication supabase_realtime add table public.products;
alter publication supabase_realtime add table public.categories;
alter publication supabase_realtime add table public.toppings;
