# PgTest
Testing in PostgreSQL. Tested with PostgreSQL 9.4.

## Installation
Create database and execute pgtest.sql. This will create pgtest schema with functions that are used for testing.

```bash
curl --silent https://raw.githubusercontent.com/raitraidma/pgtest/master/pgtest.sql |\
sudo -u postgres psql mydatabasefortesting
```


## Usage
Create schema for your tests:
```sql
CREATE SCHEMA IF NOT EXISTS test;
```

Create test functions. Test function MUST return void:
```sql
CREATE OR REPLACE FUNCTION test.a_equals_a_ok()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_equals('A', 'A');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=test, pg_temp;
```
```sql
CREATE OR REPLACE FUNCTION test.a_equals_b_fails()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_equals('A', 'B');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=test, pg_temp;
```

Run tests:
```sql
SELECT pgtest.run_tests('test');
-- OR
SELECT pgtest.run_tests(ARRAY['test_schema1','test_schema2']); -- Run tests from multiple schemas.
```

Result is number of messages that failed. Raised messages show more specific info about tests - what tests ran, how many failed, what was the cause and how long it took.
If you do not want to see pg_exception_context in messages then change `client_min_messages` to `NOTICE`:
```sql
SET client_min_messages TO NOTICE;
```

## Assertions
* `pgtest.assert_equals(expected_value, real_value);`
* `pgtest.assert_not_equals(not_expected_value, real_value);`
* `pgtest.assert_true(boolean_value);`
* `pgtest.assert_false(boolean_value);`

`expected_value` and `real_value` must be same type (BIGINT, BIT, BOOLEAN, CHAR, VARCHAR, DOUBLE PRECISION, INT, REAL, SMALLINT, TEXT, TIME, TIMETZ, TIMESTAMP, TIMESTAMPTZ, XML).
