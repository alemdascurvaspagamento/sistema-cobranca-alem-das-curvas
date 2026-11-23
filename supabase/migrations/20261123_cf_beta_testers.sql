-- Léguno Fiscal (demonstração) nos apps: só contas de teste escolhidas veem.
-- Tabela nova, sem políticas (ninguém lê direto); o app só pergunta "esta conta tem o recurso?".
create table if not exists public.cf_beta_testers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  features text[] not null default '{fiscal_demo}',
  note text,
  created_at timestamptz not null default now()
);
alter table public.cf_beta_testers enable row level security;
revoke all on public.cf_beta_testers from anon, authenticated;

create or replace function public.cf_has_beta(p_feature text)
returns boolean
language sql stable security definer
set search_path to ''
as $$
  select exists (
    select 1 from public.cf_beta_testers
    where user_id = auth.uid() and p_feature = any(features)
  )
$$;
revoke all on function public.cf_has_beta(text) from public, anon;
grant execute on function public.cf_has_beta(text) to authenticated;

-- Contas de teste do Daniel (a conta de revisão da Apple NÃO entra).
insert into public.cf_beta_testers (user_id, note)
select id, 'conta do Daniel' from auth.users
where lower(email) in ('daniel.barsottini@gmail.com', 'daniel.barsottini+teste@gmail.com')
on conflict (user_id) do nothing;
