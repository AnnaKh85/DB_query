SELECT a.id                   as "appeal_id",
       a.appeal_number        as "appeal_number",
       a.appeal_date          as "appeal_date",
       a.case_number          as "case_number",
       a.case_date            as "case_date",
       a.appeal_status        as "appeal_status",
       a.object_name          as "object_name",
       a.object_address       as "object_address",
       a.work_kind            as "work_kind",
       a.declarant_name       as "declarant_name",
       a.project_org_name     as "project_org_name",
       a.developer_name       as "developer_name",
       a.budjet_disposer_name as "budjet_disposer_name",
       a.application_date     as "application_date",
       a."primary"            as "primary",
       idc.id                 as "idc_id",
       idc.appeal_id          as "idc appeal_id",
       idc.check_date         as "idc check_date",
       idc.status             as "idc status",
       idc.check_result       as "idc check_result",
       idc.interdoc_report_id as "interdoc_report_id",
       idc.interdoc_structure as "interdoc_structure"
FROM appeal a
         left join interdoc_check idc ON idc.appeal_id = a.id
WHERE a.appeal_number = '77-660/26-(0)-0'
order by idc.check_date desc
;

-- ==== Estimate + Interdoc Main Query
SELECT a.appeal_number,
--        to_char(a.date_change, 'YYYY-MM-DD HH24:MI:SS') "appeal_date_change",
--        to_char(e.date_change, 'YYYY-MM-DD HH24:MI:SS') "estimate_date_change",
--        TO_CHAR(e.date_create, 'YYYY-MM-DD HH24:MI:SS') "estimate_date_create",
--        a.id as "appeal_id",
       a."primary",
       a.application_date,
       a.mge_appeal_id,
--        a.case_number,
--        a.case_date,
--        a.work_kind,
       pa.appeal_number                                            as previous_appeal_number,
       pa.application_date                                         as previous_application_date,
       e.id                                                        as estimate_id,
       e.report_name                                               as file_name,
       e.type                                                      as estimate_type,
       e.is_deleted,
       e.status                                                    as status_parsing,
       e.mge_file_status,
       e.mge_file_id,
       e.mge_previous_file_id,
--        e.file_id,
--        e.okn,
--        TO_CHAR(e.date_create, 'YYYY-MM-DD HH24:MI:SS') "date_create",
--        to_char(e.date_change, 'YYYY-MM-DD HH24:MI:SS') "date_change",
       idc.check_result,
       idc.interdoc_structure,
       COALESCE(lc.json_context, sc.json_context, oc.json_context) as json_context,
       idc.interdoc_report_id,
       idc.status,
       idc.check_date,
       idc.date_report
FROM appeal a
         LEFT JOIN (SELECT temp_pa.*,
                           ROW_NUMBER() OVER (PARTITION BY temp_pa.appeal_id ORDER BY temp_pa.application_date) AS rn
                    FROM previous_appeal temp_pa) pa ON a.id = pa.appeal_id AND pa.rn = 1
         LEFT JOIN estimate e ON a.appeal_number = e.appeal_number
         LEFT JOIN local_context lc ON e.id = lc.estimate_id
         LEFT JOIN summary_context sc ON e.id = sc.estimate_id
         LEFT JOIN object_context oc ON e.id = oc.estimate_id
         LEFT JOIN (SELECT tt.interdoc_structure,
                           tt.check_date,
                           tt.status,
                           tt.check_result,
                           tt.interdoc_report_id,
                           tt.date_report,
                           tt.appeal_id
                    FROM interdoc_check tt
                             INNER JOIN (SELECT DISTINCT appeal_id, max(check_date) as md
                                         FROM interdoc_check
                                         GROUP BY appeal_id) t
                                        ON t.appeal_id = tt.appeal_id AND t.md = tt.check_date) idc
                   ON e.appeal_id::uuid = idc.appeal_id
WHERE e.upload_guid = 'FD374440859F49D498F92F6A73F5B916'
  and e.mge_file_status <> 'CANCEL_FL'
--   and e.report_name='77-3331_26-(0)-0__02-01-14 ОДИ'
--   and e.mge_file_id is not NULL
order by e.type desc, idc.date_report desc
;

select e.id,
       e.appeal_number,
       e.report_name,
       e.date_create,
       sm.json_context
from estimate e
         left join summary_context sm on e.id = sm.estimate_id
where e.appeal_number = '77-2710/26-(0)-0'
  and e.status <> 'XML_PARSING_ERROR'
  and e.type = 'SUMMARY'
  and mge_file_status = 'VERIFIED_POZITIVE'
order by date_create desc
;



SELECT a.appeal_number,
       a.id,
       e.id          as estimate_id,
       e.type        as estimate_type,
       e.status      as status_parsing,
       e.mge_file_status,
       e.mge_file_id,
       e.mge_previous_file_id,
       e.report_name as file_name,
       idc.interdoc_structure,
       idc.status,
       idc.check_date
FROM appeal a
         LEFT JOIN estimate e ON a.appeal_number = e.appeal_number
         LEFT JOIN (SELECT tt.interdoc_structure,
                           tt.check_date,
                           tt.status,
                           tt.check_result,
                           tt.interdoc_report_id,
                           tt.date_report,
                           tt.appeal_id
                    FROM interdoc_check tt
                             INNER JOIN (SELECT DISTINCT appeal_id, max(check_date) as md
                                         FROM interdoc_check
                                         GROUP BY appeal_id) t
                                        ON t.appeal_id = tt.appeal_id AND t.md = tt.check_date) idc
                   ON e.appeal_id::uuid = idc.appeal_id
WHERE a.appeal_number = '77-1029/26-(0)-0'
order by estimate_type desc
;

SELECT idc.check_result, idc.interdoc_structure
FROM estimate e
         LEFT JOIN (SELECT tt.interdoc_structure,
                           tt.check_date,
                           tt.check_result,
                           tt.appeal_id
                    FROM interdoc_check tt
                             INNER JOIN (SELECT DISTINCT appeal_id, max(check_date) as md
                                         FROM interdoc_check
                                         GROUP BY appeal_id) t
                                        ON t.appeal_id = tt.appeal_id
                                            AND t.md = tt.check_date) idc
                   ON e.appeal_id::uuid = idc.appeal_id
WHERE e.appeal_number = '77-879/26-(0)-0'
  and e.mge_file_status <> 'CANCEL_FL';


SELECT a.id,
       a.primary,
       a.application_date,
       pa.application_date AS previous_application_date,
       idc.check_result,
       idc.interdoc_structure
FROM appeal a
         LEFT JOIN (SELECT temp_pa.appeal_id,
                           temp_pa.application_date,
                           ROW_NUMBER() OVER (PARTITION BY temp_pa.appeal_id ORDER BY temp_pa.application_date) AS rn
                    FROM previous_appeal temp_pa) pa ON a.id = pa.appeal_id AND pa.rn = 1
         LEFT JOIN (SELECT tt.interdoc_structure, tt.check_date, tt.check_result, tt.appeal_id
                    FROM interdoc_check tt
                             INNER JOIN (SELECT DISTINCT appeal_id, max(check_date) AS md
                                         FROM interdoc_check
                                         GROUP BY appeal_id) t
                                        ON t.appeal_id = tt.appeal_id AND t.md = tt.check_date) idc
                   ON a.id = idc.appeal_id::uuid
WHERE a.appeal_number = '77-953/26-(0)-0';