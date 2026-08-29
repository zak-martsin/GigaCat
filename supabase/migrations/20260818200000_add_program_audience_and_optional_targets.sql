alter table public.workout_programs
add column target_audience text;

alter table public.workout_programs
add constraint workout_programs_target_audience_is_supported
check (
    target_audience is null
    or target_audience in ('men', 'women', 'unisex')
);

-- Audience is editable program content, unlike recommendation metadata.
grant insert (target_audience)
on table public.workout_programs
to authenticated;

grant update (target_audience)
on table public.workout_programs
to authenticated;

-- A base catalog program can define exercise order without prescribing volume.
-- Goal- and level-specific prescriptions can be added independently later.
alter table public.workout_day_exercises
alter column target_sets drop not null,
alter column target_reps drop not null;

alter table public.workout_day_exercises
add constraint workout_day_exercises_targets_are_complete
check (
    (target_sets is null and target_reps is null)
    or (target_sets is not null and target_reps is not null)
);
