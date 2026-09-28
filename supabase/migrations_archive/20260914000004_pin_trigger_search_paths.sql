-- The last two function_search_path_mutable findings.
--
-- Neither function sets search_path, so the tables they name resolve against
-- whatever the caller's search_path happens to be. Both are trigger bodies, so
-- the practical risk is low, but every other function in this schema pins it
-- and these two were simply missed. Bodies are unchanged.

CREATE OR REPLACE FUNCTION public.ticket_touch()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
begin
  new.updated_at = now();
  if new.status = 'resolved' and old.status is distinct from 'resolved' then
    new.resolved_at = now();
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.validate_accommodation_facility_room()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.room_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.rooms
    WHERE id = NEW.room_id
      AND accommodation_id = NEW.accommodation_id
  ) THEN
    RAISE EXCEPTION 'Private facility room must belong to its accommodation';
  END IF;
  RETURN NEW;
END;
$function$;
