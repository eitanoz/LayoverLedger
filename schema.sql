-- Layover Ledger — Supabase schema
-- Run this once in your Supabase project's SQL editor (Project → SQL Editor → New query).
-- It creates the three tables the app needs and locks every row to its owner
-- with Row Level Security, so the anon key embedded in index.html can only
-- ever see or change the signed-in user's own data.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- trips --
create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  currency text not null,
  budget numeric,
  note text,
  created_at bigint not null
);

alter table public.trips enable row level security;

create policy "trips: owner can select" on public.trips
  for select using (auth.uid() = user_id);
create policy "trips: owner can insert" on public.trips
  for insert with check (auth.uid() = user_id);
create policy "trips: owner can update" on public.trips
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "trips: owner can delete" on public.trips
  for delete using (auth.uid() = user_id);

-- ------------------------------------------------------------- expenses --
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trip_id uuid not null references public.trips(id) on delete cascade,
  amount numeric not null,
  category text not null,
  note text,
  date text,
  time text,
  dt text,
  currency text,
  rate numeric,
  converted_amount numeric,
  payment_method text,
  card_id text,
  card_label text,
  created_at bigint not null
);

alter table public.expenses enable row level security;

create policy "expenses: owner can select" on public.expenses
  for select using (auth.uid() = user_id);
create policy "expenses: owner can insert" on public.expenses
  for insert with check (auth.uid() = user_id);
create policy "expenses: owner can update" on public.expenses
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "expenses: owner can delete" on public.expenses
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------- cards --
create table if not exists public.cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at bigint not null
);

alter table public.cards enable row level security;

create policy "cards: owner can select" on public.cards
  for select using (auth.uid() = user_id);
create policy "cards: owner can insert" on public.cards
  for insert with check (auth.uid() = user_id);
create policy "cards: owner can update" on public.cards
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "cards: owner can delete" on public.cards
  for delete using (auth.uid() = user_id);

-- --------------------------------------------------------------- bookings --
-- Hotel / flight / cruise / attraction reservations for a trip. Separate
-- from expenses -- this is what's booked, not what it cost.
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trip_id uuid not null references public.trips(id) on delete cascade,
  type text not null,                 -- 'hotel' | 'flight' | 'cruise' | 'attraction'
  title text not null,
  confirmation_number text,
  start_date date,
  end_date date,
  cancellation_deadline date,
  flight_number text,                 -- flights only, e.g. "TP123"
  last_status jsonb,                  -- cached result from the flight-status function
  notes text,
  created_at bigint not null
);

alter table public.bookings enable row level security;

create policy "bookings: owner can select" on public.bookings
  for select using (auth.uid() = user_id);
create policy "bookings: owner can insert" on public.bookings
  for insert with check (auth.uid() = user_id);
create policy "bookings: owner can update" on public.bookings
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "bookings: owner can delete" on public.bookings
  for delete using (auth.uid() = user_id);

-- ----------------------------------------------------------- realtime --
-- Lets the app get live updates (e.g. if you open it on two devices).
-- Wrapped so re-running this script doesn't error if a table is already
-- in the publication.
do $$
begin
  begin
    alter publication supabase_realtime add table public.trips;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.expenses;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.cards;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.bookings;
  exception when duplicate_object then null;
  end;
end $$;
