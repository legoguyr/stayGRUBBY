-- Smart Collections (November 18, 2026; FOOD_ARCHITECTURE §11).
-- A collection is an organizational label on a Dish ("Risotto", "Holiday Cooking"),
-- never a folder record: membership and counts are derived from Dishes. One column
-- on the existing canonical `dishes` row, synced through the existing cooking
-- outbox only when the Dish changes. Growth: at most 20 short labels per Dish
-- (bounded by the check below); canonical Dish data, retained with the Dish.
-- Older clients omit `collections`, which leaves the stored value unchanged. The Dish
-- upsert lives in apply_cooking_operation_model_legacy (wrapped by the ranking guard).
-- Restore sends `collections` (null when empty); its absence means an older server.
begin;

create function staygrubby.valid_dish_collections(value text[]) returns boolean
language sql immutable set search_path='' as $$
 select coalesce(cardinality(value),0)<=20 and not exists(
  select 1 from unnest(coalesce(value,'{}'::text[])) label
  where label is null or length(btrim(label))=0 or length(label)>40 or label<>btrim(label))
$$;
revoke all on function staygrubby.valid_dish_collections(text[]) from public,anon,authenticated;
alter table staygrubby.dishes add column collections text[] not null default '{}'
 check (staygrubby.valid_dish_collections(collections));

do $apply$
declare apply_body text:=pg_get_functiondef('staygrubby.apply_cooking_operation_model_legacy(jsonb)'::regprocedure);
 open_body text:=pg_get_functiondef('staygrubby.open_account_library()'::regprocedure);
 columns constant text:='source_id,cuisine,public_description,private_notes)';
 vals constant text:=$v$data->>'publicDescription',data->>'privateNotes')$v$;
 notes_update constant text:=$u$private_notes=case when data ? 'privateNotes' then excluded.private_notes else current.private_notes end
$u$;
 current_tuple constant text:='current.public_description,current.private_notes) is distinct from';
 excluded_tuple constant text:=$t$case when data ? 'privateNotes' then excluded.private_notes else current.private_notes end);$t$;
 text_guard constant text:=$g$then raise exception 'Invalid Dish text' using errcode='22023'; end if;$g$;
 export constant text:=$e$'publicDescription',r.public_description,'privateNotes',r.private_notes)$e$;
begin
 if strpos(apply_body,columns)=0 or strpos(apply_body,vals)=0 or strpos(apply_body,notes_update)=0
  or strpos(apply_body,current_tuple)=0 or strpos(apply_body,excluded_tuple)=0 or strpos(apply_body,text_guard)=0
  or strpos(open_body,export)=0 then
  raise exception 'Unexpected cooking sync predecessor';
 end if;
 apply_body:=replace(apply_body,text_guard,text_guard||$c$
   if data ? 'collections' and (jsonb_typeof(data->'collections') is distinct from 'array'
     or exists(select 1 from jsonb_array_elements(data->'collections') e where jsonb_typeof(e)<>'string')
     or not staygrubby.valid_dish_collections(array(select jsonb_array_elements_text(data->'collections'))))
   then raise exception 'Invalid Dish collections' using errcode='22023'; end if;$c$);
 apply_body:=replace(apply_body,columns,'source_id,cuisine,public_description,private_notes,collections)');
 apply_body:=replace(apply_body,vals,$v$data->>'publicDescription',data->>'privateNotes',case when data ? 'collections' then array(select jsonb_array_elements_text(data->'collections')) else '{}'::text[] end)$v$);
 apply_body:=replace(apply_body,notes_update,rtrim(notes_update,E'\n')||$u$,
     collections=case when data ? 'collections' then excluded.collections else current.collections end
$u$);
 apply_body:=replace(apply_body,current_tuple,'current.public_description,current.private_notes,current.collections) is distinct from');
 apply_body:=replace(apply_body,excluded_tuple,$t$case when data ? 'privateNotes' then excluded.private_notes else current.private_notes end,case when data ? 'collections' then excluded.collections else current.collections end);$t$);
 execute apply_body;
 execute replace(open_body,export,$e$'publicDescription',r.public_description,'privateNotes',r.private_notes,'collections',case when cardinality(r.collections)>0 then to_jsonb(r.collections) end)$e$);
end $apply$;

notify pgrst,'reload schema';
commit;
