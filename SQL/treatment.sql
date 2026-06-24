-- Leisure-time aerobic activity in moderate-equivalent minutes per week.
CREATE OR REPLACE TABLE treatment AS
WITH paq_clean AS (
  SELECT
    SEQN,
    PAQ650, PAQ665,
    CASE WHEN PAQ655 >= 77   THEN NULL ELSE PAQ655 END AS vig_days,
    CASE WHEN PAD660 >= 7777 THEN NULL ELSE PAD660 END AS vig_min,
    CASE WHEN PAQ670 >= 77   THEN NULL ELSE PAQ670 END AS mod_days,
    CASE WHEN PAD675 >= 7777 THEN NULL ELSE PAD675 END AS mod_min
  FROM paq
),
weeks AS (
  SELECT
    SEQN,
    CASE WHEN PAQ650 = 2 THEN 0 WHEN PAQ650 = 1 THEN vig_days * vig_min END AS vig_week,
    CASE WHEN PAQ665 = 2 THEN 0 WHEN PAQ665 = 1 THEN mod_days * mod_min END AS mod_week
  FROM paq_clean
)
SELECT
  SEQN,
  mod_week + 2 * vig_week AS active_min,
  CASE
    WHEN mod_week + 2 * vig_week IS NULL THEN NULL
    WHEN mod_week + 2 * vig_week >= 150  THEN 1
    ELSE 0
  END AS met_guideline
FROM weeks;
