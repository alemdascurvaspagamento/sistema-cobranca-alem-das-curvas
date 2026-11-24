-- Léguno: estorno, chargeback e cancelamento no Asaas + histórico da assinatura.
-- Só acrescenta regras; não apaga dados. Não mexe nas tabelas do sistema Pessoal.

-- 1) Novos estados de pagamento (os antigos continuam valendo).
alter table public.cf_saas_payments drop constraint if exists cf_saas_payments_status_check;
alter table public.cf_saas_payments add constraint cf_saas_payments_status_check
  check (status = any (array['pending','confirmed','received','overdue','refunded','deleted',
                             'refund_pending','partially_refunded','chargeback']));

-- 2) Histórico: cada mudança na ficha de assinatura fica registrada (antes, depois, quando).
create table if not exists public.cf_subscription_history (
  id bigint generated always as identity primary key,
  owner_id uuid not null,
  changed_at timestamptz not null default now(),
  source text not null default '',
  old_row jsonb,
  new_row jsonb
);
alter table public.cf_subscription_history enable row level security;
-- Sem regras de leitura: só o servidor (service_role) e o banco veem.
create index if not exists cf_subscription_history_owner on public.cf_subscription_history (owner_id, changed_at desc);

create or replace function public._cf_subscription_log()
returns trigger language plpgsql security definer set search_path to '' as $$
begin
  if tg_op = 'UPDATE' and to_jsonb(old) - 'updated_at' = to_jsonb(new) - 'updated_at' then
    return new;
  end if;
  insert into public.cf_subscription_history (owner_id, source, old_row, new_row)
  values (new.owner_id, coalesce(current_setting('cf.source', true), ''),
          case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  return new;
end $$;
revoke all on function public._cf_subscription_log() from public, anon, authenticated;

drop trigger if exists cf_subscriptions_log on public.cf_subscriptions;
create trigger cf_subscriptions_log after insert or update on public.cf_subscriptions
  for each row execute function public._cf_subscription_log();

-- 3) Avisos de pagamento do Asaas: agora estorno e chargeback retiram o acesso pago.
create or replace function public.cf_asaas_apply(p_event text, p_payment jsonb)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare
  pid text := p_payment ->> 'id';
  cust text := p_payment ->> 'customer';
  sub_id text := p_payment ->> 'subscription';
  ext text := p_payment ->> 'externalReference';
  v_owner uuid;
  v_status text;
  v_amount numeric := coalesce((p_payment ->> 'value')::numeric, 0);
  v_due date := nullif(p_payment ->> 'dueDate', '')::date;
  v_paid timestamptz := coalesce(nullif(p_payment ->> 'confirmedDate', '')::timestamptz,
                                 nullif(p_payment ->> 'paymentDate', '')::timestamptz);
  s public.cf_subscriptions;
  ck public.cf_checkouts;
  new_end timestamptz;
  v_step interval;
  other_end timestamptz;
  prev_status text;
