-- Privileged trigger infrastructure stays outside the Data API schema.
create schema if not exists private;

revoke all
on schema private
from public, anon, authenticated, service_role;

drop trigger if exists profiles_require_active_selected_program
on public.profiles;

drop function if exists public.require_active_selected_program();

-- The catalog remains read-only to app roles. This trigger-only function uses
-- its owner's privileges solely to lock the selected catalog row while the
-- profile update is validated.
create function private.require_active_selected_program()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if new.selected_program_id is null then
        return new;
    end if;

    if (select auth.uid()) is distinct from new.id then
        raise exception using
            errcode = '42501',
            message = 'selected_program_id can only be changed by the profile owner';
    end if;

    perform 1
    from public.workout_programs as program
    where program.id = new.selected_program_id
      and program.is_active
    for share;

    if not found then
        raise exception using
            errcode = '23514',
            message = 'selected_program_id must reference an active workout program';
    end if;

    return new;
end;
$$;

-- Trigger execution does not require client-callable function privileges.
revoke execute
on function private.require_active_selected_program()
from public, anon, authenticated, service_role;

create trigger profiles_require_active_selected_program
before insert or update of selected_program_id
on public.profiles
for each row
execute function private.require_active_selected_program();
