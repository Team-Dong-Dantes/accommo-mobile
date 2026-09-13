-- Managers can now reject a payment (not just verify it), with a reason.
alter type payment_status add value if not exists 'rejected';

alter table payments add column if not exists rejection_reason text;
