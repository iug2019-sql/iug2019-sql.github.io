SELECT
r.record_type_code,
p.ptype_code,
COUNT(r.record_type_code) as count_holds
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
GROUP BY
r.record_type_code,
p.ptype_code
ORDER BY
r.record_type_code,
p.ptype_code
