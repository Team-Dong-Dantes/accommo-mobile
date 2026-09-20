/**
 * Shared PostgREST column lists.
 *
 * accommo-mobile has no data layer: 30 pages and 17 components call
 * `supabase.from(...)` directly, and the same column list is written out by
 * hand in each one. Removing the `smoking` policy meant editing three separate
 * select strings across three files, and missing one would have produced a
 * runtime PostgREST error rather than a compile error.
 *
 * These are the fragments that were genuinely duplicated. Pulling the *strings*
 * out is deliberately smaller than wrapping every query in a fetch function:
 * the pain was five copies of a column list, not five copies of a request, and
 * a shared constant cannot change what any caller does at run time.
 *
 * Adding or removing a column on one of these tables is now a one-line edit
 * here. Keep them as template literals so they stay greppable.
 */

/** Every house rule a student is shown. */
export const POLICY_FULL =
  'curfew_time,quiet_hours,visitor_policy,cooking,laundry,pets,min_stay,contract_type'

/** Just the commercial terms — what a room costs to take. */
export const POLICY_TERMS = 'advance_months,deposit_months,min_stay,contract_type'

/** The manager's own editor, which reads the rules but sets terms per room. */
export const POLICY_RULES = 'min_stay,curfew_time,quiet_hours,visitor_policy,cooking,laundry,pets'

/** A room as it appears on a card or in a list. */
export const ROOM_CARD =
  'id,room_number,label,room_type,custom_room_type,capacity,monthly_rent,rent_basis,status'

/** A room with everything its own detail screen needs. */
export const ROOM_DETAIL =
  'id,label,room_number,room_type,custom_room_type,capacity,floor,monthly_rent,advance_months,deposit_months,rent_basis,status'

/** The person fields any avatar + name row needs. Never widen this: it is read
 *  under RLS policies that deliberately expose only a narrow public profile. */
export const USER_BRIEF = 'id,full_name,initials,avatar_color,avatar_url'

/** A lease as the student's My Stay and the manager's tenant list read it. */
export const LEASE_CORE =
  'id,room_id,status,start_date,end_date,monthly_rent,advance_paid,deposit_paid,accommodation_manager_id'
