-- Add records for testing
BEGIN;

WITH generated AS (
    SELECT version_num,
           gen_random_uuid() AS id,
           gen_random_uuid() AS file_id,
           UPPER(MD5(gen_random_uuid()::text)) AS mge_file_id
    FROM generate_series(1, 3) AS version_num
),
prepared AS (
    SELECT version_num,
           id,
           file_id,
           mge_file_id,
           LAG(mge_file_id) OVER (ORDER BY version_num) AS mge_previous_file_id
    FROM generated
)
INSERT INTO estimate (
    id,
    file_id,
    report_name,
    status,
    date_create,
    date_change,
    appeal_number,
    okn,
    schema,
    type,
    errors,
    warnings,
    appeal_id,
    mge_file_id,
    mge_previous_file_id,
    mge_file_volume,
    mge_file_version,
    mge_file_status,
    is_deleted,
    upload_guid
)
SELECT id,
       file_id,
       'file_v' || version_num AS report_name,
       'XLSX_READY' AS status,
       CURRENT_TIMESTAMP + (version_num * INTERVAL '1 second') AS date_create,
       CURRENT_TIMESTAMP + (version_num * INTERVAL '1 second') AS date_change,
       '77-2149/26-(0)-0' AS appeal_number,
       FALSE AS okn,
       'LocalEstimateBaseIndexMethodMGE-1_09_13' AS schema,
       'LOCAL' AS type,
       '[]'::jsonb AS errors,
       '[]'::jsonb AS warnings,
       '634a5a43-c489-4b79-a5b5-ab96986cb537'::uuid AS appeal_id,
       mge_file_id,
       mge_previous_file_id,
       CASE
           WHEN version_num = 1 THEN 105
           ELSE NULL
       END AS mge_file_volume,
       version_num AS mge_file_version,
       CASE
           WHEN version_num = 3 THEN 'NEW'
           ELSE 'CANCEL_FL'
       END AS mge_file_status,
       FALSE AS is_deleted,
       'd92ca3e0c6aa498190e57ce27121aa7b' AS upload_guid
FROM prepared
ORDER BY version_num
RETURNING id,
          report_name,
          mge_file_id,
          mge_previous_file_id,
          mge_file_volume,
          mge_file_version,
          mge_file_status;

COMMIT;

-- Find records for updating
WITH RECURSIVE candidates AS (
    SELECT e.id AS estimate_id,
           e.mge_previous_file_id
    FROM estimate e
    WHERE e.mge_file_volume IS NULL
      AND e.status = 'XLSX_READY'
      AND e.is_deleted = FALSE
      AND e.date_create >= DATE '2026-07-23'
      AND NOT EXISTS (
          SELECT 1
          FROM estimate successor
          WHERE successor.mge_previous_file_id = e.mge_file_id
            AND successor.id <> e.id
      )
),
predecessors AS (
    SELECT candidate.estimate_id,
           previous.id AS source_id,
           previous.mge_previous_file_id,
           previous.mge_file_volume,
           previous.date_create,
           ARRAY[candidate.estimate_id, previous.id] AS visited_ids
    FROM candidates candidate
    JOIN estimate previous
      ON previous.mge_file_id = candidate.mge_previous_file_id
    WHERE NULLIF(BTRIM(candidate.mge_previous_file_id), '') IS NOT NULL
      AND previous.id <> candidate.estimate_id

    UNION ALL

    SELECT chain.estimate_id,
           previous.id,
           previous.mge_previous_file_id,
           previous.mge_file_volume,
           previous.date_create,
           chain.visited_ids || previous.id
    FROM predecessors chain
    JOIN estimate previous
      ON previous.mge_file_id = chain.mge_previous_file_id
    WHERE chain.mge_file_volume IS NULL
      AND NULLIF(BTRIM(chain.mge_previous_file_id), '') IS NOT NULL
      AND NOT (previous.id = ANY(chain.visited_ids))
),
selected_sources AS (
    SELECT DISTINCT ON (estimate_id)
           estimate_id,
           source_id,
           mge_file_volume
    FROM predecessors
    WHERE mge_file_volume IS NOT NULL
    ORDER BY estimate_id, date_create DESC, source_id DESC
)
SELECT target.report_name,
       target.upload_guid,
       target.mge_file_id
FROM estimate target
JOIN selected_sources source
  ON source.estimate_id = target.id
WHERE target.mge_file_volume IS NULL
ORDER BY target.report_name;


