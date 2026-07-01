-- Optional dev seed (run manually after migrations)
-- Attaches sample procedures to your oldest home.

with new_proc as (
  insert into public.procedures (home_id, title, category, description, visibility)
  select
    id,
    'Winter shutdown',
    'Seasonal',
    'Prepare the cottage for freezing weather.',
    'guest'::public.visibility
  from public.homes
  order by created_at
  limit 1
  returning id
)
insert into public.procedure_steps (procedure_id, sort_order, title)
select id, ord, title
from new_proc
cross join (values
  (1, 'Drain water lines'),
  (2, 'Shut off propane'),
  (3, 'Clean and empty fridge'),
  (4, 'Lock all doors and windows'),
  (5, 'Set thermostat to 45°F'),
  (6, 'Notify caretaker')
) as s(ord, title);
