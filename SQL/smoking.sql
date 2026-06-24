-- Never, former, or current smoker from the two screening items.
CREATE OR REPLACE TABLE smoking AS
SELECT
  SEQN,
  CASE
    WHEN SMQ020 = 2 THEN 'never'
    WHEN SMQ020 = 1 AND SMQ040 = 3 THEN 'former'
    WHEN SMQ020 = 1 AND SMQ040 IN (1, 2) THEN 'current'
  END AS smoke
FROM smq;
