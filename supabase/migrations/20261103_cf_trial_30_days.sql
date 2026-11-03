-- Teste grátis passa de 60 para 30 dias para quem se cadastrar daqui em diante.
-- Quem já tem conta continua com o prazo que recebeu.
create or replace function public.cf_new_user_trial()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  begin
    insert into public.cf_subscriptions (owner_id, trial_ends_at)
    values (new.id, coalesce(new.created_at, now()) + interval '30 days')
    on conflict (owner_id) do nothing;
  exception when others then
    null; -- nunca impede o cadastro
  end;
  return new;
end $function$;
alter table public.cf_subscriptions alter column trial_ends_at set default (now() + interval '30 days');
