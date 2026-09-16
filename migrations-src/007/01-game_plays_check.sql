alter table public.game_plays drop constraint game_plays_game_check;
-- @@
alter table public.game_plays add constraint game_plays_game_check check (game in
    ('guess_the_split','who_knows_who','wordy','trivia','who_invited_you','fortune_teller','all_talk','cornhole','quick_pour','horse_racing','ring_toss','exquisite_corpse'));
