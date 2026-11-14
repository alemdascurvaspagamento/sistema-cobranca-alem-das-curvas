-- Painel de administração do Léguno (fase 1).
-- Tudo aqui é novo: não altera nem apaga dados existentes.
-- Segurança: as tabelas novas não têm nenhuma regra de leitura direta. O painel só
-- funciona por funções que confirmam, no banco, que quem chama é administrador.
-- O painel mostra dados da CONTA (e-mail, plano, uso). Nunca o conteúdo dos clientes
-- do profissional, nem o que ele recebe.

-- 1) Marcas novas na assinatura -------------------------------------------------
alter table public.cf_subscriptions add column if not exists internal boolean not null default false;
alter table public.cf_subscriptions add column if not exists cycle text not null default 'monthly';
do $$ begin
  alter table public.cf_subscriptions add constraint cf_subscriptions_cycle_chk check (cycle in ('monthly','annual'));
exception when duplicate_object then null; end $$;

-- 2) Quem é administrador e o registro das ações ----------------------------------
create table if not exists public.cf_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.cf_admins enable row level security;
revoke all on public.cf_admins from anon, authenticated;

create table if not exists public.cf_admin_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid,
  target_id uuid,
  action text not null,
  detail jsonb,
  created_at timestamptz not null default now()
);
alter table public.cf_admin_log enable row level security;
revoke all on public.cf_admin_log from anon, authenticated;
create index if not exists cf_admin_log_created_idx on public.cf_admin_log (created_at desc);

-- 3) Funções de apoio (não ficam abertas para o app) ------------------------------
create or replace function public.cf_is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.cf_admins where user_id = auth.uid())
$$;

create or replace function public._cf_admin_guard() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.cf_is_admin() then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
end $$;

create or replace function public._cf_state_of(st text, per_end timestamptz, trial_end timestamptz) returns text
language sql stable set search_path = '' as $$
  select case
    when st is null then 'read_only'
    when st = 'courtesy' then 'courtesy'
    when st in ('active', 'past_due') and per_end > now() then 'active'
    when st in ('active', 'past_due') and per_end + interval '7 days' > now() then 'grace'
    when st = 'canceled' and per_end > now() then 'active'
    when st = 'trialing' and trial_end > now() then 'trialing'
    else 'read_only'
  end
$$;

-- Preço mensal estimado (fundador R$ 39,90; Essencial R$ 34,90 ou R$ 349/ano; Profissional R$ 59,90 ou R$ 599/ano).
create or replace function public._cf_monthly_price(p_plan text, p_founder boolean, p_cycle text) returns numeric
language sql immutable set search_path = '' as $$
  select case
    when p_founder then 39.90
    when p_plan = 'essencial' then case when p_cycle = 'annual' then 349.0 / 12 else 34.90 end
    else case when p_cycle = 'annual' then 599.0 / 12 else 59.90 end
  end
$$;

create or replace function public._cf_accounts()
returns table (
  owner_id uuid, email text, created_at timestamptz, last_sign_in timestamptz, profession text,
  plan text, status text, state text, trial_ends_at timestamptz, current_period_end timestamptz,
  founder boolean, internal boolean, cycle text, clients int, platform text, last_seen date
)
language sql stable security definer set search_path = '' as $$
  select u.id, u.email::text, u.created_at, u.last_sign_in_at, p.profession_name,
         coalesce(s.plan, 'profissional'), coalesce(s.status, 'trialing'),
         public._cf_state_of(s.status, s.current_period_end, s.trial_ends_at),
         s.trial_ends_at, s.current_period_end, coalesce(s.founder, false), coalesce(s.internal, false),
         coalesce(s.cycle, 'monthly'),
         (select count(*)::int from public.cf_clients c where c.owner_id = u.id and c.active),
         (select e.platform from public.cf_usage_events e where e.owner_id = u.id order by e.created_at desc limit 1),
         (select max(e.day) from public.cf_usage_events e where e.owner_id = u.id)
  from auth.users u
  left join public.cf_subscriptions s on s.owner_id = u.id
  left join public.cf_profiles p on p.owner_id = u.id
$$;

