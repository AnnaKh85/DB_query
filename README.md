# PostgreSQL Queries for QA and Data Validation

SQL examples for investigating related application records, inspecting document-check results, and preparing and correcting test data in a construction-estimate domain.

The repository demonstrates PostgreSQL query techniques used in backend and database testing. It contains SQL scripts; it is not a standalone application or a self-contained database demo.

## Examples

| File | Purpose | Operations |
| --- | --- | --- |
| [Update Volume.sql](Update%20Volume.sql) | Generate a three-version estimate chain, preview records eligible for volume restoration, fill missing volumes from predecessor records, and inspect remaining candidates | SELECT, INSERT, UPDATE, transactions |
| [estimate_v2_interdoc.sql](estimate_v2_interdoc.sql) | Investigate appeals, estimates, previous appeals, parsing statuses, JSON contexts, and inter-document checks | SELECT |

### Restoring a missing volume across document versions

[Update Volume.sql](Update%20Volume.sql) follows version links through `mge_previous_file_id` and `mge_file_id`.

The main restoration query:

1. Selects estimates with a missing volume, status `XLSX_READY`, `is_deleted = FALSE`, and a creation date on or after the specified cutoff. Candidates must have no other record referencing them as a predecessor.
2. Traverses predecessor records using a recursive CTE.
3. Continues along a branch while its predecessor volume is NULL.
4. Tracks visited record IDs in an array to prevent cycles.
5. Chooses a non-NULL source per target with `DISTINCT ON`, ordered by source creation date descending and source ID descending.
6. Updates the target only while its volume is still NULL.

The data-generation section creates three linked versions with volume 105 on the first version and NULL on the next two. This illustrates propagation through an intermediate version with a missing value; it is not an automated assertion.

The file also includes a read-only candidate preview and diagnostic counts. The counts use different conditions from the main update, so they are separate diagnostics rather than exact before/after assertions for that update.

### Investigating estimates and inter-document checks

[estimate_v2_interdoc.sql](estimate_v2_interdoc.sql) contains several diagnostic queries that:

- Retrieve appeal details and related check history.
- Combine estimate metadata with local, summary, or object JSON context using `COALESCE`.
- Select a previous-appeal record using `ROW_NUMBER()`, ordered by application date ascending.
- Retrieve check records with the maximum check date per appeal.
- Filter by appeal number, upload identifier, parsing status, estimate type, and file status.

These queries expose data for investigation; they do not automatically compare it against expected business results.

## SQL techniques demonstrated

- Recursive and non-recursive common table expressions
- Version-chain traversal and cycle detection using arrays
- Window functions: `LAG` and `ROW_NUMBER`
- PostgreSQL `DISTINCT ON`
- `LEFT JOIN`, `INNER JOIN`, and `NOT EXISTS`
- Aggregation with `MAX` and `COUNT`
- NULL handling with `COALESCE` and `NULLIF`
- UUID casts, JSONB literals, and generated test identifiers
- `INSERT ... SELECT ... RETURNING` and `UPDATE ... FROM`
- Explicit transactions

