-- Coach Flow Profissional: deploy ONLY to its own Supabase project.
create table if not exists public.cf_clients (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null check (length(trim(name)) between 1 and 160),
 service text not null default '',
 phone text not null default '',
 status text not null default 'Em dia',
 created_at timestamptz not null default now(),
 unique(id,owner_id)
);
create table if not exists public.cf_appointments (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 client_id uuid not null,
 starts_at timestamptz not null,
 status text not null default 'Agendada'
   check (status in ('Agendada','Realizada','Cancelada')),
 charge boolean not null default true,
 unit_price numeric(12,2) not null default 0 check(unit_price>=0),
 note text not null default '',
 created_at timestamptz not null default now(),
 foreign key(client_id,owner_id) references public.cf_clients(id,owner_id) on delete cascade
);
create table if not exists public.cf_billing (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 client_id uuid not null,
 period date not null,
 adjustment numeric(12,2) not null default 0,
 paid_at timestamptz,
 created_at timestamptz not null default now(),
 unique(owner_id,client_id,period),
 foreign key(client_id,owner_id) references public.cf_clients(id,owner_id) on delete cascade
);
create index if not exists cf_appointments_owner_date on public.cf_appointments(owner_id,starts_at);
create index if not exists cf_billing_owner_period on public.cf_billing(owner_id,period);
alter table public.cf_clients enable row level security;
alter table public.cf_appointments enable row level security;
alter table public.cf_billing enable row level security;
create policy cf_clients_owner on public.cf_clients for all to authenticated
 using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id);
create policy cf_appointments_owner on public.cf_appointments for all to authenticated
 using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id);
create policy cf_billing_owner on public.cf_billing for all to authenticated
 using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id);
grant select,insert,update,delete on public.cf_clients,public.cf_appointments,public.cf_billing to authenticated;
