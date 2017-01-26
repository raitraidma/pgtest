# PgTest
Testing in PostgreSQL. Tested with PostgreSQL 9.4.

## Installation
Create database and execute `pgtest.sql`. This will create pgtest schema with functions that are used for testing.

```bash
curl --silent https://raw.githubusercontent.com/raitraidma/pgtest/master/pgtest.sql |\
sudo -u postgres psql mydatabasefortesting
```

To run PgTest's tests execute `pgtest_test.sql`. There you can also see how to use PgTest.

## Usage
Create schema for your tests:
```sql
CREATE SCHEMA IF NOT EXISTS test;
```

Create test functions. Test function MUST return `void` and start with `test_`. Tests are ordered by function name.
```sql
CREATE OR REPLACE FUNCTION test.test_a_equals_a_ok()
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
CREATE OR REPLACE FUNCTION test.test_a_equals_b_fails()
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
If you do not want to see pg_exception_context in messages then change `client_min_messages` to `NOTICE`. Otherwise use DEBUG, LOG or INFO.
```sql
SET client_min_messages TO NOTICE;
```

## Assertions
* `pgtest.assert_equals(expected_value, real_value [, custom_error_message]);`
* `pgtest.assert_not_equals(not_expected_value, real_value [, custom_error_message]);`
* `pgtest.assert_true(boolean_value [, custom_error_message]);`
* `pgtest.assert_false(boolean_value [, custom_error_message]);`
* `pgtest.assert_query_equals(expected_recordset, sql_query [, custom_error_message])`

`expected_value` and `real_value` must be same type (BIGINT, BIT, BOOLEAN, CHAR, VARCHAR, DOUBLE PRECISION, INT, REAL, SMALLINT, TEXT, TIME, TIMETZ, TIMESTAMP, TIMESTAMPTZ, XML or array).

`expected_recordset` is array TEXT[][] (e.g `ARRAY[ARRAY['a', 'b'], ARRAY['c', 'd']]`) and `sql_query` is sql query as text (e.g `'SELECT ''a'', ''b'''`).

## Mocking
* `pgtest.mock(original_function_schema_name, original_function_name, function_arguments, mock_function_schema_name, mock_function_name)` - replaces original function with mock function.