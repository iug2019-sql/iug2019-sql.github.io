# DRAFT Tips And Tricks
___
## Tables of Note: 

### `sierra_view.*record`, `sierra_view.*property` and `sierra_view.*view`

* Each record type has one of each table
  * bib_view, bib_record, bib_record_property
* Record table contains majority of fixed fields
* Record_property table contains additional descriptive fields
  * Including useful values such as call_number, title and barcode
* View table combines fields from multiple tables
Convenience comes at the expense of efficiency


### `sierra_view.*myuser`

* A `my_user` table exists for each fixed field in the system
* Contains code and name values for their respective field
* Use to provide translations for system codes

---