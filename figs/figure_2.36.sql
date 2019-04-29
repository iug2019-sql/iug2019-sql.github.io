-- return ISBN number (or null, if number doesn't match expected format of ISBN
-- and record number associated with the ISBN
SELECT
v.record_id, 
(regexp_matches(
	v.field_content,
	-- the regex to match on (10 or 13 digits, with the possibility of the 
	-- 'X' character in the check-digit spot)
	'[0-9]{9,10}[x]{0,1}|[0-9]{12,13}[x]{0,1}', 
	-- regex flags; ignore case
	'i'
))[1]::varchar(30) as search_isbn

FROM
sierra_view.varfield AS v

WHERE
v.marc_tag || v.varfield_type_code = '020i'

LIMIT 100