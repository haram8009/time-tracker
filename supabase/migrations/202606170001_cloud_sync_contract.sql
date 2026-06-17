-- Cloud sync contract for Google-authenticated users.
-- Guest data remains local-only; anonymous auth is not used by this feature.

create extension if not exists pgcrypto;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  color_hex text not null,
  is_preset boolean not null default false,
  is_hidden boolean not null default false,
  sort_order integer not null default 0,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint categories_owner_id_id_unique unique (owner_id, id),
  constraint categories_name_not_blank check (length(btrim(name)) > 0),
  constraint categories_color_hex_format check (color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

create table if not exists public.time_blocks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid not null,
  date date not null,
  start_minute integer not null,
  end_minute integer not null,
  note text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint time_blocks_owner_id_id_unique unique (owner_id, id),
  constraint time_blocks_category_owner_fkey
    foreign key (owner_id, category_id)
    references public.categories(owner_id, id)
    on update cascade
    on delete restrict,
  constraint time_blocks_start_bounds check (
    start_minute >= 0 and start_minute < 1440
  ),
  constraint time_blocks_end_bounds check (
    end_minute > 0 and end_minute <= 1440
  ),
  constraint time_blocks_valid_range check (start_minute < end_minute),
  constraint time_blocks_ten_minute_grid check (
    start_minute % 10 = 0 and end_minute % 10 = 0
  )
);

create table if not exists public.user_settings (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  notification_enabled boolean not null default true,
  sleep_start_minute integer not null default 1380,
  sleep_end_minute integer not null default 420,
  updated_at timestamptz not null default now(),
  constraint user_settings_sleep_start_bounds check (
    sleep_start_minute >= 0 and sleep_start_minute < 1440
  ),
  constraint user_settings_sleep_end_bounds check (
    sleep_end_minute >= 0 and sleep_end_minute < 1440
  ),
  constraint user_settings_ten_minute_grid check (
    sleep_start_minute % 10 = 0 and sleep_end_minute % 10 = 0
  )
);

create index if not exists categories_owner_updated_idx
  on public.categories (owner_id, updated_at);

create index if not exists categories_owner_visible_idx
  on public.categories (owner_id, sort_order, id)
  where deleted_at is null and is_hidden = false;

create index if not exists time_blocks_owner_updated_idx
  on public.time_blocks (owner_id, updated_at);

create index if not exists time_blocks_owner_date_start_idx
  on public.time_blocks (owner_id, date, start_minute)
  where deleted_at is null;

create index if not exists time_blocks_owner_category_idx
  on public.time_blocks (owner_id, category_id);

create index if not exists user_settings_owner_updated_idx
  on public.user_settings (owner_id, updated_at);

alter table public.categories enable row level security;
alter table public.time_blocks enable row level security;
alter table public.user_settings enable row level security;

create policy "categories_owner_select"
  on public.categories
  for select
  to authenticated
  using (owner_id = (select auth.uid()));

create policy "categories_owner_insert"
  on public.categories
  for insert
  to authenticated
  with check (owner_id = (select auth.uid()));

create policy "categories_owner_update"
  on public.categories
  for update
  to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "categories_owner_delete"
  on public.categories
  for delete
  to authenticated
  using (owner_id = (select auth.uid()));

create policy "time_blocks_owner_select"
  on public.time_blocks
  for select
  to authenticated
  using (owner_id = (select auth.uid()));

create policy "time_blocks_owner_insert"
  on public.time_blocks
  for insert
  to authenticated
  with check (owner_id = (select auth.uid()));

create policy "time_blocks_owner_update"
  on public.time_blocks
  for update
  to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "time_blocks_owner_delete"
  on public.time_blocks
  for delete
  to authenticated
  using (owner_id = (select auth.uid()));

create policy "user_settings_owner_select"
  on public.user_settings
  for select
  to authenticated
  using (owner_id = (select auth.uid()));

create policy "user_settings_owner_insert"
  on public.user_settings
  for insert
  to authenticated
  with check (owner_id = (select auth.uid()));

create policy "user_settings_owner_update"
  on public.user_settings
  for update
  to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "user_settings_owner_delete"
  on public.user_settings
  for delete
  to authenticated
  using (owner_id = (select auth.uid()));
