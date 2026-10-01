-- Wi-Fi moves from the amenity chips to the utilities, next to water and
-- electricity: what students need to know is whether it is in the rent, split,
-- or a flat fee. Unlike water and power it can also be absent, so billing gains
-- 'not_available'. Own meter is offered for Wi-Fi by no client; the column takes
-- the shared enum, so nothing here forbids it.
alter type public.utility_billing add value if not exists 'not_available';

alter table public.accommodations
  add column if not exists wifi_billing public.utility_billing,
  add column if not exists wifi_flat_fee numeric;

alter table public.accommodations drop constraint if exists accommodations_wifi_flat_fee;
alter table public.accommodations
  add constraint accommodations_wifi_flat_fee check (
    case when wifi_billing = 'flat_fee' then coalesce(wifi_flat_fee, 0) > 0 else wifi_flat_fee is null end
  );

-- Split Wi-Fi is billed monthly like split water and power.
alter table public.utility_bills drop constraint if exists utility_bills_utility_check;
alter table public.utility_bills
  add constraint utility_bills_utility_check check (utility in ('water', 'electric', 'wifi'));

-- Existing 'wifi' amenity rows stay, unlike the water/electric ones: "this place
-- has Wi-Fi" is a real fact, and Discover's Wi-Fi filter still matches on it
-- until the landlord/landlady sets wifi_billing. Current clients no longer show
-- or offer the chip, and the check keeps admitting it for older APKs.