begin
  if pid is null then raise exception 'pagamento sem identificador'; end if;
  perform set_config('cf.source', 'asaas:' || coalesce(p_event, ''), true);
  if sub_id is not null then
    select * into ck from public.cf_checkouts where asaas_subscription_id = sub_id order by created_at desc limit 1;
    v_owner := ck.owner_id;
  end if;
  if v_owner is null then
    select owner_id into v_owner from public.cf_subscriptions where asaas_customer_id = cust limit 1;
  end if;
  if v_owner is null and ext ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select id into v_owner from auth.users where id = ext::uuid;
  end if;
  v_status := case
    when p_event = 'PAYMENT_DELETED' then 'deleted'
    when p_event = 'PAYMENT_REFUNDED' then 'refunded'
    when p_event = 'PAYMENT_PARTIALLY_REFUNDED' then 'partially_refunded'
    when p_event in ('PAYMENT_CHARGEBACK_REQUESTED', 'PAYMENT_CHARGEBACK_DISPUTE') then 'chargeback'
    when p_event = 'PAYMENT_RECEIVED_IN_CASH_UNDONE' then 'refunded'
    else case p_payment ->> 'status'
      when 'RECEIVED' then 'received' when 'RECEIVED_IN_CASH' then 'received'
      when 'CONFIRMED' then 'confirmed' when 'OVERDUE' then 'overdue'
      when 'REFUNDED' then 'refunded'
      when 'REFUND_REQUESTED' then 'refund_pending' when 'REFUND_IN_PROGRESS' then 'refund_pending'
      when 'CHARGEBACK_REQUESTED' then 'chargeback' when 'CHARGEBACK_DISPUTE' then 'chargeback'
      -- Disputa vencida a favor da empresa: o pagamento volta a valer.
      when 'AWAITING_CHARGEBACK_REVERSAL' then 'received'
      else 'pending' end
  end;
  select * into s from public.cf_subscriptions where owner_id = v_owner;
  -- Aviso atrasado: um "pago" que chega depois do estorno não reativa o pagamento.
  select status into prev_status from public.cf_saas_payments where asaas_payment_id = pid;
  if prev_status in ('refunded', 'chargeback') and v_status in ('received', 'confirmed', 'pending', 'overdue')
     and coalesce(p_event, '') not in ('PAYMENT_RESTORED', 'PAYMENT_AWAITING_CHARGEBACK_REVERSAL') then
    return jsonb_build_object('owner_found', v_owner is not null, 'status', prev_status, 'ignored', true);
  end if;
  insert into public.cf_saas_payments (owner_id, asaas_payment_id, amount, status, due_date, paid_at, plan)
    values (v_owner, pid, v_amount, v_status, v_due, v_paid, coalesce(ck.plan, s.plan))
  on conflict (asaas_payment_id) do update set
    owner_id = coalesce(excluded.owner_id, public.cf_saas_payments.owner_id),
    amount = excluded.amount, status = excluded.status,
    due_date = coalesce(excluded.due_date, public.cf_saas_payments.due_date),
    paid_at = coalesce(excluded.paid_at, public.cf_saas_payments.paid_at),
    updated_at = now();
  if v_owner is not null and s.owner_id is not null and s.status <> 'courtesy' then
    v_step := case when coalesce(ck.cycle, s.cycle) = 'annual' then interval '1 year' else interval '1 month' end;
    if v_status in ('received', 'confirmed') then
      new_end := coalesce(v_due, current_date)::timestamptz + v_step;
      update public.cf_subscriptions set
        status = 'active',
        plan = coalesce(ck.plan, plan),
        cycle = coalesce(ck.cycle, cycle),
        founder = founder or coalesce(ck.founder, false),
        asaas_subscription_id = coalesce(sub_id, asaas_subscription_id),
        asaas_customer_id = coalesce(cust, asaas_customer_id),
        current_period_end = greatest(coalesce(current_period_end, new_end), new_end)
      where owner_id = v_owner;
    elsif v_status = 'overdue' and s.status = 'active' then
      update public.cf_subscriptions set status = 'past_due' where owner_id = v_owner;
    elsif v_status in ('refunded', 'chargeback') then
      -- O acesso pago passa a valer só até onde outros pagamentos válidos cobrem.
      select max(coalesce(p.due_date, p.paid_at::date)::timestamptz + v_step) into other_end
        from public.cf_saas_payments p
       where p.owner_id = v_owner and p.asaas_payment_id <> pid and p.status in ('received', 'confirmed');
      if other_end is not null and other_end > now() then
        update public.cf_subscriptions set status = 'active', current_period_end = other_end where owner_id = v_owner;
      elsif s.trial_ends_at is not null and s.trial_ends_at > now() then
        -- Pagou durante o teste grátis e foi estornado: volta para o teste, até o fim dele.
        update public.cf_subscriptions set status = 'trialing', current_period_end = null where owner_id = v_owner;
      else
        update public.cf_subscriptions set status = 'canceled', current_period_end = now() where owner_id = v_owner;
      end if;
    end if;
  end if;
  return jsonb_build_object('owner_found', v_owner is not null, 'status', v_status);
end $function$;
revoke all on function public.cf_asaas_apply(text, jsonb) from public, anon, authenticated;
grant execute on function public.cf_asaas_apply(text, jsonb) to service_role;

-- 4) Avisos de assinatura do Asaas: assinatura removida ou inativada = cancelada.
--    O acesso continua até o fim do período já pago (regra de _cf_state_of).
create or replace function public.cf_asaas_subscription_event(p_event text, p_sub jsonb)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare
  v_id text := p_sub ->> 'id';
  n int := 0;
begin
  if v_id is null then raise exception 'assinatura sem identificador'; end if;
  perform set_config('cf.source', 'asaas:' || coalesce(p_event, ''), true);
  if p_event in ('SUBSCRIPTION_DELETED', 'SUBSCRIPTION_INACTIVATED') then
    -- Só a assinatura que está em uso; tentativas antigas apagadas pelo checkout são ignoradas.
    update public.cf_subscriptions set status = 'canceled'
     where asaas_subscription_id = v_id and status in ('active', 'past_due');
    get diagnostics n = row_count;
  end if;
  return jsonb_build_object('event', p_event, 'updated', n);
end $function$;
revoke all on function public.cf_asaas_subscription_event(text, jsonb) from public, anon, authenticated;
grant execute on function public.cf_asaas_subscription_event(text, jsonb) to service_role;
