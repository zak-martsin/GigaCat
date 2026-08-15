-- Creates a profile for every new Supabase Auth user.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id)
    values (new.id)
    on conflict (id) do nothing;

    return new;
end;
$$;

-- Prevents direct calls through the public API.
revoke execute
on function public.handle_new_user()
from public;

-- Runs the function after creating an Auth user.
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

-- Creates missing profiles for users registered before this migration.
insert into public.profiles (id)
select id
from auth.users
on conflict (id) do nothing;
