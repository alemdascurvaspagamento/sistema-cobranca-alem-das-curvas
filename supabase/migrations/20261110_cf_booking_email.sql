-- Agendamento online: o cliente pode deixar o e-mail para receber a resposta
-- (aceito ou recusado) automaticamente.
alter table public.cf_booking_requests add column if not exists email text not null default '';

drop function if exists public.cf_request_booking(text, text, text, text, date, text, text);

create or replace function public.cf_request_booking(
  p_slug text, p_name text, p_phone text, p_service text, p_date date, p_time text,
  p_note text default '', p_email text default '')
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  s cf_booking_settings%rowtype;
  digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  mail text := lower(trim(coalesce(p_email, '')));
  tmin int;
  ok boolean := false;
  w jsonb;
  wins jsonb;
  dow int := extract(isodow from p_date)::int;
begin
  select * into s from cf_booking_settings where slug = p_slug and enabled;
  if not found then return 'Este link não está mais ativo.'; end if;
  if length(trim(coalesce(p_name, ''))) < 2 then return 'Digite seu nome.'; end if;
  if length(digits) < 10 or length(digits) > 15 then return 'Digite um telefone com DDD.'; end if;
  if mail <> '' and (length(mail) > 120 or mail !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$') then return 'Confira o e-mail digitado.'; end if;
  if p_time !~ '^[0-2][0-9]:[0-5][0-9]$' then return 'Horário inválido.'; end if;
  if p_date < current_date or p_date > current_date + s.days_ahead then return 'Escolha uma data dentro do período disponível.'; end if;
  if s.day_windows <> '{}'::jsonb then
    wins := coalesce(s.day_windows -> dow::text, '[]'::jsonb);
  elsif dow = any (s.weekdays) then
    wins := s.windows;
  else
    wins := '[]'::jsonb;
  end if;
  if jsonb_array_length(wins) = 0 then return 'Este dia não está disponível.'; end if;
  tmin := split_part(p_time, ':', 1)::int * 60 + split_part(p_time, ':', 2)::int;
  for w in select * from jsonb_array_elements(wins) loop
    if tmin >= split_part(w->>'start', ':', 1)::int * 60 + split_part(w->>'start', ':', 2)::int
       and tmin + s.slot_minutes <= split_part(w->>'end', ':', 1)::int * 60 + split_part(w->>'end', ':', 2)::int then
      ok := true;
    end if;
  end loop;
  if not ok then return 'Este horário não está disponível.'; end if;
  if exists (
    select 1 from jsonb_array_elements(s.busy) b
    where (b->>'date')::date = p_date
      and tmin < (b->>'end')::int and (b->>'start')::int < tmin + s.slot_minutes
  ) then return 'Este horário acabou de ser ocupado. Escolha outro.'; end if;
  if exists (select 1 from cf_booking_requests where owner_id = s.owner_id and status = 'pending' and date = p_date and time = p_time) then
    return 'Alguém já pediu este horário. Escolha outro.';
  end if;
  if (select count(*) from cf_booking_requests where owner_id = s.owner_id and phone = digits and status = 'pending') >= 3 then
    return 'Você já tem pedidos aguardando resposta. Aguarde o retorno do profissional.';
  end if;
  if (select count(*) from cf_booking_requests where owner_id = s.owner_id and created_at > now() - interval '1 day') >= 40 then
    return 'Muitos pedidos hoje. Tente mais tarde ou fale direto com o profissional.';
  end if;
  insert into cf_booking_requests(owner_id, name, phone, email, service, date, time, note)
  values (s.owner_id, left(trim(p_name), 80), digits, mail, left(coalesce(p_service, ''), 60), p_date, p_time, left(coalesce(p_note, ''), 300));
  return 'ok';
end;
$function$;

grant execute on function public.cf_request_booking(text, text, text, text, date, text, text, text) to anon, authenticated;
