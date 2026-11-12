-- Optional fields preserve access for existing accounts without onboarding.
alter table public.profiles
    add column goal text,
    add column level text,
    add column avatar_path text,
    add constraint profiles_goal_check
        check (goal in ('loseWeight', 'maintain', 'buildMuscle')),
    add constraint profiles_level_check
        check (level in ('beginner', 'intermediate', 'advanced'));

-- Ownership policies and server-managed identity/timestamps remain unchanged.
grant update (goal, level, avatar_path)
    on table public.profiles to authenticated;
