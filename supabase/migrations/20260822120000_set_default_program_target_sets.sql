-- Default catalog programs prescribe two sets while repetitions remain
-- available for future goal- and level-specific recommendations.
alter table public.workout_day_exercises
drop constraint workout_day_exercises_targets_are_complete;

update public.workout_day_exercises as assignment
set target_sets = 2
from public.workout_days as day
join public.workout_programs as program
  on program.id = day.program_id
where assignment.workout_day_id = day.id
  and program.author_id is null;
