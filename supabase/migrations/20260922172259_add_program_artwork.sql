alter table public.workout_programs
    add column if not exists artwork_path text,
    add column if not exists artwork_revision integer not null default 0;

update public.workout_programs
set artwork_path = '20000000-0000-0000-0000-000000000001/hero.jpg',
    artwork_revision = 1
where id = '20000000-0000-0000-0000-000000000001';

update public.workout_programs
set artwork_path = '20000000-0000-0000-0000-000000000002/hero.jpg',
    artwork_revision = 1
where id = '20000000-0000-0000-0000-000000000002';

insert into storage.buckets (id, name, public)
values ('program-images', 'program-images', false)
on conflict (id) do update
set public = excluded.public;

drop policy if exists "Authenticated users can read program images"
on storage.objects;

create policy "Authenticated users can read program images"
on storage.objects
for select
to authenticated
using (bucket_id = 'program-images');

-- Keep artwork metadata in the same consistent catalog snapshot as the program structure.
create or replace function public.get_system_catalog_v1()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
select jsonb_build_object(
    'programs', coalesce((
        select jsonb_agg(
            jsonb_build_object(
                'id', program.id,
                'author_id', program.author_id,
                'target_audience', program.target_audience,
                'title', program.title,
                'description', program.description,
                'tags', program.tags,
                'is_active', program.is_active,
                'artwork_path', program.artwork_path,
                'artwork_revision', program.artwork_revision,
                'workout_days', coalesce((
                    select jsonb_agg(
                        jsonb_build_object(
                            'id', day.id,
                            'program_id', day.program_id,
                            'title', day.title,
                            'order_index', day.order_index,
                            'workout_day_exercises', coalesce((
                                select jsonb_agg(
                                    jsonb_build_object(
                                        'id', assignment.id,
                                        'workout_day_id', assignment.workout_day_id,
                                        'exercise_id', assignment.exercise_id,
                                        'target_sets', assignment.target_sets,
                                        'target_reps', assignment.target_reps,
                                        'order_index', assignment.order_index
                                    )
                                    order by assignment.order_index, assignment.id
                                )
                                from public.workout_day_exercises as assignment
                                where assignment.workout_day_id = day.id
                            ), '[]'::jsonb)
                        )
                        order by day.order_index, day.id
                    )
                    from public.workout_days as day
                    where day.program_id = program.id
                ), '[]'::jsonb)
            )
            order by program.title, program.id
        )
        from public.workout_programs as program
        where program.author_id is null
          and program.is_active
    ), '[]'::jsonb),
    'exercises', coalesce((
        select jsonb_agg(
            jsonb_build_object(
                'id', exercise.id,
                'name', exercise.name,
                'muscle_group', exercise.muscle_group
            )
            order by exercise.name, exercise.id
        )
        from public.exercises as exercise
    ), '[]'::jsonb)
);
$$;

revoke execute on function public.get_system_catalog_v1()
from public, anon, service_role;

grant execute on function public.get_system_catalog_v1()
to authenticated;
