-- OSAS asking for new requirements is not a rejection.
--
-- "Request new requirements" and the queue's "reject, allow resubmission" both
-- stored `rejected`, so a verified person OSAS only asked to upload again was
-- labelled Rejected in both apps. Its own value lets them read differently.
-- Added alone: a new enum value cannot be used in the transaction that adds it.
alter type public.user_status add value if not exists 'needs_resubmission' after 'verified';