create or replace function public._cf_funnel(p_days int) returns jsonb
language sql stable security definer set search_path = '' as $$
  with a as (
    select * from public._cf_accounts()
    where not internal and created_at > now() - make_interval(days => p_days)
  )
  select jsonb_build_object(
    'registered', (select count(*) from a),
    'with_client', (select count(*) from a where clients > 0
        or exists (select 1 from public.cf_usage_events e where e.owner_id = a.owner_id and e.event in ('cliente_novo', 'cliente_importado'))),
    'billed', (select count(*) from a where
        exists (select 1 from public.cf_payments p where p.owner_id = a.owner_id)
        or exists (select 1 from public.cf_usage_events e where e.owner_id = a.owner_id and e.event = 'cobranca_whatsapp')),
    'paid', (select count(*) from a where status in ('active', 'past_due'))
  )
$$;

revoke all on function public._cf_admin_guard() from public, anon, authenticated;
revoke all on function public._cf_state_of(text, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function public._cf_monthly_price(text, boolean, text) from public, anon, authenticated;
revoke all on function public._cf_accounts() from public, anon, authenticated;
revoke all on function public._cf_funnel(int) from public, anon, authenticated;
revoke all on function public.cf_is_admin() from public, anon;
grant execute on function public.cf_is_admin() to authenticated;

-- 4) Telas do painel ---------------------------------------------------------------
create or replace function public.cf_admin_overview(p_days int default 30) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare r jsonb;
begin
  perform public._cf_admin_guard();
  with a as (select * from public._cf_accounts() where not internal)
  select jsonb_build_object(
    'total', (select count(*) from a),
    'new_period', (select count(*) from a where created_at > now() - make_interval(days => p_days)),
    'trialing', (select count(*) from a where state = 'trialing'),
    'trial_ending', (select count(*) from a where state = 'trialing' and trial_ends_at < now() + interval '7 days'),
    'paying', (select count(*) from a where status = 'active' and state = 'active'),
    'mrr', (select coalesce(round(sum(public._cf_monthly_price(plan, founder, cycle)), 2), 0)
              from a where status = 'active' and state in ('active', 'grace')),
    'late', (select count(*) from a where state = 'grace'),
    'late_amount', (select coalesce(round(sum(public._cf_monthly_price(plan, founder, cycle)), 2), 0)
              from a where state = 'grace'),
    'active_week', (select count(distinct e.owner_id) from public.cf_usage_events e
              join a on a.owner_id = e.owner_id where e.day >= current_date - 6),
    'weekly', (select coalesce(jsonb_agg(jsonb_build_object('week', w.d, 'n',
                (select count(*) from a where a.created_at >= w.d and a.created_at < w.d + 7)) order by w.d), '[]'::jsonb)
              from (select (date_trunc('week', now())::date - 7 * g) as d from generate_series(4, 0, -1) g) w),
    'funnel', public._cf_funnel(p_days)
  ) into r;
  return r;
end $$;

create or replace function public.cf_admin_funnel(p_days int default 3650) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public._cf_admin_guard();
  return public._cf_funnel(p_days);
end $$;

create or replace function public.cf_admin_accounts(
  p_q text default null, p_filter text default 'all', p_limit int default 100, p_offset int default 0
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare r jsonb;
begin
  perform public._cf_admin_guard();
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb) into r from (
    select * from public._cf_accounts() a
    where (p_q is null or p_q = '' or a.email ilike '%' || p_q || '%' or coalesce(a.profession, '') ilike '%' || p_q || '%')
      and case p_filter
            when 'trial' then a.state = 'trialing'
            when 'paying' then a.status = 'active' and a.state = 'active'
            when 'late' then a.state = 'grace'
            when 'readonly' then a.state = 'read_only'
            when 'internal' then a.internal
            else true end
    order by a.created_at desc
    limit least(greatest(p_limit, 1), 500) offset greatest(p_offset, 0)
  ) x;
  return r;
end $$;

