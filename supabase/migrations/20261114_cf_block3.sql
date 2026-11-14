-- Bloco 3:
-- 1) Pedido de remarcação ou cancelamento pelo link de agendamento.
-- 2) Registro de uso das funções (sem dados de clientes).
-- 3) Excluir conta passa a apagar também o resumo da manhã e o registro de uso.

-- 1) Tipo do pedido: novo horário (padrão), remarcar ou cancelar.
alter table public.cf_booking_requests
  add column if not exists kind text not null default 'new';
alter table public.cf_booking_requests drop constraint if exists cf_booking_requests_kind_check;
alter table public.cf_booking_requests
  add constraint cf_booking_requests_kind_check check (kind in ('new', 'change', 'cancel'));

create or replace function public.cf_request_change(
  p_slug text, p_name text, p_phone text, p_kind text, p_note text default '', p_email text default ''
) returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  s cf_booking_settings%rowtype;
  digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  mail text := lower(trim(coalesce(p_email, '')));
begin
  select * into s from cf_booking_settings where slug = p_slug and enabled;
  if not found then return 'Este link não está mais ativo.'; end if;
  if p_kind not in ('change', 'cancel') then return 'Escolha remarcar ou cancelar.'; end if;
  if length(trim(coalesce(p_name, ''))) < 2 then return 'Digite seu nome.'; end if;
  if length(digits) < 10 or length(digits) > 15 then return 'Digite um telefone com DDD.'; end if;
  if mail <> '' and (length(mail) > 120 or mail !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$') then return 'Confira o e-mail digitado.'; end if;
  if length(trim(coalesce(p_note, ''))) < 3 then return 'Conte qual horário é e, se for remarcar, para quando.'; end if;
  if (select count(*) from cf_booking_requests where owner_id = s.owner_id and phone = digits and status = 'pending' and kind <> 'new') >= 2 then
    return 'Você já tem um pedido aguardando resposta. Aguarde o retorno do profissional.';
  end if;
  if (select count(*) from cf_booking_requests where owner_id = s.owner_id and created_at > now() - interval '1 day') >= 40 then
    return 'Muitos pedidos hoje. Tente mais tarde ou fale direto com o profissional.';
  end if;
  insert into cf_booking_requests(owner_id, name, phone, email, service, date, time, note, kind)
  values (s.owner_id, left(trim(p_name), 80), digits, mail, '', current_date, '00:00', left(trim(p_note), 300), p_kind);
  return 'ok';
end;
$function$;

revoke all on function public.cf_request_change(text, text, text, text, text, text) from public;
grant execute on function public.cf_request_change(text, text, text, text, text, text) to anon, authenticated, service_role;

-- 2) Registro de uso: só o nome da função usada e o dia. Nada de nomes, valores ou telefones.
create table if not exists public.cf_usage_events (
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  event text not null check (event ~ '^[a-z0-9_]{3,40}$'),
  day date not null default ((now() at time zone 'America/Sao_Paulo')::date),
  platform text not null default '' check (char_length(platform) <= 20),
  created_at timestamptz not null default now(),
  primary key (owner_id, event, day)
);
alter table public.cf_usage_events enable row level security;
-- O app só grava; quem lê é o servidor (consulta do dono do Léguno).
drop policy if exists "dono grava" on public.cf_usage_events;
create policy "dono grava" on public.cf_usage_events for insert to authenticated
  with check (owner_id = (select auth.uid()));

-- 3) Excluir conta: agora também apaga o resumo da manhã e o registro de uso.
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
  delete from public.cf_support_requests where owner_id = uid;
  delete from public.cf_morning_brief where owner_id = uid;
  delete from public.cf_usage_events where owner_id = uid;
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
