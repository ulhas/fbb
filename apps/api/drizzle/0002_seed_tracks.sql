-- Seed the 8 canonical tracks the iOS follow-picker shows.
-- Idempotent: re-running won't duplicate (ON CONFLICT on the unique `code`).

INSERT INTO "tracks" ("code", "family", "cadence", "display_name", "short_name", "description", "required_equipment", "default_for_quiz", "active", "sort_order")
VALUES
  ('pump_lift_5x', 'pump_lift', '5x', 'Pump Lift 5x',
   'Lift 5x',
   'Five-day strength split — heavy compounds, structured accessories, weekly progression.',
   ARRAY['barbell', 'db', 'machine']::text[],
   true,  true, 10),

  ('pump_lift_4x', 'pump_lift', '4x', 'Pump Lift 4x',
   'Lift 4x',
   'Four-day strength split for busy weeks — same lifts, smarter density.',
   ARRAY['barbell', 'db', 'machine']::text[],
   true,  true, 20),

  ('pump_lift_3x', 'pump_lift', '3x', 'Pump Lift 3x',
   'Lift 3x',
   'Three-day strength split — minimal commitment, maximal carryover.',
   ARRAY['barbell', 'db']::text[],
   false, true, 30),

  ('pump_condition_5x', 'pump_condition', '5x', 'Pump Condition 5x',
   'Condition 5x',
   'Five-day strength + conditioning hybrid — engine, capacity, and lifting blended weekly.',
   ARRAY['barbell', 'db', 'kb', 'machine']::text[],
   false, true, 40),

  ('pump_condition_4x', 'pump_condition', '4x', 'Pump Condition 4x',
   'Condition 4x',
   'Four-day strength + conditioning hybrid — best for athletes balancing sport and gym.',
   ARRAY['barbell', 'db', 'kb']::text[],
   true,  true, 50),

  ('pump_condition_3x', 'pump_condition', '3x', 'Pump Condition 3x',
   'Condition 3x',
   'Three-day strength + conditioning hybrid — short, sharp, sustainable.',
   ARRAY['db', 'kb', 'bodyweight']::text[],
   false, true, 60),

  ('perform', 'perform', NULL, 'Perform',
   'Perform',
   'Competition-style programming — strength, intervals, mixed modal. Built for athletes who want to compete.',
   ARRAY['barbell', 'db', 'kb', 'rings', 'machine']::text[],
   false, true, 70),

  ('minimalist', 'minimalist', NULL, 'Minimalist',
   'Minimalist',
   'One pair of dumbbells (or a kettlebell) and 30 minutes — high-quality training when life is loud.',
   ARRAY['db', 'kb', 'bodyweight']::text[],
   false, true, 80)

ON CONFLICT ("code") DO NOTHING;
