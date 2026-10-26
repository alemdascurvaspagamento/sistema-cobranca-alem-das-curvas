-- Coach Flow Profissional — área própria no banco (tabelas cf_*).
-- Convive com as tabelas do Coach Flow Pessoal sem alterá-las.
-- Cada linha pertence a um profissional (owner_id) e só ele a vê (RLS).

create table if not exists public.cf_profiles (
  owner_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  profession_id text not null default 'outra',
  profession_name text,
  billing_model text not null default 'perSession'
    check (billing_model in ('perSession','hourly','monthly','package')),
  cancel_rule text not null default 'compensate' check (cancel_rule in ('compensate','charge','waive')),
  holiday_rule text not null default 'noCharge' check (holiday_rule in ('noCharge','charge')),
  move_rule text not null default 'chargeNewMonth' check (move_rule in ('chargeNewMonth','chargeOriginalMonth')),
  pix_key text not null default '',
  business_name text,
  monthly_goal numeric(12,2) not null default 0 check (monthly_goal >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cf_clients (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  phone text not null default '',
  service text not null default '',
  model text not null default 'perSession' check (model in ('perSession','hourly','monthly','package')),
  rate numeric(12,2) not null default 0 check (rate >= 0),
  weekdays smallint[] not null default '{}',
  times jsonb not null default '{}'::jsonb,
  duration_minutes int not null default 60 check (duration_minutes between 5 and 600),
  package_size int not null default 10 check (package_size >= 1),
  package_start date,
  due_day int not null default 5 check (due_day between 1 and 31),
  active boolean not null default true,
  legacy_id bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_id)
);

create table if not exists public.cf_sessions (
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid not null,
  date date not null,
  status text not null default 'scheduled'
    check (status in ('scheduled','completed','cancelled','moved','rescheduled')),
  charge boolean,
  credit boolean not null default false,
  new_date date,
  origin_date date,
  extra boolean not null default false,
  note text not null default '',
  time text check (time is null or time ~ '^[0-2][0-9]:[0-5][0-9]$'),
  updated_at timestamptz not null default now(),
  primary key (client_id, date),
  foreign key (client_id, owner_id) references public.cf_clients(id, owner_id) on delete cascade
);

create table if not exists public.cf_holidays (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date date not null,
  name text not null,
  no_class boolean not null default true
);

create table if not exists public.cf_payments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid not null,
  month date not null check (extract(day from month) = 1),
  amount numeric(12,2) not null check (amount > 0),
  paid_on date not null,
  method text not null default 'Pix',
  created_at timestamptz not null default now(),
  foreign key (client_id, owner_id) references public.cf_clients(id, owner_id) on delete cascade
);

create table if not exists public.cf_expenses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  description text not null,
  amount numeric(12,2) not null check (amount > 0),
  date date not null,
  fixed boolean not null default false,
  end_month date,
  created_at timestamptz not null default now(),
  unique (id, owner_id)
);

create table if not exists public.cf_expense_payments (
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  expense_id uuid not null,
  month date not null check (extract(day from month) = 1),
  paid_on date not null,
  primary key (expense_id, month),
  foreign key (expense_id, owner_id) references public.cf_expenses(id, owner_id) on delete cascade
);

create table if not exists public.cf_incomes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  description text not null,
  amount numeric(12,2) not null check (amount > 0),
  date date not null,
  created_at timestamptz not null default now()
);

create index if not exists cf_clients_owner_idx on public.cf_clients(owner_id);
create index if not exists cf_sessions_owner_date_idx on public.cf_sessions(owner_id, date);
create index if not exists cf_holidays_owner_idx on public.cf_holidays(owner_id, date);
create index if not exists cf_payments_owner_idx on public.cf_payments(owner_id, month);
create index if not exists cf_payments_client_idx on public.cf_payments(client_id, owner_id);
create index if not exists cf_expenses_owner_idx on public.cf_expenses(owner_id);
create index if not exists cf_expense_payments_expense_idx on public.cf_expense_payments(expense_id, owner_id);
create index if not exists cf_expense_payments_owner_idx on public.cf_expense_payments(owner_id);
create index if not exists cf_incomes_owner_idx on public.cf_incomes(owner_id, date);

-- Segurança: só usuários logados, e cada um só enxerga e altera o que é seu.
do $$
declare t text;
begin
  foreach t in array array['cf_profiles','cf_clients','cf_sessions','cf_holidays','cf_payments',
                           'cf_expenses','cf_expense_payments','cf_incomes'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('drop policy if exists "dono le e altera" on public.%I', t);
    execute format($p$create policy "dono le e altera" on public.%I for all to authenticated
                     using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()))$p$, t);
  end loop;
end $$;

-- Mantém updated_at em dia.
create or replace function public.cf_touch() returns trigger language plpgsql
set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;

drop trigger if exists cf_profiles_touch on public.cf_profiles;
create trigger cf_profiles_touch before update on public.cf_profiles for each row execute function public.cf_touch();
drop trigger if exists cf_clients_touch on public.cf_clients;
create trigger cf_clients_touch before update on public.cf_clients for each row execute function public.cf_touch();
drop trigger if exists cf_sessions_touch on public.cf_sessions;
create trigger cf_sessions_touch before update on public.cf_sessions for each row execute function public.cf_touch();
