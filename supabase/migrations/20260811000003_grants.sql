-- SmartCafe: GRANT base privileges for RLS. RLS policies only filter rows;
-- the role still needs table-level GRANT to even see a table. `authenticated`
-- gets SELECT on read surfaces (reference data + read-only money/tracking);
-- writes go through SECURITY DEFINER RPCs (no direct INSERT/UPDATE/DELETE).

-- reference data: staff reads, admin writes
grant select on public.categories, public.toppings, public.products,
  public.ingredients, public.recipes, public.recipe_items,
  public.vouchers, public.cafe_tables, public.notifications
  to authenticated;

-- app_users: staff reads own + all (policy filters), admin writes via policy
grant select on public.app_users to authenticated;

-- customers: staff reads all, customer own-row via policy
grant select on public.customers to authenticated;

-- money/stock tables: read-only for staff (write = RPC only)
grant select on public.orders, public.order_items, public.stock_transactions,
  public.audit_log
  to authenticated;

-- RPC functions: grant execute to authenticated (SECURITY DEFINER runs as owner)
grant execute on function public.rpc_next_order_code() to authenticated;
grant execute on function public.rpc_place_order(uuid, text, text, jsonb, text, text, text, int, numeric, text) to authenticated;
grant execute on function public.rpc_consume_recipe(text) to authenticated;
grant execute on function public.rpc_pay_order(text, text) to authenticated;
grant execute on function public.rpc_cancel_order(text, text) to authenticated;
grant execute on function public.rpc_move_order(text, text) to authenticated;
grant execute on function public.rpc_adjust_stock(text, text, numeric, text, uuid) to authenticated;
