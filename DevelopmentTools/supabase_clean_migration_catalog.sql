-- Read-only structural inventory. Run against an explicitly verified project.
-- Function definitions are represented by digests. No user records are returned.
with app_tables as (
 select c.oid,n.nspname,c.relname,c.relrowsecurity,c.relforcerowsecurity
 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('staygrubby','development','api','public') and c.relkind in ('r','p')
), func as (
 select n.nspname schema_name,p.proname name,pg_get_function_identity_arguments(p.oid) args,pg_get_function_result(p.oid) result_type,
 p.prosecdef security_definer,p.provolatile volatility,p.proconfig config,md5(pg_get_functiondef(p.oid)) definition_md5,
 has_function_privilege('anon',p.oid,'EXECUTE') anon_execute,has_function_privilege('authenticated',p.oid,'EXECUTE') authenticated_execute,
 has_function_privilege('service_role',p.oid,'EXECUTE') service_execute, (p.prosrc ~* '(40001|40P01)') mentions_retry_code
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('staygrubby','development','api','public') and p.prokind in ('f','p')
), table_defs as (
 select t.nspname schema_name,t.relname name,t.relrowsecurity rls,t.relforcerowsecurity force_rls,
 (select jsonb_agg(jsonb_build_array(a.attname,format_type(a.atttypid,a.atttypmod),a.attnotnull,a.attidentity,a.attgenerated,pg_get_expr(d.adbin,d.adrelid)) order by a.attnum)
 from pg_attribute a left join pg_attrdef d on d.adrelid=t.oid and d.adnum=a.attnum where a.attrelid=t.oid and a.attnum>0 and not a.attisdropped) columns,
 (select jsonb_agg(jsonb_build_array(x.conname,pg_get_constraintdef(x.oid,true),x.convalidated) order by x.conname) from pg_constraint x where x.conrelid=t.oid) constraints,
 (select jsonb_agg(pg_get_indexdef(i.indexrelid) order by ci.relname) from pg_index i join pg_class ci on ci.oid=i.indexrelid where i.indrelid=t.oid) indexes,
 (select jsonb_agg(r.name||':'||v.name order by r.name,v.name) from (values('anon'),('authenticated'),('service_role')) r(name) cross join (values('SELECT'),('INSERT'),('UPDATE'),('DELETE')) v(name) where has_table_privilege(r.name,t.oid,v.name)) dml
 from app_tables t
), trig as (
 select n.nspname schema_name,c.relname table_name,t.tgname name,t.tgenabled enabled,pg_get_triggerdef(t.oid,true) definition
 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
 join pg_proc p on p.oid=t.tgfoid join pg_namespace fn on fn.oid=p.pronamespace where not t.tgisinternal
 and (n.nspname in ('staygrubby','development','api','public') or n.nspname in ('auth','storage') and fn.nspname in ('staygrubby','development','api','public'))
), seq as (
 select schemaname,sequencename,data_type::text,start_value,increment_by,cycle,last_value from pg_sequences where schemaname in ('staygrubby','development','api','public')
) select
 (select coalesce(jsonb_agg(to_jsonb(f) order by schema_name,name,args),'[]') from func f) functions,
 (select coalesce(jsonb_agg(to_jsonb(t) order by schema_name,name),'[]') from table_defs t) tables,
 (select coalesce(jsonb_agg(to_jsonb(x) order by schemaname,tablename,policyname),'[]') from pg_policies x where schemaname in ('staygrubby','development','api','public','storage','auth','realtime')) policies,
 (select coalesce(jsonb_agg(to_jsonb(t) order by schema_name,table_name,name),'[]') from trig t) triggers,
 (select coalesce(jsonb_agg(to_jsonb(s) order by schemaname,sequencename),'[]') from seq s) sequences;
