-- Who recorded the expense (for push: never notify the creator; only others).
alter table public.expenses
  add column if not exists created_by uuid references public.users(id);

-- Backfill legacy rows (best guess: payer recorded the expense).
update public.expenses
set created_by = paid_by
where created_by is null;

-- Per-device preference for custom APNs sounds (money_in.caf / money_out.caf vs default).
alter table public.users
  add column if not exists push_custom_sound_enabled boolean not null default true;
