-- Read-only Storage inventory. Output contains private object paths and hashes.
-- Save the result only to an owner-restricted directory outside Git.
with dev as (select l.account_id from staygrubby.auth_account_links l join development.recipe_test_identity d using(auth_user_id) where d.singleton),
refs(bucket_id,name,reason,expected_bytes,expected_sha256) as (
select 'cooking-photos',k.name,case when m.deleted_at is not null or a.deleted_at is not null or d.deleted_at is not null then 'retired cook' when b.ready then 'ready active cook' else 'pending active cook' end,k.bytes,k.sha
from staygrubby.media_backups b join staygrubby.media m on (m.account_id,m.id)=(b.account_id,b.media_id)
join staygrubby.cooking_attempts a on (a.account_id,a.id)=(m.account_id,m.attempt_id) join staygrubby.dishes d on (d.account_id,d.id)=(a.account_id,a.dish_id)
cross join lateral(values(b.display_key,b.display_bytes,b.display_hash),(b.thumbnail_key,b.thumbnail_bytes,b.thumbnail_hash)) k(name,bytes,sha)
union all select 'profile-photos',k.path,k.reason,null,null from staygrubby.profiles p cross join lateral(values(p.avatar_path,'published avatar'),(p.avatar_draft_path,'draft avatar')) k(path,reason) where k.path is not null
union all select 'social-photos',photo_path,case when deleted_at is not null then 'retired post' when published and photo_ready then 'published post' else 'pending post' end,null,null from staygrubby.social_posts where photo_path is not null
union all select 'recipe-photos',p.path,case when exists(select 1 from staygrubby.recipes r where r.content->>'photoID'=p.id::text) then 'current recipe' when exists(select 1 from staygrubby.recipe_revisions r where r.content->>'photoID'=p.id::text) then 'recipe revision' when exists(select 1 from staygrubby.recipe_cooks c where c.snapshot->>'photoID'=p.id::text and c.completed_at is not null) then 'completed recipe snapshot' when exists(select 1 from staygrubby.recipe_cooks c where c.snapshot->>'photoID'=p.id::text) then 'pending recipe snapshot' else 'unreferenced recipe registration' end,p.byte_count,p.sha256 from staygrubby.recipe_photos p
), objects as (
select o.bucket_id,o.name path,(o.metadata->>'size')::bigint bytes,o.metadata->>'mimetype' mime,coalesce(o.metadata->>'eTag',o.metadata->>'etag') etag,r.reason,r.expected_bytes,r.expected_sha256,
o.owner_id is not null has_owner,coalesce(l.auth_user_id::text=o.owner_id,false) owner_matches_path,dev.account_id is not null marked_development
from storage.objects o left join refs r on (r.bucket_id,r.name)=(o.bucket_id,o.name) left join staygrubby.auth_account_links l on l.account_id::text=split_part(o.name,'/',1)
left join dev on dev.account_id=l.account_id
) select (select jsonb_agg(to_jsonb(o) order by bucket_id,path) from objects o) objects,
(select jsonb_agg(to_jsonb(b) order by id) from (select id,name,public,file_size_limit,allowed_mime_types from storage.buckets) b) buckets,
(select jsonb_agg(to_jsonb(r) order by bucket_id,name) from refs r where not exists(select 1 from storage.objects o where (o.bucket_id,o.name)=(r.bucket_id,r.name))) missing_refs;
