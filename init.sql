-- recall 回忆相册 · 云端数据初始化（在 Supabase SQL Editor 中运行一次）
create table if not exists public.wall (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  author text not null default '',
  note text not null default '',
  date timestamptz not null default now(),
  mono text not null default '',
  storage_path text not null,
  owner uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.wall enable row level security;
drop policy if exists "wall_read" on public.wall;
create policy "wall_read" on public.wall for select using (true);
drop policy if exists "wall_write" on public.wall;
create policy "wall_write" on public.wall for insert to authenticated with check (true);
drop policy if exists "wall_edit" on public.wall;
create policy "wall_edit" on public.wall for update to authenticated using (auth.uid() = owner);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  wall_id uuid not null references public.wall(id) on delete cascade,
  author text not null default '匿名',
  text text not null,
  created_at timestamptz not null default now()
);
alter table public.comments enable row level security;
drop policy if exists "cmt_read" on public.comments;
create policy "cmt_read" on public.comments for select using (true);
drop policy if exists "cmt_write" on public.comments;
create policy "cmt_write" on public.comments for insert to authenticated with check (true);

insert into storage.buckets (id, name, public) values ('photos', 'photos', true)
on conflict (id) do update set public = true;
drop policy if exists "img_read" on storage.objects;
create policy "img_read" on storage.objects for select using (bucket_id = 'photos');
drop policy if exists "img_write" on storage.objects;
create policy "img_write" on storage.objects for insert to authenticated with check (bucket_id = 'photos');
