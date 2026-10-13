-- Layover Ledger — bookings table repair
--
-- Safe to run any number of times, and safe even if the bookings table
-- already exists with different columns (for example, if this shared
-- Supabase project already had a table named "bookings" from your other
-- app before Layover Ledger's schema.sql ran — "create table if not
-- exists" would have silently skipped creating ours in that case,
-- leaving the old, incompatible table in place). This script creates the
-- table if it's missing, and adds any columns Layover Ledger needs if
-- they aren't already there, without touching or deleting anything else
-- that table might hold.
--
-- Run this in Supabase → SQL Editor → New query → Run.

create extension if not exists pgcrypto;

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid()
);

alter table public.bookings add column if not exists user_id uuid;
alter table public.bookings add column if not exists trip_id uuid;
alter table public.bookings add column if not exists type text;
alter table public.bookings add column if not exists title text;
alter table public.bookings add column if not exists confirmation_number text;
alter table public.bookings add column if not exists start_date date;
alter table public.bookings add column if not exists end_date date;
alter table public.bookings add column if not exists cancellation_deadline date;
alter table public.bookings add column if not exists flight_number text;
alter table public.bookings add column if not exists last_status jsonb;
alter table public.bookings add column if not exists notes text;
alter table public.bookings add column if not exists created_at bigint;

do $$
begin
  begin
    alter table public.bookings
      add constraint bookings_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade;
  exception when duplicate_object then null;
  end;
  begin
    alter table public.bookings
      add constraint bookings_trip_id_fkey foreign key (trip_id) references public.trips(id) on delete cascade;
  exception when duplicate_object then null;
  end;
end $$;

alter table public.bookings enable row level security;

drop policy if exists "bookings: owner can select" on public.bookings;
create policy "bookings: owner can select" on public.bookings
  for select using (auth.uid() = user_id);

drop policy if exists "bookings: owner can insert" on public.bookings;
create policy "bookings: owner can insert" on public.bookings
  for insert with check (auth.uid() = user_id);

drop policy if exists "bookings: owner can update" on public.bookings;
create policy "bookings: owner can update" on public.bookings
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "bookings: owner can delete" on public.bookings;
create policy "bookings: owner can delete" on public.bookings
  for delete using (auth.uid() = user_id);

do $$
begin
  begin
    alter publication supabase_realtime add table public.bookings;
  exception when duplicate_object then null;
  end;
end $$;

-- Quick sanity check: run this separately afterward to see the table's
-- actual columns and confirm everything Layover Ledger needs is there.
-- select column_name, data_type, is_nullable
-- from information_schema.columns
-- where table_schema = 'public' and table_name = 'bookings'
-- order by ordinal_position;
