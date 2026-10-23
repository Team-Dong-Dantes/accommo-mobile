-- Drop the tables archived by 20261023020000, 20261023030000 and 20261023040000.
-- Their rows live on in public.reviews and private.reminders_sent (admin_profiles
-- never had any).
--
-- auth.users still carried an old policy reading admin_profiles. It granted
-- nothing (the table was empty) and is the only thing outside the archive that
-- depends on it.

drop policy if exists admin_select_all_users on auth.users;

drop table if exists archive.accommodation_reviews;
drop table if exists archive.landlord_reviews;
drop table if exists archive.tenant_reviews;
drop table if exists archive.expiry_reminders;
drop table if exists archive.payment_reminders;
drop table if exists archive.admin_profiles;
drop schema if exists archive;
