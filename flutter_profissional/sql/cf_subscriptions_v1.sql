-- Coach Flow Profissional: assinatura de cada profissional.
-- Só o servidor (service_role / webhook do Asaas) altera; o profissional só lê a própria.

create table if not exists public.cf_subscriptions (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null default 'profissional' check (plan in ('essencial', 'profissional')),
  status text not null default 'trialing'
    check (status in ('trialing', 'active', 'past_due', 'canceled', 'courtesy')),
  trial_ends_at timestamptz not null default (now() + interval '14 days'),
  current_period_end timestamptz,
  founder boolean not null default false,
  asaas_customer_id text,
  asaas_subscription_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.cf_subscriptions enable row level security;
revoke all on public.cf_subscriptions from anon;
revoke insert, update, delete on public.cf_subscriptions from authenticated;
grant select on public.cf_subscriptions to authenticated;

drop policy if exists "dono le a assinatura" on public.cf_subscriptions;
create policy "dono le a assinatura" on public.cf_subscriptions
  for select to authenticated using (owner_id = (select auth.uid()));

drop trigger if exists cf_subscriptions_touch on public.cf_subscriptions;
create trigger cf_subscriptions_touch before update on public.cf_subscriptions
  for each row execute function public.cf_touch();

-- Situação efetiva de quem está logado (considera datas): trialing, active, grace, read_only, courtesy.
create or replace function public.cf_access_state()
returns text
language sql stable security invoker
set search_path = ''
as $$
  select case
    when s.owner_id is null then 'trialing'  -- primeiro acesso, ainda sem linha
    when s.status = 'courtesy' then 'courtesy'
    when s.status in ('active', 'past_due') and s.current_period_end > now() then 'active'
    when s.status in ('active', 'past_due') and s.current_period_end + interval '7 days' > now() then 'grace'
    when s.status = 'canceled' and s.current_period_end > now() then 'active'
    when s.status = 'trialing' and s.trial_ends_at > now() then 'trialing'
    else 'read_only'
  end
  from (select 1) one
  left join public.cf_subscriptions s on s.owner_id = auth.uid()
$$;
revoke all on function public.cf_access_state() from public, anon;
grant execute on function public.cf_access_state() to authenticated;

create or replace function public.cf_can_write()
returns boolean
language sql stable
set search_path = ''
as $$ select public.cf_access_state() <> 'read_only' $$;
revoke all on function public.cf_can_write() from public, anon;
grant execute on function public.cf_can_write() to authenticated;

-- O que o app precisa saber da assinatura.
create or replace function public.cf_my_subscription()
returns jsonb
language sql stable security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'plan', coalesce(s.plan, 'profissional'),
    'status', coalesce(s.status, 'trialing'),
    'state', public.cf_access_state(),
    'trial_ends_at', s.trial_ends_at,
    'current_period_end', s.current_period_end,
    'founder', coalesce(s.founder, false),
    'client_limit', case when s.plan = 'essencial' and s.status <> 'courtesy' then 15 else null end
  )
  from (select 1) one
  left join public.cf_subscriptions s on s.owner_id = auth.uid()
$$;
revoke all on function public.cf_my_subscription() from public, anon;
grant execute on function public.cf_my_subscription() to authenticated;

-- Primeiro acesso: ao criar o perfil, começa o teste de 14 dias.
create or replace function public.cf_start_trial()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.cf_subscriptions (owner_id) values (new.owner_id)
  on conflict (owner_id) do nothing;
  return new;
end;
$$;
revoke all on function public.cf_start_trial() from public, anon, authenticated;

drop trigger if exists cf_profiles_start_trial on public.cf_profiles;
create trigger cf_profiles_start_trial after insert on public.cf_profiles
  for each row execute function public.cf_start_trial();

-- Somente leitura: bloqueia gravações nas tabelas de dados (o perfil continua editável).
do $$
declare t text;
begin
  foreach t in array array['cf_clients','cf_sessions','cf_holidays','cf_payments','cf_expenses',
                           'cf_expense_payments','cf_incomes'] loop
    execute format('drop policy if exists "assinatura em dia (inserir)" on public.%I', t);
    execute format('drop policy if exists "assinatura em dia (alterar)" on public.%I', t);
    execute format('drop policy if exists "assinatura em dia (apagar)" on public.%I', t);
    execute format('create policy "assinatura em dia (inserir)" on public.%I as restrictive for insert to authenticated with check ((select public.cf_can_write()))', t);
    execute format('create policy "assinatura em dia (alterar)" on public.%I as restrictive for update to authenticated using ((select public.cf_can_write()))', t);
    execute format('create policy "assinatura em dia (apagar)" on public.%I as restrictive for delete to authenticated using ((select public.cf_can_write()))', t);
  end loop;
end $$;

-- Plano Essencial: no máximo 15 clientes ativos.
create or replace function public.cf_check_client_limit()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare lim int; n int;
begin
  if not new.active then return new; end if;
  if tg_op = 'UPDATE' and old.active then return new; end if;
  -- Upsert de um cliente que já está ativo (edição): não conta como novo.
  if tg_op = 'INSERT' and exists (select 1 from public.cf_clients c where c.id = new.id and c.active) then
    return new;
  end if;
  select case when s.plan = 'essencial' and s.status <> 'courtesy' then 15 end into lim
  from public.cf_subscriptions s where s.owner_id = new.owner_id;
  if lim is null then return new; end if;
  select count(*) into n from public.cf_clients c
  where c.owner_id = new.owner_id and c.active and c.id <> new.id;
  if n >= lim then
    raise exception 'cf_limite_clientes' using hint = 'Plano Essencial: até 15 clientes ativos.';
  end if;
  return new;
end;
$$;
revoke all on function public.cf_check_client_limit() from public, anon, authenticated;

drop trigger if exists cf_clients_limit on public.cf_clients;
create trigger cf_clients_limit before insert or update of active on public.cf_clients
  for each row execute function public.cf_check_client_limit();

-- Contas que já existiam antes da assinatura: cortesia (o dono do Coach Flow).
insert into public.cf_subscriptions (owner_id, status, plan)
select p.owner_id, 'courtesy', 'profissional' from public.cf_profiles p
on conflict (owner_id) do nothing;
