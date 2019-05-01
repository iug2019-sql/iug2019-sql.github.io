# DRAFT Tips And Tricks

___

## Tables of Note

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

`desktop_option_id` isn't documented, but you may be able to figure out the option by a combination of `value`, and `iii_user_id` or `user_name` ... good luck!

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
___
