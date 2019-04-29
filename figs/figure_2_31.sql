DROP TABLE IF EXISTS temp_hold_data;
-- temp table `temp_hold_data for use later...
CREATE TEMP TABLE temp_hold_data AS
SELECT
CASE
WHEN r.record_type_code = 'i' THEN (
	SELECT
	l.bib_record_id
	FROM
	sierra_view.bib_record_item_record_link as l
	WHERE
	l.item_record_id = h.record_id
	LIMIT 1
)
WHEN r.record_type_code = 'j' THEN (
	SELECT
	l.bib_record_id
	FROM
	sierra_view.bib_record_volume_record_link as l
	WHERE
	l.volume_record_id = h.record_id
	LIMIT 1
)
WHEN r.record_type_code = 'b' THEN (
	h.record_id
)
ELSE NULL
END AS bib_record_id,
r.record_type_code, r.record_num,
p.ptype_code, h.*
FROM
sierra_view.hold AS h
JOIN
sierra_view.record_metadata AS r
ON
  r.id = h.record_id
JOIN
sierra_view.patron_record AS p
ON
  p.record_id = h.patron_record_id
;
---

CREATE INDEX temp_hold_data_bib_record_id ON temp_hold_data(bib_record_id);
ANALYZE temp_hold_data;

---
-- produce row output per bib_record_id (title) with a list of the 
-- pickup locations, and a count of the number of holds on that title
DROP TABLE IF EXISTS temp_title_item_counts;
CREATE TEMP TABLE temp_title_item_counts AS
WITH distinct_titles AS (
	SELECT
	t.bib_record_id,
	-- here we know that all record_nums are going to be bib_record_num
	-- since below we limit to record_type_code = 'b'
	t.record_num as bib_record_num,
	string_agg(t.pickup_location_code::TEXT, ',') AS pickup_locations,
	COUNT(*) as count_holds_title
	FROM
	temp_hold_data as t
	-- this time, limit only to bib_level_holds, and 
	-- patrons that are ptype 0
	WHERE
	t.record_type_code = 'b'
	AND t.ptype_code = 0
	GROUP BY
	t.bib_record_id,
	t.record_num
)

SELECT
d.bib_record_id,
'b' || d.bib_record_num || 'a' AS bib_record_num,
d.count_holds_title,
(
	SELECT
	COUNT(*)
	FROM
	sierra_view.bib_record_item_record_link AS l
	JOIN
	sierra_view.item_record AS i
	ON
	  i.record_id = l.item_record_id
	LEFT OUTER JOIN
	sierra_view.checkout as c
	ON
	  c.item_record_id = l.item_record_id
	WHERE
	l.bib_record_id = d.bib_record_id
	-- item has a status code of something that we'd want to see 	
	AND i.item_status_code IN (
		'-', '!', 'b', 'p', '(', '@', ')', '_', '=', '+'
	)
	AND COALESCE(
		--if this age is >= 60 days, it'll return FALSE, 
		-- and not count as an "available item"
		age(c.due_gmt) < '60 days'::INTERVAL,
		-- if there is no due_gmt value (NULL) return TRUE 		
		TRUE
	)
) AS count_items_available,
d.pickup_locations
FROM
distinct_titles AS d
;

SELECT
t.bib_record_id,
t.bib_record_num,
t.count_holds_title,
t.count_items_available,
CASE
	WHEN t.count_items_available = 0 THEN NULL
	-- formatting for output with to_char	
	-- https://www.postgresql.org/docs/current/functions-formatting.html#FUNCTIONS-FORMATTING-EXAMPLES-TABLE
	-- also, cast the INTEGER count values to numeric so that we get a float value back on division
	ELSE ROUND(
		(t.count_holds_title::NUMERIC / t.count_items_available::NUMERIC),
		2
	)
END AS hold_to_item_ratio,
p.best_title,
-- bring in this value later if we want
-- p.best_author,
t.pickup_locations

FROM
temp_title_item_counts as t

JOIN
sierra_view.bib_record_property AS p
ON
  p.bib_record_id = t.bib_record_id
;