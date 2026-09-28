-- Other users' avatars never rendered anywhere in the app (Messages, tenant/
-- manager detail cards, tenant lists, QR scan results, ...): there was no
-- column to hold a photo visible to anyone but its owner. `avatar_url` sits
-- alongside the existing `initials`/`avatar_color` fallback, world-readable
-- under the same "Authenticated users can view public profile info" policy
-- already covering those columns, and writable only by the row's own user
-- under the existing "Users can update their own profile" policy.
alter table public.users add column if not exists avatar_url text;
