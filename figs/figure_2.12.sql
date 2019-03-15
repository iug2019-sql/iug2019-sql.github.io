DROP TABLE IF EXISTS temp_hold_data;

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

-- SELECT
-- *
-- FROM
-- temp_hold_data
-- 
-- LIMIT 100