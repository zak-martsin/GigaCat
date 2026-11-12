-- Run as the database owner after the Profile v1 migrations. All profile edits roll back.
begin;

do $test$
declare
    owner_id uuid;
    affected bigint;
    combination record;
begin
    if not (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass) then
        raise exception 'profiles RLS must remain enabled';
    end if;
    if has_table_privilege('anon', 'public.profiles', 'UPDATE') then
        raise exception 'Anonymous profile updates must stay forbidden';
    end if;
    if (select count(*) from public.workout_programs where id in (
        '20000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002'
    ) and author_id is null) <> 2 then
        raise exception 'Expected both shipped system programs';
    end if;
    if exists (
        select 1 from public.workout_day_exercises assignment
        join public.workout_days day on day.id = assignment.workout_day_id
        where day.program_id in (
            '20000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002'
        ) and assignment.target_sets is not null
    ) then
        raise exception 'Shipped programs must delegate to profile recommendations';
    end if;

    select id into owner_id from public.profiles order by id limit 1;
    if owner_id is null then
        raise exception 'An existing profile is required for the transactional ownership checks';
    end if;
    perform set_config('request.jwt.claim.sub', owner_id::text, true);
    execute 'set local role authenticated';
    if (select count(*) from public.profiles) <> 1 then
        raise exception 'Authenticated profile reads must be scoped to one owner';
    end if;
    for combination in
        select goal, level
        from unnest(array['loseWeight', 'maintain', 'buildMuscle']) as goals(goal)
        cross join unnest(array['beginner', 'intermediate', 'advanced']) as levels(level)
    loop
        update public.profiles set goal = combination.goal, level = combination.level, avatar_path = null
        where id = owner_id;
        get diagnostics affected = row_count;
        if affected <> 1 then raise exception 'Owner could not update their own profile'; end if;
    end loop;
    update public.profiles set goal = null, level = null, avatar_path = null where id = owner_id;
    update public.profiles set goal = 'maintain' where id <> owner_id;
    get diagnostics affected = row_count;
    if affected <> 0 then raise exception 'Another owner profile was writable'; end if;
    begin
        update public.profiles set goal = 'invalid-goal' where id = owner_id;
        raise exception 'Invalid goals must be rejected';
    exception when check_violation then null;
    end;
    begin
        update public.profiles set level = 'invalid-level' where id = owner_id;
        raise exception 'Invalid levels must be rejected';
    exception when check_violation then null;
    end;
    begin
        update public.profiles set created_at = now() where id = owner_id;
        raise exception 'Client writes to server timestamps must be forbidden';
    exception when insufficient_privilege then null;
    end;
    begin
        update public.profiles set id = owner_id where id = owner_id;
        raise exception 'Client writes to profile identity must be forbidden';
    exception when insufficient_privilege then null;
    end;
    execute 'reset role';
end;
$test$;

rollback;
select 'Profile v1 permissions, constraints, nullable resets and ownership checks passed; profile edits rolled back' as result;
