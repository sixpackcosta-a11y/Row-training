-- V142: ocultación reversible de resultados ErgData que no corresponden a la
-- planificación. No modifica ni elimina sesiones planificadas.
alter table public.concept2_results
  add column if not exists hidden boolean not null default false;
grant select,update on table public.concept2_results to service_role;

do $$
begin
  if not has_table_privilege('service_role','public.concept2_results','update') then
    raise exception 'V142: falta UPDATE de service_role sobre concept2_results';
  end if;
end $$;
