-- Two rooms carried 500 and 5000 months of advance/deposit -- 41 and 416 years.
-- rooms.advance_months / deposit_months had `min` on the input but no `max` and
-- no clamp on save, so a mistyped value went straight in. Both accommodations
-- are accredited, so students were seeing these, and the student application
-- summary multiplies them by the rent: room 101 quoted ~PHP 1,333,333 due on
-- move-in.
--
-- The client now clamps to 0-12 on blur and again in the save payload
-- (AccommodationDetail.vue, clampNum/clampOptional). This repairs the rows that
-- predate that.
--
-- One month advance and one month deposit is the ordinary arrangement locally;
-- these were plainly typos rather than a real figure to preserve.

update public.rooms
   set advance_months = 1,
       deposit_months = 1
 where id in (
   'ca7aa4f0-b65b-42c3-9b46-de4a159a65dc',
   '232a1648-0e40-4121-8d8b-cbf50d584e77'
 );
