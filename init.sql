-- recall 回忆相册 · 云端数据初始化（在 Supabase SQL Editor 中运行一次）
create table if not exists public.wall (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  author text not null default '',
  note text not null default '',
  date timestamptz not null default now(),
  mono_public boolean not null default true,
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

-- 独白独立成表：私密独白只有照片主人可见（RLS 硬隔离）
create table if not exists public.wall_monos (
  wall_id uuid primary key references public.wall(id) on delete cascade,
  mono text not null default ''
);
alter table public.wall_monos enable row level security;
drop policy if exists "wm_read" on public.wall_monos;
create policy "wm_read" on public.wall_monos for select using (
  exists (select 1 from public.wall w where w.id = wall_monos.wall_id and (w.mono_public or w.owner = auth.uid()))
);
drop policy if exists "wm_write" on public.wall_monos;
create policy "wm_write" on public.wall_monos for insert to authenticated with check (
  exists (select 1 from public.wall w where w.id = wall_id and w.owner = auth.uid())
);
drop policy if exists "wm_edit" on public.wall_monos;
create policy "wm_edit" on public.wall_monos for update to authenticated using (
  exists (select 1 from public.wall w where w.id = wall_monos.wall_id and w.owner = auth.uid())
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  wall_id uuid not null references public.wall(id) on delete cascade,
  author text not null default '匿名',
  text text not null,
  created_at timestamptz not null default now()
);
alter table public.comments enable row level security;
drop policy if exists "cmt_read" on public.comments;
create policy "cmt_read" on public.comments for select using (
  exists (select 1 from public.wall w where w.id = comments.wall_id and (w.mono_public or w.owner = auth.uid()))
);
drop policy if exists "cmt_write" on public.comments;
create policy "cmt_write" on public.comments for insert to authenticated with check (
  exists (select 1 from public.wall w where w.id = wall_id and w.mono_public)
);

insert into storage.buckets (id, name, public) values ('photos', 'photos', true)
on conflict (id) do update set public = true;
drop policy if exists "img_read" on storage.objects;
create policy "img_read" on storage.objects for select using (bucket_id = 'photos');
drop policy if exists "img_write" on storage.objects;
create policy "img_write" on storage.objects for insert to authenticated with check (bucket_id = 'photos');

-- ===== 删除权限（把邮箱换成你的管理员账号）=====
-- 管理员可删除任何墙上照片；上传者可删除自己的
drop policy if exists "wall_delete" on public.wall;
create policy "wall_delete" on public.wall for delete to authenticated
  using (auth.jwt()->>'email' = '你的管理员邮箱@example.com' or auth.uid() = owner);
-- 管理员可删除任何留言
drop policy if exists "cmt_delete" on public.comments;
create policy "cmt_delete" on public.comments for delete to authenticated
  using (auth.jwt()->>'email' = '你的管理员邮箱@example.com');
-- 管理员可删除任何照片文件；上传者可删除自己上传的
drop policy if exists "img_delete" on storage.objects;
create policy "img_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (auth.jwt()->>'email' = '你的管理员邮箱@example.com'
    or exists (select 1 from public.wall w where w.storage_path = storage.objects.name and w.owner = auth.uid())));
