-- OSAS can take an accredited accommodation out of what students browse
-- without touching its accreditation. This is a separate flag rather than a
-- status because `status` is the landlord's own lifecycle (they can delist and
-- relist), and because `accommodations_select_accredited` also serves current
-- boarders their own My Stay screen, so filtering there would lock them out of
-- the place they live in. The student browse queries filter on the flag instead.
alter table public.accommodations
  add column if not exists hidden_from_listings boolean not null default false;

-- `accommodations_update_own` lets a landlord update any column of their own
-- row, which would let them clear an OSAS decision. Only an admin may change
-- this one.
create or replace function public.guard_hidden_from_listings()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.hidden_from_listings is distinct from old.hidden_from_listings
     and not is_admin(auth.uid()) then
    raise exception 'Only OSAS can change whether an accommodation is hidden from listings'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists accommodations_guard_hidden_from_listings on public.accommodations;
create trigger accommodations_guard_hidden_from_listings
  before update of hidden_from_listings on public.accommodations
  for each row execute function public.guard_hidden_from_listings();
