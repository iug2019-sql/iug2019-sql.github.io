# Sierra SQL Tips And Tricks: IUG 2019
![iug2019-logo_small.png](https://github.com/iug2019-sql/iug2019-sql.github.io/raw/master/img/iug2019-logo_small.png "IUG 2019")
___

## Tables of Note


### `sierra_view.record_metadata`

* This table is *very* useful as it contains:
  * `record_type_code`: defines record as being bib (b), item (i), patron (p), etc.
  * `record_num`: record number used by the SDA and the webpac / encore
  * `creation_date_gmt`: date the record entered the system (different from a cataloged date)
  * `deletion_date_gmt`: deleted records will have no other information in the system other than info left in this table
  * `record_last_updated_gmt` : when the record was last modified
  * `campus_code`: useful for telling if the record is from ILL
    * **Note** that this field **won't** have a `NULL` value; instead, it's blank or `''` in cases where there is no `campus_code`

* It's useful to JOIN to this table, as it can be used to filter out records that don't "belong" to the library (ILL) using the `campus_code` as shown below (note the use of `campus_code` being blank as the filtering condition in the WHERE clause):

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

`sierra_view.record_metadata` is also useful for obtaining the `record_num` from a `record_id` (`record_num` is used in the SDA, webpac / encore for identifying a record). We can JOIN `sierra_view.record_metadata`, appending the columns (generic checkdigit character, `a` can be added to the end for cases where a checkdigit is needed):

```sql
sierra_view.record_type_code || sierra_view.record_number || 'a'
```

Example:

```sql
SELECT
r.record_type_code || r.record_num || 'a' as record_number

FROM
sierra_view.record_metadata as r

WHERE
r.record_type_code || r.campus_code = 'p'
and r.deletion_date_gmt is null

limit 5
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

```sql
SELECT
p.name
FROM
sierra_view.item_record i
JOIN
sierra_view.itype_property_myuser p
ON i.itype_code_num = p.code
```

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

```sql
--Count the number of owning libraries for each title in a review file
--Pass query a review file of items to be weeded
--Check to see which other locations own those titles and how they've performed system wide prior to deleting records

SELECT
id2reckey(b.id)||'a' AS "bib_record",
b.title AS "bib_title",
count(bi.id) AS "item_count",
count(distinct(i.agency_code_num)) AS "location_count",
array_to_string(
            ARRAY(
               SELECT loc.location_code
                 FROM sierra_view.bib_record_location AS loc
                WHERE b.id = loc.bib_record_id
             ORDER BY 1
            ),
            ','
          ) AS "location codes",
SUM(i.checkout_total) AS "total checkouts",
SUM(i.renewal_total) AS "total renewals"
FROM
sierra_view.bib_view as b 
JOIN sierra_view.bool_set as sb ON b.id = sb.record_metadata_id AND sb.bool_info_id = '369'
JOIN Sierra_view.bib_record_item_record_link as bi ON b.id = bi.bib_record_id
JOIN sierra_view.item_record as i ON bi.item_record_id = i.id
JOIN sierra_view.record_metadata AS rm ON bi.item_record_id = rm.id
group by 1, 2, 5;
```

___


___

## Account for possible NULL Values!

`NULL` is a special value, and you should account for cases where a value can be `NULL`, as it can result in unexpected behavior.

Use `CONCAT()` function, which is NULL safe, or `COALESCE()` function, which returns the **first** non-null value.

```sql
SELECT
-- string concatenatination with operator ||
NULL || 'where did this go?!?!' AS ex_1,

-- string concatenatination with operator ||
COALESCE(NULL, '', 'we don''t get here') || 'remember that COALESCE returns first non-null value!' AS ex_2,

-- string concatenation with CONCAT function (which is NULL safe)
CONCAT(NULL, 'mind your ', NULL, 'values!') AS ex_3

```

Output:

| ex1 | ex2 | ex3 |
| --- | --- | --- |
| `NULL` | "remember that COALESCE returns first non-null value!" | "mind your values!" |

___

___

## Picking the Correct Key to JOIN On

Picking the correct primary / foreign keys for joins can be tricky.

* Make sure you carefully examine the sierra DNA documentation
* Columns named `id` generally are generally the **primary key**, as is the case in `sierra_view.record_metadata`. This means that it'll appear in other tables as the **foreign key**. For example:

**INCORRECT:**

```sql
SELECT
r.id,
b.id,
r.record_num
FROM
sierra_view.record_metadata as r

JOIN
sierra_view.bib_record as b
ON
  -- THIS IS NOT CORRECT AND WILL RETURN BAD DATA!!!
  b.id = r.id

LIMIT 100
;
```

**CORRECT:**

```sql
SELECT
r.id,
b.id,
r.record_num
FROM
sierra_view.record_metadata as r

JOIN
sierra_view.bib_record as b
ON
  -- THIS IS CORRECT (foreign key, `record_id` JOINed to primary key, `id` )
  b.record_id = r.id

LIMIT 100
;
```
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

___

___

## Using Indexes Effectively

Using an index can significantly speed up your query.

We can determine what indexes exist (or don't exist) on table with a query similar to the following:

```sql
-- find indexes on phrase_entry ...
-- or, find all indexes by removing
-- tablename = 'phrase_entry'
-- and uncommenting tablename NOTE LIKE 'pg%'
--
SELECT
*
FROM
pg_indexes
WHERE
tablename = 'phrase_entry'
-- tablename NOT LIKE 'pg%'
ORDER BY
schemaname,
tablename,
indexname
;
```
which tells us that one of the following indexes exist:

```sql
CREATE INDEX idx_phrase_entry ON iiirecord.phrase_entry USING btree ((((index_tag)::text || (index_entry)::text)), type2, insert_title, record_key)
```

The following query will take advantage of the index, and result in a fast, efficient search (this particular example will search for barcode and return the record it is associated with):

```sql
SELECT
e.record_id
FROM
sierra_view.phrase_entry as e
WHERE
e.index_tag || e.index_entry = 'b' || LOWER('A000052469475')
-- 64 msec execution time
-- EXPLAIN:
-- Index Scan using idx_phrase_entry on phrase_entry  (cost=0.69..586.22 rows=143 width=8)
--  Index Cond: (((index_tag)::text || (index_entry)::text) = 'ba000052469475'::text)
```

This is the INCORRECT way (just to demonstrate how drastic the difference is of using an index VS not using one)

```sql
SELECT
e.record_id
FROM
sierra_view.phrase_entry as e
WHERE
e.index_tag = 'b' 
AND e.index_entry = LOWER('A000052469475')
-- 28 secs execution time!!!!
-- EXPLAIN:
-- Seq Scan on phrase_entry  (cost=0.00..1783427.78 rows=20 width=8)
--  Filter: (((index_tag)::text = 'b'::text) AND ((index_entry)::text = 'a000052469475'::text))

--
-- sequential scan = bad!

```
___

___

## Unexpected One-to-Many Situations

Sometimes we only expect 1 row of data to be returned, but we get multiple rows back.

For example, this query:

```sql
SELECT
p.record_id,
v.field_content

FROM
sierra_view.patron_record as p

JOIN
sierra_view.varfield as v
ON
  v.record_id = p.record_id
  AND v.varfield_type_code = 'b'

WHERE
p.record_id = 481037682097
```

returns the following data:

```
481037682097;12345679
481037682097;12345678 / PREV ID
```

If we only want one row of data per patron record in our output, we have two options.

1 Grab the first occurrence of the barcode only:

```sql
SELECT
p.record_id,
(	
	-- subquery grabs the first occurance of the barcode
	SELECT
	v.field_content
	FROM
	sierra_view.varfield as v
	WHERE
	v.record_id = p.record_id
	AND v.varfield_type_code = 'b'
	ORDER BY
	v.occ_num
	LIMIT 1
) as field_content

FROM
sierra_view.patron_record as p

WHERE
p.record_id = 481037682097
```

```
481037682097;12345679
```

2 Aggregate all the barcodes into one column of data:

```sql
SELECT
p.record_id,
(	
	-- subquery grabs all barcodes
	SELECT
	string_agg(v.field_content, ',' ORDER BY v.occ_num)
	FROM
	sierra_view.varfield as v
	WHERE
	v.record_id = p.record_id
	AND v.varfield_type_code = 'b'
) as fields_content

FROM
sierra_view.patron_record as p

WHERE
p.record_id = 481037682097
```

```
481037682097;12345679,12345678 / PREV ID
```

___

___

## Helpful / useful queries

### Get info about indexes / tables postgres database

```sql
-- find indexes!
-- NOTE that these indexes are defined not on the view,
-- but on the iiirecord. The tables and views are assumed 
-- to be similarly named, but that's not guaranteed
SELECT
*
FROM
pg_indexes
WHERE
tablename = 'phrase_entry'
-- tablename NOT LIKE 'pg%' -- use this to find ALL indexes
ORDER BY
schemaname,
tablename,
indexname
;
```


```sql
-- show detailed view of `sierra_view` table_schema
SELECT
*
FROM
information_schema.columns

WHERE
table_schema = 'sierra_view'

ORDER BY
table_name,
ordinal_position
;

```

```sql
-- show all tables
SELECT
*
FROM
pg_catalog.pg_tables
ORDER BY
tablename
;
```
