-- Repair any selections created before active-program validation existed.
update public.profiles as profile
set selected_program_id = null
where profile.selected_program_id is not null
  and not exists (
      select 1
      from public.workout_programs as program
      where program.id = profile.selected_program_id
        and program.is_active
  );

-- A profile may select only a program that is active at write time. The row
-- lock keeps a concurrent deactivation from passing between this check and
-- the profile update.
create function public.require_active_selected_program()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.selected_program_id is null then
        return new;
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

revoke execute
on function public.require_active_selected_program()
from public, anon, authenticated, service_role;

create trigger profiles_require_active_selected_program
before insert or update of selected_program_id
on public.profiles
for each row
execute function public.require_active_selected_program();

-- Deactivating a server-owned catalog program clears it from every profile.
-- SECURITY DEFINER is required because the operation crosses user-owned rows;
-- direct execution is revoked so this remains trigger-only infrastructure.
create function public.clear_deactivated_system_program_from_profiles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.profiles
    set selected_program_id = null
    where selected_program_id = new.id;

    return new;
end;
$$;

revoke execute
on function public.clear_deactivated_system_program_from_profiles()
from public, anon, authenticated, service_role;

create trigger workout_programs_clear_deactivated_system_selection
after update of is_active
on public.workout_programs
for each row
when (
    old.is_active
    and not new.is_active
    and new.author_id is null
)
execute function public.clear_deactivated_system_program_from_profiles();
