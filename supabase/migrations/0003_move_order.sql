-- 0003 — Chuyển bàn atomic (move_order_v2)
-- Chạy sau 0002_security_hardening.sql. Chạy lại an toàn (idempotent).
--
-- Vấn đề: client cũ đổi bàn bằng 3 upsert rời rạc (2 bảng tables + 1 orders)
-- gửi qua queue — mất mạng giữa chừng là lệch bàn/đơn. RPC này gom thành
-- 1 transaction: đổi table_id đơn + bàn cũ về trống + bàn mới serving.
-- Client enqueue op 'move_order' duy nhất (optimistic local giữ nguyên).

-- move_order_v2: guard staff + replay-safe
drop function if exists public.move_order_v2(text, text, text);
create function public.move_order_v2(
  p_order_id text, p_old_table_id text, p_new_table_id text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.orders%rowtype;
  nt public.tables%rowtype;
begin
  if not public.is_staff() then
    raise exception 'move_order_v2: permission denied';
  end if;

  select * into o from public.orders where id = p_order_id;
  if not found then return; end if;
  -- replay/idempotent: đơn đã ở bàn đích thì chỉ gia cố trạng thái bàn
  if o.table_id is not null and o.table_id = p_new_table_id then
    update public.tables set status = 'serving', current_order_id = p_order_id
    where id = p_new_table_id;
    return;
  end if;

  select * into nt from public.tables where id = p_new_table_id;
  if not found then return; end if;

  update public.orders
    set table_id = nt.id, table_name = nt.table_name, updated_at = now()
  where id = p_order_id;

  if p_old_table_id is not null then
    update public.tables set status = 'empty', current_order_id = null
    where id = p_old_table_id;
  end if;
  update public.tables set status = 'serving', current_order_id = p_order_id
  where id = nt.id;
end;
$$;

revoke execute on function public.move_order_v2(text, text, text)
  from public, anon;
grant execute on function public.move_order_v2(text, text, text)
  to authenticated;
