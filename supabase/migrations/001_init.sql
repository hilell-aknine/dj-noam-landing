-- ==========================================================
-- דיג'יי נועם לויכטר · בסיס נתונים מאוחד
-- אתר + CRM + Pic2QR על פרויקט סופהבייס אחד
-- 24.09.2026
-- ==========================================================

create extension if not exists pgcrypto;

-- ==========================================================
-- ENUMS
-- ==========================================================
do $$ begin
  create type lead_status as enum ('new','contacted','quoted','booked','done','lost');
exception when duplicate_object then null; end $$;

do $$ begin
  create type event_kind as enum ('wedding','bar_mitzvah','bat_mitzvah','corporate','henna','birthday','other');
exception when duplicate_object then null; end $$;

-- ==========================================================
-- 1. לידים (הטופס באתר נוחת כאן)
-- ==========================================================
create table if not exists public.leads (
  id               uuid primary key default gen_random_uuid(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  full_name        text not null,
  phone            text not null,
  email            text,

  event_kind       event_kind not null default 'other',
  event_date       date,
  venue            text,
  guests_estimate  int,

  budget_min       int,
  budget_max       int,

  source           text not null default 'website',
  message          text,

  status           lead_status not null default 'new',
  owner_note       text
);

create index if not exists leads_status_created_idx on public.leads (status, created_at desc);
create index if not exists leads_event_date_idx     on public.leads (event_date);
create index if not exists leads_phone_idx          on public.leads (phone);

-- ==========================================================
-- 2. יומן פעילות מול הליד (זה מה שהופך רשימה ל-CRM)
-- ==========================================================
create table if not exists public.lead_activities (
  id          uuid primary key default gen_random_uuid(),
  lead_id     uuid not null references public.leads(id) on delete cascade,
  created_at  timestamptz not null default now(),
  kind        text not null check (kind in ('call','whatsapp','meeting','quote','payment','note')),
  body        text,
  amount      numeric(10,2)
);

create index if not exists lead_activities_lead_idx on public.lead_activities (lead_id, created_at desc);

-- ==========================================================
-- 3. Pic2QR — רישום התמונות שהועלו
-- ==========================================================
create table if not exists public.qr_images (
  id             uuid primary key default gen_random_uuid(),
  created_at     timestamptz not null default now(),
  storage_path   text not null unique,
  public_url     text not null,
  original_name  text,
  mime           text,
  size_bytes     bigint,
  scan_count     int not null default 0
);

create index if not exists qr_images_created_idx on public.qr_images (created_at desc);

-- ==========================================================
-- updated_at אוטומטי
-- ==========================================================
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists leads_touch_updated_at on public.leads;
create trigger leads_touch_updated_at
  before update on public.leads
  for each row execute function public.touch_updated_at();

-- ==========================================================
-- RLS — נעול כברירת מחדל, נכשל סגור
-- אין שום policy ל-anon. כתיבה מהטופס הציבורי עוברת אך ורק
-- דרך Edge Function עם service_role. אסור WITH CHECK (true).
-- ==========================================================
alter table public.leads           enable row level security;
alter table public.lead_activities enable row level security;
alter table public.qr_images       enable row level security;

-- נועם המחובר רואה ומנהל הכל
drop policy if exists leads_authenticated_all on public.leads;
create policy leads_authenticated_all on public.leads
  for all to authenticated using (true) with check (true);

drop policy if exists lead_activities_authenticated_all on public.lead_activities;
create policy lead_activities_authenticated_all on public.lead_activities
  for all to authenticated using (true) with check (true);

drop policy if exists qr_images_authenticated_all on public.qr_images;
create policy qr_images_authenticated_all on public.qr_images
  for all to authenticated using (true) with check (true);

-- ==========================================================
-- אחסון — באקט התמונות של Pic2QR
-- ==========================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pics','pics', true, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- קריאה ציבורית: זה מה שגורם ל-QR להיסרק מכל טלפון
drop policy if exists pics_public_read on storage.objects;
create policy pics_public_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'pics');

-- העלאה: רק מחובר. העלאה אנונימית תעבור דרך Edge Function.
drop policy if exists pics_authenticated_upload on storage.objects;
create policy pics_authenticated_upload on storage.objects
  for insert to authenticated
  with check (bucket_id = 'pics');
