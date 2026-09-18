-- Reusable exercise definitions shared by workout programs.
create table public.exercises (
    id uuid primary key,
    name text not null check (char_length(btrim(name)) > 0),
    muscle_group text not null check (
        muscle_group in (
            'chest',
            'back',
            'shoulders',
            'biceps',
            'triceps',
            'legs',
            'glutes',
            'core',
            'fullBody',
            'cardio',
            'other'
        )
    ),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- author_id is null for the default GigaCat catalog and contains a user ID
-- for a program created by that user.
create table public.workout_programs (
    id uuid primary key,
    author_id uuid references auth.users (id) on delete restrict,
    title text not null check (char_length(btrim(title)) > 0),
    description text not null check (char_length(btrim(description)) > 0),
    tags text[] not null default '{}',
    is_recommended boolean not null default false,
    is_popular boolean not null default false,
    rate_score numeric(2, 1) check (
        rate_score is null or rate_score between 0 and 5
    ),
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint workout_programs_tags_are_supported check (
        tags <@ array[
            'gym',
            'home',
            'streetWorkout',
            'cardio',
            'strength',
            'muscleGain',
            'mobility',
            'hiit',
            'bodyweight'
        ]::text[]
    )
);

create index workout_programs_author_id_idx
on public.workout_programs (author_id);

-- Ordered training days belonging to a program.
create table public.workout_days (
    id uuid primary key,
    program_id uuid not null references public.workout_programs (id) on delete cascade,
    title text not null check (char_length(btrim(title)) > 0),
    order_index integer not null check (order_index >= 0),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (program_id, order_index)
);

create index workout_days_program_id_idx
on public.workout_days (program_id);

-- Ordered exercise assignments and their planned volume for each workout day.
create table public.workout_day_exercises (
    id uuid primary key,
    workout_day_id uuid not null references public.workout_days (id) on delete cascade,
    exercise_id uuid not null references public.exercises (id) on delete restrict,
    target_sets integer not null check (target_sets > 0),
    target_reps integer not null check (target_reps > 0),
    order_index integer not null check (order_index >= 0),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (workout_day_id, order_index)
);

create index workout_day_exercises_workout_day_id_idx
on public.workout_day_exercises (workout_day_id);

create index workout_day_exercises_exercise_id_idx
on public.workout_day_exercises (exercise_id);

-- Keep updated_at server-controlled for every catalog table.
create trigger exercises_set_updated_at
before update on public.exercises
for each row
execute function public.set_updated_at();

create trigger workout_programs_set_updated_at
before update on public.workout_programs
for each row
execute function public.set_updated_at();

create trigger workout_days_set_updated_at
before update on public.workout_days
for each row
execute function public.set_updated_at();

create trigger workout_day_exercises_set_updated_at
before update on public.workout_day_exercises
for each row
execute function public.set_updated_at();

alter table public.exercises enable row level security;
alter table public.workout_programs enable row level security;
alter table public.workout_days enable row level security;
alter table public.workout_day_exercises enable row level security;

revoke all on table public.exercises from anon;
revoke all on table public.workout_programs from anon;
revoke all on table public.workout_days from anon;
revoke all on table public.workout_day_exercises from anon;

grant select on table public.exercises to authenticated;
grant select, insert, update, delete on table public.workout_programs to authenticated;
grant select, insert, update, delete on table public.workout_days to authenticated;
grant select, insert, update, delete on table public.workout_day_exercises to authenticated;

-- Exercises are maintained by the server and are read-only for app clients.
create policy "Authenticated users can read exercises"
on public.exercises
for select
to authenticated
using (true);

-- Active catalog programs are visible to signed-in users. Authors can also
-- read their own inactive programs.
create policy "Authenticated users can read available programs"
on public.workout_programs
for select
to authenticated
using (
    is_active
    or author_id = (select auth.uid())
);

create policy "Users can create their programs"
on public.workout_programs
for insert
to authenticated
with check (author_id = (select auth.uid()));

create policy "Users can update their programs"
on public.workout_programs
for update
to authenticated
using (author_id = (select auth.uid()))
with check (author_id = (select auth.uid()));

create policy "Users can delete their programs"
on public.workout_programs
for delete
to authenticated
using (author_id = (select auth.uid()));

create policy "Authenticated users can read available workout days"
on public.workout_days
for select
to authenticated
using (
    exists (
        select 1
        from public.workout_programs as program
        where program.id = workout_days.program_id
          and (
              program.is_active
              or program.author_id = (select auth.uid())
          )
    )
);

create policy "Authors can create workout days"
on public.workout_days
for insert
to authenticated
with check (
    exists (
        select 1
        from public.workout_programs as program
        where program.id = workout_days.program_id
          and program.author_id = (select auth.uid())
    )
);

create policy "Authors can update workout days"
on public.workout_days
for update
to authenticated
using (
    exists (
        select 1
        from public.workout_programs as program
        where program.id = workout_days.program_id
          and program.author_id = (select auth.uid())
    )
)
with check (
    exists (
        select 1
        from public.workout_programs as program
        where program.id = workout_days.program_id
          and program.author_id = (select auth.uid())
    )
);

create policy "Authors can delete workout days"
on public.workout_days
for delete
to authenticated
using (
    exists (
        select 1
        from public.workout_programs as program
        where program.id = workout_days.program_id
          and program.author_id = (select auth.uid())
    )
);

create policy "Authenticated users can read available day exercises"
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
          and (
              program.is_active
              or program.author_id = (select auth.uid())
          )
    )
);

create policy "Authors can create day exercises"
on public.workout_day_exercises
for insert
to authenticated
with check (
    exists (
        select 1
        from public.workout_days as day
        join public.workout_programs as program
          on program.id = day.program_id
        where day.id = workout_day_exercises.workout_day_id
          and program.author_id = (select auth.uid())
    )
);

create policy "Authors can update day exercises"
on public.workout_day_exercises
for update
to authenticated
using (
    exists (
        select 1
        from public.workout_days as day
        join public.workout_programs as program
          on program.id = day.program_id
        where day.id = workout_day_exercises.workout_day_id
          and program.author_id = (select auth.uid())
    )
)
with check (
    exists (
        select 1
        from public.workout_days as day
        join public.workout_programs as program
          on program.id = day.program_id
        where day.id = workout_day_exercises.workout_day_id
          and program.author_id = (select auth.uid())
    )
);

create policy "Authors can delete day exercises"
on public.workout_day_exercises
for delete
to authenticated
using (
    exists (
        select 1
        from public.workout_days as day
        join public.workout_programs as program
          on program.id = day.program_id
        where day.id = workout_day_exercises.workout_day_id
          and program.author_id = (select auth.uid())
    )
);
