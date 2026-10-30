-- Applied to Supabase project MDBadmintonLive. Kept here for reproducibility.
create extension if not exists pgcrypto;
create table if not exists public.shuttleai_matches (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 title text not null default 'การแข่งขันใหม่', court_name text not null default 'สนาม 1', side_a_name text not null default 'ฝั่ง A', side_b_name text not null default 'ฝั่ง B',
 points_a integer not null default 0 check(points_a>=0), points_b integer not null default 0 check(points_b>=0), games_a integer not null default 0 check(games_a>=0), games_b integer not null default 0 check(games_b>=0),
 current_server text check(current_server in ('A','B') or current_server is null), status text not null default 'setup' check(status in ('setup','live','paused','finished')),
 scoring_mode text not null default 'ai_auto' check(scoring_mode in ('ai_auto','review')), ai_enabled boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists public.shuttleai_score_events (
 id uuid primary key default gen_random_uuid(), match_id uuid not null references public.shuttleai_matches(id) on delete cascade, owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 event_key text not null, source text not null check(source in ('ai','manual','undo','system')), point_to text check(point_to in ('A','B') or point_to is null), confidence numeric(5,4) check(confidence between 0 and 1), reason text,
 before_state jsonb not null default '{}'::jsonb, after_state jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), unique(match_id,event_key));
create table if not exists public.shuttleai_stream_sessions (
 id uuid primary key default gen_random_uuid(), match_id uuid not null references public.shuttleai_matches(id) on delete cascade, owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 source text not null check(source in ('android_camera','obs_rtmp','obs_srt','file_test')), status text not null default 'created' check(status in ('created','connecting','live','reconnecting','stopped','error')),
 ingest_url text, started_at timestamptz, stopped_at timestamptz, last_heartbeat_at timestamptz, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());
create table if not exists public.shuttleai_ai_events (
 id uuid primary key default gen_random_uuid(), match_id uuid not null references public.shuttleai_matches(id) on delete cascade, owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 event_key text not null, event_type text not null, confidence numeric(5,4) check(confidence between 0 and 1), decision text not null default 'observe' check(decision in ('observe','candidate','accepted','rejected','uncertain')),
 payload jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), unique(match_id,event_key));
create index if not exists shuttleai_matches_owner_updated_idx on public.shuttleai_matches(owner_id,updated_at desc);
create index if not exists shuttleai_score_events_match_created_idx on public.shuttleai_score_events(match_id,created_at desc);
create index if not exists shuttleai_stream_sessions_match_created_idx on public.shuttleai_stream_sessions(match_id,created_at desc);
create index if not exists shuttleai_ai_events_match_created_idx on public.shuttleai_ai_events(match_id,created_at desc);
alter table public.shuttleai_matches enable row level security; alter table public.shuttleai_score_events enable row level security; alter table public.shuttleai_stream_sessions enable row level security; alter table public.shuttleai_ai_events enable row level security;
drop policy if exists shuttleai_matches_select_own on public.shuttleai_matches; create policy shuttleai_matches_select_own on public.shuttleai_matches for select to authenticated using((select auth.uid())=owner_id);
drop policy if exists shuttleai_matches_insert_own on public.shuttleai_matches; create policy shuttleai_matches_insert_own on public.shuttleai_matches for insert to authenticated with check((select auth.uid())=owner_id);
drop policy if exists shuttleai_matches_update_own on public.shuttleai_matches; create policy shuttleai_matches_update_own on public.shuttleai_matches for update to authenticated using((select auth.uid())=owner_id) with check((select auth.uid())=owner_id);
drop policy if exists shuttleai_matches_delete_own on public.shuttleai_matches; create policy shuttleai_matches_delete_own on public.shuttleai_matches for delete to authenticated using((select auth.uid())=owner_id);
drop policy if exists shuttleai_score_events_select_own on public.shuttleai_score_events; create policy shuttleai_score_events_select_own on public.shuttleai_score_events for select to authenticated using((select auth.uid())=owner_id);
drop policy if exists shuttleai_score_events_insert_own on public.shuttleai_score_events; create policy shuttleai_score_events_insert_own on public.shuttleai_score_events for insert to authenticated with check((select auth.uid())=owner_id);
drop policy if exists shuttleai_score_events_delete_own on public.shuttleai_score_events; create policy shuttleai_score_events_delete_own on public.shuttleai_score_events for delete to authenticated using((select auth.uid())=owner_id);
drop policy if exists shuttleai_stream_sessions_select_own on public.shuttleai_stream_sessions; create policy shuttleai_stream_sessions_select_own on public.shuttleai_stream_sessions for select to authenticated using((select auth.uid())=owner_id);
drop policy if exists shuttleai_stream_sessions_insert_own on public.shuttleai_stream_sessions; create policy shuttleai_stream_sessions_insert_own on public.shuttleai_stream_sessions for insert to authenticated with check((select auth.uid())=owner_id);
drop policy if exists shuttleai_stream_sessions_update_own on public.shuttleai_stream_sessions; create policy shuttleai_stream_sessions_update_own on public.shuttleai_stream_sessions for update to authenticated using((select auth.uid())=owner_id) with check((select auth.uid())=owner_id);
drop policy if exists shuttleai_ai_events_select_own on public.shuttleai_ai_events; create policy shuttleai_ai_events_select_own on public.shuttleai_ai_events for select to authenticated using((select auth.uid())=owner_id);
drop policy if exists shuttleai_ai_events_insert_own on public.shuttleai_ai_events; create policy shuttleai_ai_events_insert_own on public.shuttleai_ai_events for insert to authenticated with check((select auth.uid())=owner_id);
grant select,insert,update,delete on public.shuttleai_matches to authenticated; grant select,insert,delete on public.shuttleai_score_events to authenticated; grant select,insert,update on public.shuttleai_stream_sessions to authenticated; grant select,insert on public.shuttleai_ai_events to authenticated;
