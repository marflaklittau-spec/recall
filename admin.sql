-- recall 管理员删除权限（在 Supabase SQL Editor 中运行一次）
-- 管理员邮箱：2822214930@qq.com —— 该账号可删除任何照片和留言

-- 管理员可删除任何墙上照片；上传者可删除自己的
drop policy if exists "wall_delete" on public.wall;
create policy "wall_delete" on public.wall for delete to authenticated
  using (auth.jwt()->>'email' = '2822214930@qq.com' or auth.uid() = owner);

-- 管理员可删除任何留言
drop policy if exists "cmt_delete" on public.comments;
create policy "cmt_delete" on public.comments for delete to authenticated
  using (auth.jwt()->>'email' = '2822214930@qq.com');

-- 管理员可删除任何照片文件；上传者可删除自己上传的
drop policy if exists "img_delete" on storage.objects;
create policy "img_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (auth.jwt()->>'email' = '2822214930@qq.com'
    or exists (select 1 from public.wall w where w.storage_path = storage.objects.name and w.owner = auth.uid())));
