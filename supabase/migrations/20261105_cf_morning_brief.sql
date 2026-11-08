-- Resumo da manhã: o app guarda aqui um resumo dos próximos dias
-- e a função cf-morning-brief manda por e-mail no horário escolhido.
create table if not exists public.cf_morning_brief (
  owner_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  email_on boolean not null default false,
  send_hour smallint not null default 7 check (send_hour between 5 and 11),
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  last_sent_on date
);

alter table public.cf_morning_brief enable row level security;

drop policy if exists "dono le e altera" on public.cf_morning_brief;
create policy "dono le e altera" on public.cf_morning_brief
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

-- Só o servidor marca o envio; o app não consegue mexer nessa coluna.
create or replace function public.cf_morning_brief_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('authenticated', 'anon') then
    new.last_sent_on := case when tg_op = 'UPDATE' then old.last_sent_on else null end;
  end if;
  return new;
end $$;

drop trigger if exists cf_morning_brief_guard on public.cf_morning_brief;
create trigger cf_morning_brief_guard before insert or update on public.cf_morning_brief
  for each row execute function public.cf_morning_brief_guard();

-- Agendamento: a cada hora cheia chama a função, que só envia
-- para quem escolheu aquele horário e ainda não recebeu hoje.
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.unschedule('leguno-resumo-da-manha')
where exists (select 1 from cron.job where jobname = 'leguno-resumo-da-manha');

select cron.schedule(
  'leguno-resumo-da-manha',
  '0 * * * *',
  $$select net.http_post(
      url := 'https://yjpxjzgvshaabjpdpbsc.supabase.co/functions/v1/cf-morning-brief',
      headers := '{"Content-Type":"application/json"}'::jsonb,
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
  )$$
);
