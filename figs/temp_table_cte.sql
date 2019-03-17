CREATE INDEX temp_hold_data_bib_record_id ON temp_hold_data(bib_record_id);
ANALYZE temp_hold_data;
-- common table expression WITH clause
WITH distinct_titles AS (
	SELECT
	t.bib_record_id,
	string_agg(t.pickup_location_code::TEXT, ',') AS pickup_locations,
	COUNT(*) as count_holds_title
	FROM
	temp_hold_data as t
	GROUP BY
	t.bib_record_id
)

SELECT
d.*
FROM
distinct_titles AS d
ORDER BY
d.count_holds_title DESC
;