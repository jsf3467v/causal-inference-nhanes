-- These five numbers should match the R frame and the eda messages.
SELECT 'analysis_rows'        AS check, COUNT(*)                          AS value FROM analysis_table
UNION ALL
SELECT 'study_rows',                COUNT(*)                                    FROM study_cohort
UNION ALL
SELECT 'met_guideline',             SUM(met_guideline)                          FROM study_cohort
UNION ALL
SELECT 'deaths',                    SUM(died)                                   FROM study_cohort
UNION ALL
SELECT 'median_follow_months', CAST(MEDIAN(follow_months) AS BIGINT)            FROM study_cohort;
