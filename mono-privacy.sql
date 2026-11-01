-- recall 独白公开/私密开关（在 Supabase SQL Editor 中运行一次）
-- 私密独白只有照片主人登录后可见，其他人（含管理员）走任何接口都拿不到

-- 1. wall 表加公开开关（默认公开，不影响现有内容）
alter table public.wall add column if not exists mono_public boolean not null default true;

-- 2. 独白独立成表（RLS 硬隔离）
create table if not exists public.wall_monos (
  wall_id uuid primary key references public.wall(id) on delete cascade,
  mono text not null default ''
);
alter table public.wall_monos enable row level security;

-- 3. 迁移现有独白
insert into public.wall_monos (wall_id, mono)
select id, mono from public.wall where mono is not null and mono <> ''
on conflict (wall_id) do nothing;

-- 4. 独白读取：公开照片的独白大家可读，私密的只有照片主人可读
drop policy if exists "wm_read" on public.wall_monos;
create policy "wm_read" on public.wall_monos for select using (
  exists (select 1 from public.wall w where w.id = wall_monos.wall_id and (w.mono_public or w.owner = auth.uid()))
);

-- 5. 独白写入：仅照片主人
drop policy if exists "wm_write" on public.wall_monos;
create policy "wm_write" on public.wall_monos for insert to authenticated with check (
  exists (select 1 from public.wall w where w.id = wall_id and w.owner = auth.uid())
);
drop policy if exists "wm_edit" on public.wall_monos;
create policy "wm_edit" on public.wall_monos for update to authenticated using (
  exists (select 1 from public.wall w where w.id = wall_monos.wall_id and w.owner = auth.uid())
);

-- 6. 留言绑定公开状态：私密照片的留言仅主人可见，且只有公开照片能被留言
drop policy if exists "cmt_read" on public.comments;
create policy "cmt_read" on public.comments for select using (
  exists (select 1 from public.wall w where w.id = comments.wall_id and (w.mono_public or w.owner = auth.uid()))
);
drop policy if exists "cmt_write" on public.comments;
create policy "cmt_write" on public.comments for insert to authenticated with check (
  exists (select 1 from public.wall w where w.id = wall_id and w.mono_public)
);

-- 说明：wall.mono 旧列暂时保留（新代码不再读写）；确认新版本运行正常后，
-- 可选执行：alter table public.wall drop column if exists mono;
