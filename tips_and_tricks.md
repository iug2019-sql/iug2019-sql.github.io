# DRAFT Tips And Tricks

___

## Tables of Note


### `sierra_view.record_metadata`

* This table is *very* useful as it contains:
  * `record_type_code`: defines record as being bib (b), item (i), patron (p), etc.
  * `record_num`: record number used by the SDA and the webpac / encore
  * `creation_date_gmt`: date the record entered the system (different from a cataloged date)
  * `deletion_date_gmt`: deleted records will have no other information in the system other than info left in this table
  * `campus_code`: useful for telling if the record is from ILL
  * `record_last_updated_gmt` : when the record was last modified

* It's useful to JOIN to this table, as it can be used to filter out records that don't "belong" to the library (ILL). 
* **Note** that this field won't have a `NULL` value; instead, it's blank or `''` in cases where there is no `campus_code`

```sql
-- find titles that have been cataloged in the last 7 days
SELECT
r.record_type_code || r.record_num || 'a' as bib_record_num,
r.creation_date_gmt,
b.cataloging_date_gmt
FROM
sierra_view.record_metadata as r
JOIN
sierra_view.bib_record as b
ON
  b.record_id = r.id
WHERE
-- concatinating these together will exclude bib records that are ILL
r.record_type_code || r.campus_code = 'b'
AND r.deletion_date_gmt IS NULL
AND b.is_suppressed IS FALSE
AND AGE(b.cataloging_date_gmt) <= '7 days'::INTERVAL
```




### `sierra_view.*record`, `sierra_view.*property`

* Each record type has one of each table
  * bib_view, bib_record, bib_record_property
* Record table contains majority of fixed fields
* Record_property table contains additional descriptive fields
  * Including useful values such as call_number, title and barcode

### `sierra_view.*view`

* View table combines fields from multiple tables Convenience comes at the expense of efficiency (use them sparingly, if at all if possible!)

Example: `sierra_view.bib_view` combines data from multiple tables, but query speeds can be slower than accessing other tables more directly.

```sql
SELECT
*
FROM
sierra_view.bib_view

LIMIT 1000
```

`(1.6 seconds)`

VS

```sql
SELECT
*
FROM
sierra_view.bib_record as b

JOIN
sierra_view.bib_record_property as p
ON
  p.bib_record_id = b.record_id

LIMIT 1000
```

`(543 milliseconds)`

### `sierra_view.*myuser`

* A `my_user` table exists for each fixed field in the system
* Contains code and name values for their respective field
* Use to provide translations for system codes

### `sierra_view.iii user_desktop_option`

* `desktop_option_id` isn't documented, but you may be able to figure out the option by a combination of `value`, and `iii_user_id` or `user_name` ... good luck!

```sql
DROP TABLE IF EXISTS temp_users;

CREATE TEMP TABLE temp_users as
SELECT
iii_user_id,
user_name
FROM
sierra_view.iii_user_application_myuser

GROUP BY
iii_user_id,
user_name
;

DROP INDEX IF EXISTS temp_users_iii_user_id;
CREATE INDEX temp_users_iii_user_id ON temp_users (iii_user_id);

SELECT
t.user_name,
t.iii_user_id,
o.desktop_option_id,
o.value

FROM
sierra_view.iii_user_desktop_option as o

LEFT OUTER JOIN
temp_users as t
ON
  t.iii_user_id = o.iii_user_id

ORDER BY
t.user_name,
o.desktop_option_id
;
```

### `sierra_view.varfield`

* using `occ_num` is a good method for picking the first value of (possibly) repeated values (especially where you may not be expecting or wanting multiple values)

```sql
--- get patron record id and the first barcode listed on their account
SELECT
r.record_id,
(
	SELECT
	v.field_content
	FROM
	sierra_view.varfield as v
	WHERE
	v.record_id = r.record_id
	AND v.varfield_type_code = 'b'
	ORDER BY
	v.occ_num

	LIMIT 1
) as barcode
FROM
sierra_view.patron_record as r

LIMIT 100
```

### `sierra_view.bool_info`

* This table has a column called `sql_query` that could be useful for seeing the underlying SQL for create list searches.
___

___

## Unique SQL Queries (can't easily be done via the SDA / CreateLists)

```sql
-- identifies order records across accounting units that lack a location code
-- due to downloading incomplete data from a vendor
SELECT
r.record_type_code || r.record_num || 'a' as order_record_num,
r.creation_date_gmt,
o.accounting_unit_code_num

FROM
sierra_view.order_record as o

JOIN
sierra_view.record_metadata as r
ON
  r.id = o.record_id

JOIN
sierra_view.order_record_cmf as c
ON
  c.order_record_id = o.record_id

WHERE
c.location_code = 'none'
;
```