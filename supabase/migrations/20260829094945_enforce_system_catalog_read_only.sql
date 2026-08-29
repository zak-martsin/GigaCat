-- App clients can only read the server-owned v1 catalog. Revoke every table
-- privilege first so TRUNCATE, TRIGGER, and REFERENCES cannot survive older
-- grants, then restore the single capability required by the app.
revoke all privileges
on table
    public.exercises,
    public.workout_programs,
    public.workout_days,
    public.workout_day_exercises
from anon, authenticated;

grant select
on table
    public.exercises,
    public.workout_programs,
    public.workout_days,
    public.workout_day_exercises
to authenticated;
