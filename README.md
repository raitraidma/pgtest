# PgTest
Testing in PostgreSQL.

## Installation
Create database and execute pgtest.sql. This will create pgtest schema with functions that are used for testing.

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
```

Result is number of messages that failed. Raised info messages show more specific info about tests - what tests running, how many failed, what was the cause and how long it took.

