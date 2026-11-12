-- These two programs delegate workload to the user's goal/level policy.
-- Other program prescriptions, repetitions and user profiles remain unchanged.
update public.workout_day_exercises as assignment
set target_sets = null
from public.workout_days as day
join public.workout_programs as program on program.id = day.program_id
where assignment.workout_day_id = day.id
  and program.author_id is null
  and program.id in (
      '20000000-0000-0000-0000-000000000001'::uuid,
      '20000000-0000-0000-0000-000000000002'::uuid
  );

comment on column public.workout_day_exercises.target_sets is
    'Optional program set override. NULL delegates to the client goal/level recommendation (fallback: 2).';
