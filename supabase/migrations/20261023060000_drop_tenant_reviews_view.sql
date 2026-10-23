-- 1.101 writes tenant ratings to `reviews` directly, and every release is
-- required, so the stand-in view kept for older builds by 20261023020000 goes.

drop view if exists public.tenant_reviews;
