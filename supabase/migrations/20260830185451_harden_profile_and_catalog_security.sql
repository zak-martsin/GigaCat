-- The Auth trigger owns profile creation. App clients only read their profile
-- and update the selected program column.
revoke all privileges
on table public.profiles
from anon, authenticated;

grant select
on table public.profiles
to authenticated;

grant update (selected_program_id)
on table public.profiles
to authenticated;

drop policy if exists "Users can create their profile"
on public.profiles;

-- Trigger helpers are internal database infrastructure, not RPC endpoints.
revoke execute
on function public.set_updated_at()
from public, anon, authenticated, service_role;

-- A selected program must reference a real catalog program. Removing one
-- clears the selection instead of preventing catalog maintenance.
alter table public.profiles
add constraint profiles_selected_program_id_fkey
foreign key (selected_program_id)
references public.workout_programs (id)
on delete set null;

create index profiles_selected_program_id_idx
on public.profiles (selected_program_id)
where selected_program_id is not null;

-- GigaCat v1 exposes only active, server-owned programs. Enforce that boundary
-- in RLS as well as in the client query.
drop policy if exists "Authenticated users can read available programs"
on public.workout_programs;

create policy "Authenticated users can read system programs"
on public.workout_programs
for select
to authenticated
using (
    is_active
    and author_id is null
);

drop policy if exists "Authenticated users can read available workout days"
on public.workout_days;

create policy "Authenticated users can read system workout days"
on public.workout_days
for select
to authenticated
using (
    exists (
        select 1
        from public.workout_programs as program
        where program.id = workout_days.program_id
          and program.is_active
          and program.author_id is null
    )
);

drop policy if exists "Authenticated users can read available day exercises"
on public.workout_day_exercises;

create policy "Authenticated users can read system day exercises"
on public.workout_day_exercises
for select
to authenticated
using (
    exists (
        select 1
        from public.workout_days as day
        join public.workout_programs as program
          on program.id = day.program_id
        where day.id = workout_day_exercises.workout_day_id
          and program.is_active
          and program.author_id is null
    )
);
