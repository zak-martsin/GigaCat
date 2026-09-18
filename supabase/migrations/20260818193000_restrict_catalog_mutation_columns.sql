-- RLS controls which rows an author can mutate. Column grants additionally
-- protect server-owned metadata and timestamps inside those rows.
revoke insert, update
on table public.workout_programs
from authenticated;

grant insert (
    id,
    author_id,
    title,
    description,
    tags,
    is_active
)
on table public.workout_programs
to authenticated;

grant update (
    title,
    description,
    tags,
    is_active
)
on table public.workout_programs
to authenticated;

revoke insert, update
on table public.workout_days
from authenticated;

grant insert (
    id,
    program_id,
    title,
    order_index
)
on table public.workout_days
to authenticated;

grant update (
    program_id,
    title,
    order_index
)
on table public.workout_days
to authenticated;

revoke insert, update
on table public.workout_day_exercises
from authenticated;

grant insert (
    id,
    workout_day_id,
    exercise_id,
    target_sets,
    target_reps,
    order_index
)
on table public.workout_day_exercises
to authenticated;

grant update (
    workout_day_id,
    exercise_id,
    target_sets,
    target_reps,
    order_index
)
on table public.workout_day_exercises
to authenticated;