create or replace function public.cf_admin_account_detail(p_owner uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare r jsonb;
begin
  perform public._cf_admin_guard();
  select jsonb_build_object(
    'account', (select to_jsonb(a) from public._cf_accounts() a where a.owner_id = p_owner),
    'usage', (select coalesce(jsonb_agg(jsonb_build_object('event', e.event, 'day', e.day, 'platform', e.platform)
                order by e.day desc, e.event), '[]'::jsonb)
              from (select * from public.cf_usage_events where owner_id = p_owner order by day desc limit 60) e),
    'support', (select coalesce(jsonb_agg(jsonb_build_object('message', s.message, 'platform', s.platform,
                'app_version', s.app_version, 'created_at', s.created_at) order by s.created_at desc), '[]'::jsonb)
              from public.cf_support_requests s where s.owner_id = p_owner),
    'log', (select coalesce(jsonb_agg(jsonb_build_object('action', l.action, 'detail', l.detail,
                'created_at', l.created_at) order by l.created_at desc), '[]'::jsonb)
              from (select * from public.cf_admin_log where target_id = p_owner order by created_at desc limit 30) l)
  ) into r;
  return r;
end $$;

create or replace function public.cf_admin_support() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare r jsonb;
begin
  perform public._cf_admin_guard();
  select coalesce(jsonb_agg(jsonb_build_object('owner_id', s.owner_id, 'email', u.email, 'message', s.message,
           'platform', s.platform, 'app_version', s.app_version, 'created_at', s.created_at)
           order by s.created_at desc), '[]'::jsonb) into r
  from (select * from public.cf_support_requests order by created_at desc limit 100) s
  left join auth.users u on u.id = s.owner_id;
  return r;
end $$;

create or replace function public.cf_admin_log_list(p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare r jsonb;
begin
  perform public._cf_admin_guard();
  select coalesce(jsonb_agg(jsonb_build_object('action', l.action, 'detail', l.detail, 'created_at', l.created_at,
           'admin', ua.email, 'target', ut.email) order by l.created_at desc), '[]'::jsonb) into r
  from (select * from public.cf_admin_log order by created_at desc limit least(greatest(p_limit, 1), 500)) l
  left join auth.users ua on ua.id = l.admin_id
  left join auth.users ut on ut.id = l.target_id;
  return r;
end $$;

-- 5) Ações (todas ficam registradas) ------------------------------------------------
create or replace function public.cf_admin_extend_trial(p_owner uuid, p_days int, p_note text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s public.cf_subscriptions; new_end timestamptz;
begin
  perform public._cf_admin_guard();
  if p_days < 1 or p_days > 90 then raise exception 'escolha de 1 a 90 dias'; end if;
  select * into s from public.cf_subscriptions where owner_id = p_owner;
  if not found or s.status <> 'trialing' then raise exception 'só dá para estender conta em teste grátis'; end if;
  new_end := greatest(s.trial_ends_at, now()) + make_interval(days => p_days);
  update public.cf_subscriptions set trial_ends_at = new_end where owner_id = p_owner;
  insert into public.cf_admin_log (admin_id, target_id, action, detail)
    values (auth.uid(), p_owner, 'estender_teste',
            jsonb_build_object('dias', p_days, 'novo_fim', new_end, 'nota', p_note));
  return jsonb_build_object('trial_ends_at', new_end);
end $$;

create or replace function public.cf_admin_set_founder(p_owner uuid, p_founder boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform public._cf_admin_guard();
  update public.cf_subscriptions set founder = p_founder where owner_id = p_owner;
  if not found then raise exception 'conta sem assinatura'; end if;
  insert into public.cf_admin_log (admin_id, target_id, action, detail)
    values (auth.uid(), p_owner, 'fundador', jsonb_build_object('ligado', p_founder));
  return jsonb_build_object('founder', p_founder);
end $$;

create or replace function public.cf_admin_set_courtesy(p_owner uuid, p_on boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform public._cf_admin_guard();
  if p_on then
    update public.cf_subscriptions set status = 'courtesy' where owner_id = p_owner;
  else
    update public.cf_subscriptions set status = 'trialing', trial_ends_at = now() + interval '7 days' where owner_id = p_owner and status = 'courtesy';
  end if;
  if not found then raise exception 'nada a alterar nesta conta'; end if;
  insert into public.cf_admin_log (admin_id, target_id, action, detail)
    values (auth.uid(), p_owner, 'cortesia', jsonb_build_object('ligado', p_on));
  return jsonb_build_object('courtesy', p_on);
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'cf_admin_overview(int)', 'cf_admin_funnel(int)', 'cf_admin_accounts(text,text,int,int)',
    'cf_admin_account_detail(uuid)', 'cf_admin_support()', 'cf_admin_log_list(int)',
    'cf_admin_extend_trial(uuid,int,text)', 'cf_admin_set_founder(uuid,boolean)', 'cf_admin_set_courtesy(uuid,boolean)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- 6) Primeiro administrador e contas internas ----------------------------------------
insert into public.cf_admins (user_id)
  select id from auth.users where email = 'daniel.barsottini@gmail.com'
  on conflict do nothing;

update public.cf_subscriptions set internal = true
  where owner_id in (select id from auth.users where email like 'daniel.barsottini%@gmail.com' or email = 'daniel.barsottini@gmail.com');