-- UPDATE field mge_file_volume
BEGIN;
WITH RECURSIVE candidates AS (
    -- 1 select estimates with an empty volume that meet the conditions of the problem and are not referenced by other records
    SELECT e.id AS estimate_id,
           e.mge_previous_file_id
    FROM estimate e
    WHERE e.mge_file_volume IS NULL
      AND e.status = 'XLSX_READY'
      AND e.is_deleted = FALSE
      AND e.date_create >= DATE '2026-07-23'
      AND NOT EXISTS (
        SELECT 1
        FROM estimate successor
        WHERE successor.mge_previous_file_id = e.mge_file_id
          AND successor.id <> e.id
    )
), predecessors AS (
    -- 2 For each selected estimate find its previous version
    SELECT candidate.estimate_id,
           previous.id AS source_id,
           previous.mge_previous_file_id,
           previous.mge_file_volume,
           previous.date_create,
           ARRAY[candidate.estimate_id, previous.id] AS visited_ids
    FROM candidates candidate
             JOIN estimate previous ON previous.mge_file_id = candidate.mge_previous_file_id
    WHERE NULLIF(BTRIM(candidate.mge_previous_file_id), '') IS NOT NULL
      AND previous.id <> candidate.estimate_id

    UNION ALL

    -- if the volume is empty in the previous estimate move on down the chain
    SELECT chain.estimate_id,
           previous.id,
           previous.mge_previous_file_id,
           previous.mge_file_volume,
           previous.date_create,
           chain.visited_ids || previous.id
    FROM predecessors chain
             JOIN estimate previous ON previous.mge_file_id = chain.mge_previous_file_id
    WHERE chain.mge_file_volume IS NULL
      AND NULLIF(BTRIM(chain.mge_previous_file_id), '') IS NOT NULL
      -- don't return to a record we have already viewed to avoid infinite recursion
      AND NOT (previous.id = ANY(chain.visited_ids))
), selected_sources AS (
    -- 3 leave the sources with the volume filled in and select one for each estimate
    -- if there are several suitable sources - choose the most recent one
    SELECT DISTINCT ON (estimate_id)
        estimate_id, source_id, mge_file_volume
    FROM predecessors
    WHERE mge_file_volume IS NOT NULL
    ORDER BY estimate_id, date_create DESC, source_id DESC
)
--4 add the volume we have found to the current estimate if that volume is empty
UPDATE estimate target
SET mge_file_volume = source.mge_file_volume
FROM selected_sources source
WHERE target.id = source.estimate_id
  AND target.mge_file_volume IS NULL;
COMMIT;


SELECT COUNT (*)
FROM estimate e
WHERE e.mge_file_volume IS NULL
AND e.status = 'XLSX_READY'
AND e.is_deleted = FALSE
AND e.date_create >= DATE '2026-07-23'
AND NOT EXISTS (
SELECT 1
FROM estimate s
WHERE s.mge_previous_file_id = e.mge_file_id
);

SELECT COUNT (*)
FROM estimate e
WHERE e.mge_file_volume IS NULL
AND e.status = 'XLSX_READY'
AND e.is_deleted = FALSE
AND e.mge_previous_file_id IS NOT NULL
AND e.date_create >= DATE '2026-07-23'
AND NOT EXISTS (
SELECT 1
FROM estimate s
WHERE s.mge_previous_file_id = e.mge_file_id
);

SELECT COUNT (*)
FROM estimate e
JOIN estimate p ON p.mge_file_id = e.mge_previous_file_id
WHERE e.mge_file_volume IS NULL
AND e.status = 'XLSX_READY'
AND e.is_deleted = FALSE
AND e.mge_previous_file_id IS NOT NULL
AND p.mge_file_volume IS NULL
AND e.date_create >= DATE '2026-07-23'
AND NOT EXISTS (
SELECT 1
FROM estimate s
WHERE s.mge_previous_file_id = e.mge_file_id
);

SELECT COUNT (*)
FROM estimate e
JOIN estimate p ON p.mge_file_id = e.mge_previous_file_id
WHERE e.mge_file_volume IS NULL
AND e.status = 'XLSX_READY'
AND e.is_deleted = FALSE
AND e.mge_previous_file_id IS NOT NULL
AND p.mge_file_volume IS NOT NULL
AND e.date_create >= DATE '2026-07-23'
AND NOT EXISTS (
SELECT 1
FROM estimate s
WHERE s.mge_previous_file_id = e.mge_file_id
);