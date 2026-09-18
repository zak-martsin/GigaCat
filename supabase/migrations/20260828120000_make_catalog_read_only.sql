-- GigaCat v1 exposes only the server-owned catalog. Keep catalog content read-only
-- for app clients while retaining authenticated SELECT access behind RLS.
revoke insert, update, delete
on table public.workout_programs
from authenticated;

revoke insert (
    id,
    author_id,
    target_audience,
    title,
    description,
    tags,
    is_active
)
on table public.workout_programs
from authenticated;

revoke update (
    target_audience,
    title,
    description,
    tags,
    is_active
)
on table public.workout_programs
from authenticated;

revoke insert, update, delete
on table public.workout_days
from authenticated;

revoke insert (
    id,
    program_id,
    title,
    order_index
)
on table public.workout_days
from authenticated;

revoke update (
    program_id,
    title,
    order_index
)
on table public.workout_days
from authenticated;

revoke insert, update, delete
on table public.workout_day_exercises
from authenticated;

revoke insert (
    id,
    workout_day_id,
    exercise_id,
    target_sets,
    target_reps,
    order_index
)
on table public.workout_day_exercises
from authenticated;

revoke update (
    workout_day_id,
    exercise_id,
    target_sets,
    target_reps,
    order_index
)
on table public.workout_day_exercises
from authenticated;

drop policy if exists "Users can create their programs"
on public.workout_programs;

drop policy if exists "Users can update their programs"
on public.workout_programs;

drop policy if exists "Users can delete their programs"
on public.workout_programs;

drop policy if exists "Authors can create workout days"
on public.workout_days;

drop policy if exists "Authors can update workout days"
on public.workout_days;

drop policy if exists "Authors can delete workout days"
on public.workout_days;

drop policy if exists "Authors can create day exercises"
on public.workout_day_exercises;

drop policy if exists "Authors can update day exercises"
on public.workout_day_exercises;

drop policy if exists "Authors can delete day exercises"
on public.workout_day_exercises;

-- Recommendation/rating fields belonged to the removed marketplace UI and are
-- not part of the v1 catalog contract.
alter table public.workout_programs
drop column if exists is_recommended,
drop column if exists is_popular,
drop column if exists rate_score;
