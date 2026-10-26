-- Surrender vote (!ff): the team that gave up, 1 Agatha / 2 Mason; null = played out.
-- Run this BEFORE deploying the function that writes it, or every result fails.
alter table public.ranked_matches
  add column if not exists surrendered_team smallint check (surrendered_team in (1, 2));
