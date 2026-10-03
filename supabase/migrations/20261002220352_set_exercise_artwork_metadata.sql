do $$
declare
    updated_exercise_count integer;
begin
    update public.exercises
    set artwork_path = id::text || '/main.png',
        artwork_revision = greatest(artwork_revision, 1)
    where id::text like '10000000-0000-0000-0000-%';

    get diagnostics updated_exercise_count = row_count;

    if updated_exercise_count <> 61 then
        raise exception
            'Expected to update 61 system exercises, updated %',
            updated_exercise_count;
    end if;
end;
$$;
