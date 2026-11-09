-- Excluir conta: completa a lista do que é apagado.
-- Antes, links de cobrança (nome do pagador e chave Pix), fechamentos mensais (nomes dos clientes)
-- e a assinatura só eram apagados quando o login também era removido. Quem usa também o
-- app Pessoal (login mantido) ficava com esses dados do Léguno. Agora saem sempre.
create or replace function public.cf_delete_my_account()
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
  uid uuid := auth.uid();
  t record;
  n bigint;
  other bigint := 0;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  delete from public.cf_booking_requests where owner_id = uid;
  delete from public.cf_booking_settings where owner_id = uid;
  delete from public.cf_calendar_feed where owner_id = uid;
  delete from public.cf_events where owner_id = uid;
  delete from public.cf_expense_payments where owner_id = uid;
  delete from public.cf_expenses where owner_id = uid;
  delete from public.cf_incomes where owner_id = uid;
  delete from public.cf_pay_links where owner_id = uid;
  delete from public.cf_payments where owner_id = uid;
  delete from public.cf_sessions where owner_id = uid;
  delete from public.cf_holidays where owner_id = uid;
  delete from public.cf_month_snapshots where owner_id = uid;
  delete from public.cf_clients where owner_id = uid;
  delete from public.cf_subscriptions where owner_id = uid;
  delete from public.cf_profiles where owner_id = uid;
  for t in
    select c.table_name, c.column_name from information_schema.columns c
    join information_schema.tables tb on tb.table_schema = c.table_schema and tb.table_name = c.table_name and tb.table_type = 'BASE TABLE'
    where c.table_schema = 'public' and c.column_name in ('owner_id', 'user_id')
      and c.table_name not like 'cf\_%' and c.table_name <> 'audit_log'
  loop
    execute format('select count(*) from public.%I where %I = $1', t.table_name, t.column_name) into n using uid;
    other := other + n;
  end loop;
  if other > 0 then
    return 'avora_data_deleted';
  end if;
  delete from auth.users where id = uid;
  return 'account_deleted';
end $function$;
