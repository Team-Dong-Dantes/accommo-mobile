-- Names typed with Caps Lock on, fixed once.
--
-- capitalizeName() (src/utils/format.ts) only ever raised a leading lowercase
-- letter, so "ALEXA JOY E. BALDOZ" went through registration as typed and into
-- the OSAS queue that way. The app now lowers a run of capitals before
-- capitalising; this applies the same rule to the names already stored.
--
-- tidy_name() is that rule in SQL: a word of two or more capitals is lowered
-- unless it is a roman numeral ("III"), then the first letter after the start,
-- a space, an apostrophe or a hyphen is raised. Mixed case ("McDonald") and
-- single-letter initials are left alone. Not initcap(), which would also lower
-- the rest of every word and turn "McDonald" into "Mcdonald".
--
-- Students and landlords/landladies only: those are the names the app's rule
-- governs. A dry run against the live table also matched "OSAS Admin", an
-- acronym an admin chose, which this must not touch. Only rows holding a run of
-- capitals are rewritten, so a name typed in lowercase on purpose is not.
-- trg_audit_users records each old name in audit_logs.

create or replace function pg_temp.tidy_name(p text) returns text
language plpgsql immutable as $$
declare
  v_out text := '';
  v_prev text := ' ';
  v_tok text;
begin
  for v_tok in select m[1] from regexp_matches(coalesce(p, ''), '[[:alpha:]]+|[^[:alpha:]]+', 'g') as m loop
    if v_tok ~ '^[[:alpha:]]' then
      if v_tok ~ '^[[:upper:]]{2,}$' and v_tok !~ '^(I{1,3}|IV|VI{0,3}|IX|X)$' then
        v_tok := lower(v_tok);
      end if;
      if v_prev ~ '[[:space:]''-]$' then
        v_tok := upper(left(v_tok, 1)) || substr(v_tok, 2);
      end if;
    end if;
    v_out := v_out || v_tok;
    v_prev := v_tok;
  end loop;
  return v_out;
end $$;

update public.users
   set full_name = pg_temp.tidy_name(full_name)
 where role::text in ('student', 'landlord')
   and full_name ~ '[[:upper:]]{2,}'
   and full_name is distinct from pg_temp.tidy_name(full_name);
