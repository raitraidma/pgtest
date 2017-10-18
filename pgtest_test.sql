DROP SCHEMA IF EXISTS pgtest_test CASCADE;
CREATE SCHEMA pgtest_test;

CREATE OR REPLACE FUNCTION pgtest_test.f_test_function(s_input VARCHAR, i_default INT DEFAULT 1, s_default TEXT DEFAULT 'def')
  RETURNS boolean AS
$$
  SELECT (CASE
    WHEN $1 = 'a' THEN true
    ELSE false
  END);
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;

CREATE OR REPLACE FUNCTION pgtest_test.f_test_function_mock(s_input VARCHAR, i_default INT DEFAULT 2, s_default TEXT DEFAULT 'ault')
  RETURNS boolean AS
$$
  SELECT (CASE
    WHEN $1 = 'a' THEN false
    ELSE true
  END);
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;

CREATE OR REPLACE FUNCTION pgtest_test.f_test_function_array_param(s_input VARCHAR[])
  RETURNS int AS
$$
  SELECT array_length(s_input, 1);
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;

CREATE OR REPLACE FUNCTION pgtest_test.f_test_function_array_param_mock(s_input VARCHAR[])
  RETURNS int AS
$$
  SELECT array_length(s_input, 1) + 10;
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;

CREATE OR REPLACE FUNCTION pgtest_test.f_test_function_udt_param(s_table_name information_schema.columns.table_name%TYPE)
  RETURNS information_schema.columns.table_name%TYPE AS
$$
  SELECT s_table_name;
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;

CREATE OR REPLACE FUNCTION pgtest_test.f_test_function_udt_param_mock(s_table_name information_schema.columns.table_name%TYPE)
  RETURNS information_schema.columns.table_name%TYPE AS
$$
  SELECT s_table_name;
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;

CREATE OR REPLACE FUNCTION pgtest_test.f_test_function_array_param_and_array_return(s_input VARCHAR[])
  RETURNS VARCHAR[] AS
$$
  SELECT s_input;
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;

CREATE OR REPLACE FUNCTION pgtest_test.f_test_function_array_param_and_array_return_mock(s_input VARCHAR[])
  RETURNS VARCHAR[] AS
$$
  SELECT s_input;
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;

CREATE OR REPLACE FUNCTION pgtest_test.f_test_function_returns_table()
RETURNS TABLE (
  id BIGINT
, name VARCHAR
, groups INT[]
) AS $$
  SELECT 1::BIGINT, 'name1', ARRAY[1,2]::INT[]
  UNION ALL
  SELECT 2::BIGINT, 'name2', ARRAY[3,4]::INT[]
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;

CREATE OR REPLACE FUNCTION pgtest_test.f_test_function_returns_table_mock()
RETURNS TABLE (
  id BIGINT
, name VARCHAR
, groups INT[]
) AS $$
  SELECT 10::BIGINT, 'name10', ARRAY[10,20]::INT[]
  UNION ALL
  SELECT 20::BIGINT, 'name20', ARRAY[30,40]::INT[]
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;

CREATE TABLE pgtest_test.test_table (
  id INT
);

CREATE VIEW pgtest_test.test_view (id) AS
SELECT 1;

CREATE MATERIALIZED VIEW pgtest_test.test_materialized_view (id) AS
SELECT 2;

-----------
-- Tests --
-----------
CREATE OR REPLACE FUNCTION pgtest_test.test_asset_null_compares_with_null()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_null(NULL::TEXT);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_asset_not_null_compares_with_empty_text()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_not_null(''::TEXT);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_asset_true_compares_with_true()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_true(true);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_asset_false_compares_with_false()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_false(false);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_equals_compares_same_int()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_equals(25, 25);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_equals_compares_different_ints()
  RETURNS void AS
$$
DECLARE
  b_pass BOOLEAN := FALSE;
BEGIN
  BEGIN
    PERFORM pgtest.assert_equals(25, 29);
  EXCEPTION
    WHEN SQLSTATE '40005' THEN b_pass := TRUE;
  END;
  PERFORM pgtest.assert_true(b_pass, 'Ints should not be equal.');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_equals_compares_same_text()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_equals('some text'::TEXT, 'some text');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_equals_compares_text_with_null()
  RETURNS void AS
$$
DECLARE
  b_pass BOOLEAN := FALSE;
BEGIN
  BEGIN
    PERFORM pgtest.assert_equals('some text'::TEXT, NULL);
  EXCEPTION
    WHEN SQLSTATE '40005' THEN b_pass := TRUE;
  END;
  PERFORM pgtest.assert_true(b_pass, 'Text is not equal to NULL.');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_equals_compares_null_with_text()
  RETURNS void AS
$$
DECLARE
  b_pass BOOLEAN := FALSE;
BEGIN
  BEGIN
    PERFORM pgtest.assert_equals(NULL, 'some text'::TEXT);
  EXCEPTION
    WHEN SQLSTATE '40005' THEN b_pass := TRUE;
  END;
  PERFORM pgtest.assert_true(b_pass, 'NULL is not equal to text.');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_equals_compares_different_text()
  RETURNS void AS
$$
DECLARE
  b_pass BOOLEAN := FALSE;
BEGIN
  BEGIN
    PERFORM pgtest.assert_equals('some text'::TEXT, 'some other text');
  EXCEPTION
    WHEN SQLSTATE '40005' THEN b_pass := TRUE;
  END;
  PERFORM pgtest.assert_true(b_pass, 'Texts should not be equal.');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_not_equals_compares_different_text()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_not_equals('some text'::TEXT, 'some other text');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_not_equals_compares_same_text()
  RETURNS void AS
$$
DECLARE
  b_pass BOOLEAN := FALSE;
BEGIN
  BEGIN
    PERFORM pgtest.assert_not_equals('some text'::TEXT, 'some text');
  EXCEPTION
    WHEN SQLSTATE '40005' THEN b_pass := TRUE;
  END;
  PERFORM pgtest.assert_true(b_pass, 'Texts should be equal.');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_equals_throws_default_error_message()
  RETURNS void AS
$$
DECLARE
  s_message_text TEXT;
BEGIN
  BEGIN
    PERFORM pgtest.assert_equals('some text'::TEXT, 'some other text');
  EXCEPTION
    WHEN SQLSTATE '40005' THEN
      GET STACKED DIAGNOSTICS s_message_text = MESSAGE_TEXT;
  END;
  PERFORM pgtest.assert_equals('Expected: some text. But was: some other text.', s_message_text);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_equals_throws_custom_error_message()
  RETURNS void AS
$$
DECLARE
  s_message_text TEXT;
BEGIN
  BEGIN
    PERFORM pgtest.assert_equals('some text'::TEXT, 'some other text', 'First: %1$s. Second: %2$s.');
  EXCEPTION
    WHEN SQLSTATE '40005' THEN
      GET STACKED DIAGNOSTICS s_message_text = MESSAGE_TEXT;
  END;
  PERFORM pgtest.assert_equals('First: some text. Second: some other text.', s_message_text);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_mock_1_mock_changes_function_implementation()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_true(pgtest_test.f_test_function('a'));
  PERFORM pgtest.mock('pgtest_test', 'f_test_function', ARRAY['character varying', 'integer', 'text']::VARCHAR[], 'pgtest_test', 'f_test_function_mock');
  PERFORM pgtest.assert_false(pgtest_test.f_test_function('a'));
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_mock_2_mock_is_rolled_back_after_previous_test()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_true(pgtest_test.f_test_function('a'));
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_mock_and_spy_accept_array_parameters()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_equals(2, pgtest_test.f_test_function_array_param(ARRAY['a', 'b']::VARCHAR[]));
  PERFORM pgtest.mock('pgtest_test', 'f_test_function_array_param', ARRAY['character varying[]']::VARCHAR[], 'pgtest_test', 'f_test_function_array_param_mock');
  PERFORM pgtest.assert_equals(12, pgtest_test.f_test_function_array_param( ARRAY['a', 'b']::VARCHAR[]));
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_mock_and_assert_call_times()
  RETURNS void AS
$$
DECLARE
  s_mock_id VARCHAR;
BEGIN
  PERFORM pgtest.assert_true(pgtest_test.f_test_function('a'));
  s_mock_id := pgtest.mock('pgtest_test', 'f_test_function', ARRAY['character varying', 'integer', 'text']::VARCHAR[], 'pgtest_test', 'f_test_function_mock');
  PERFORM pgtest.assert_false(pgtest_test.f_test_function('a'));
  PERFORM pgtest.assert_false(pgtest_test.f_test_function('a'));
  PERFORM pgtest.assert_false(pgtest_test.f_test_function('a'));
  PERFORM pgtest.assert_called(s_mock_id, 3);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_mock_and_assert_called_at_least_once()
  RETURNS void AS
$$
DECLARE
  s_mock_id VARCHAR;
BEGIN
  PERFORM pgtest_test.f_test_function('a');
  s_mock_id := pgtest.mock('pgtest_test', 'f_test_function', ARRAY['character varying', 'integer', 'text']::VARCHAR[], 'pgtest_test', 'f_test_function_mock');
  PERFORM pgtest_test.f_test_function('a');
  PERFORM pgtest_test.f_test_function('a');
  PERFORM pgtest_test.f_test_function('a');
  PERFORM pgtest.assert_called_at_least_once(s_mock_id);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_mock_and_assert_call_arguments()
  RETURNS void AS
$$
DECLARE
  s_mock_id VARCHAR;
BEGIN
  PERFORM pgtest_test.f_test_function('a');
  s_mock_id := pgtest.mock('pgtest_test', 'f_test_function', ARRAY['character varying', 'integer', 'text']::VARCHAR[], 'pgtest_test', 'f_test_function_mock');
  PERFORM pgtest_test.f_test_function('b');
  PERFORM pgtest_test.f_test_function('c');
  PERFORM pgtest_test.f_test_function('d');
  PERFORM pgtest.assert_called_with_arguments(s_mock_id, ARRAY['b', '1', 'def'], 1);
  PERFORM pgtest.assert_called_with_arguments(s_mock_id, ARRAY['c', '1', 'def'], 2);
  PERFORM pgtest.assert_called_with_arguments(s_mock_id, ARRAY['d', '1', 'def'], 3);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_mock_and_assert_wrong_call_arguments()
  RETURNS void AS
$$
DECLARE
  s_mock_id VARCHAR;
  b_pass BOOLEAN := FALSE;
BEGIN
  BEGIN
    s_mock_id := pgtest.mock('pgtest_test', 'f_test_function', ARRAY['character varying', 'integer', 'text']::VARCHAR[], 'pgtest_test', 'f_test_function_mock');
    PERFORM pgtest_test.f_test_function('a');
    PERFORM pgtest_test.f_test_function('b');
    PERFORM pgtest_test.f_test_function('c');
    PERFORM pgtest.assert_called_with_arguments(s_mock_id, ARRAY['d'], 2);
  EXCEPTION
    WHEN SQLSTATE '40005' THEN b_pass := TRUE;
  END;
  PERFORM pgtest.assert_true(b_pass, 'assert_called_with_arguments should throw exception, because arguments do not match.');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_mock_function_without_parameters_returns_table()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_rows(
    $SQL$ VALUES (1::BIGINT, 'name1', ARRAY[1,2]::INT[]), (2::BIGINT, 'name2', ARRAY[3,4]::INT[]) $SQL$,
    $SQL$ SELECT * FROM pgtest_test.f_test_function_returns_table() $SQL$
  );

  PERFORM pgtest.mock('pgtest_test', 'f_test_function_returns_table', ARRAY[]::VARCHAR[], 'pgtest_test', 'f_test_function_returns_table_mock');

  PERFORM pgtest.assert_rows(
    $SQL$ VALUES (10::BIGINT, 'name10', ARRAY[10,20]::INT[]), (20::BIGINT, 'name20', ARRAY[30,40]::INT[]) $SQL$,
    $SQL$ SELECT * FROM pgtest_test.f_test_function_returns_table() $SQL$
  );
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_mock_function_with_udt_param_and_return_type()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.mock('pgtest_test', 'f_test_function_udt_param', ARRAY['information_schema.sql_identifier']::VARCHAR[], 'pgtest_test', 'f_test_function_udt_param_mock');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_mock_function_with_array_param_and_array_return()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.mock('pgtest_test', 'f_test_function_array_param_and_array_return', ARRAY['character varying[]']::VARCHAR[], 'pgtest_test', 'f_test_function_array_param_and_array_return_mock');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_spy_function_implementation_does_not_change()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_true(pgtest_test.f_test_function('a'));
  PERFORM pgtest.spy('pgtest_test', 'f_test_function', ARRAY['character varying', 'integer', 'text']::VARCHAR[]);
  PERFORM pgtest.assert_true(pgtest_test.f_test_function('a'));
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_spy_and_assert_call_times()
  RETURNS void AS
$$
DECLARE
  s_spy_id VARCHAR;
BEGIN
  PERFORM pgtest.assert_true(pgtest_test.f_test_function('a'));
  s_spy_id := pgtest.spy('pgtest_test', 'f_test_function', ARRAY['character varying', 'integer', 'text']::VARCHAR[]);
  PERFORM pgtest.assert_true(pgtest_test.f_test_function('a'));
  PERFORM pgtest.assert_true(pgtest_test.f_test_function('a'));
  PERFORM pgtest.assert_true(pgtest_test.f_test_function('a'));
  PERFORM pgtest.assert_true(pgtest_test.f_test_function('a'));
  PERFORM pgtest.assert_called(s_spy_id, 4);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_spy_and_assert_call_arguments()
  RETURNS void AS
$$
DECLARE
  s_spy_id VARCHAR;
BEGIN
  PERFORM pgtest_test.f_test_function('a');
  s_spy_id := pgtest.spy('pgtest_test', 'f_test_function', ARRAY['character varying', 'integer', 'text']::VARCHAR[]);
  PERFORM pgtest_test.f_test_function('b');
  PERFORM pgtest_test.f_test_function('c');
  PERFORM pgtest_test.f_test_function('d');
  PERFORM pgtest_test.f_test_function('e');
  PERFORM pgtest.assert_called_with_arguments(s_spy_id, ARRAY['b', '1', 'def'], 1);
  PERFORM pgtest.assert_called_with_arguments(s_spy_id, ARRAY['c', '1', 'def'], 2);
  PERFORM pgtest.assert_called_with_arguments(s_spy_id, ARRAY['d', '1', 'def'], 3);
  PERFORM pgtest.assert_called_with_arguments(s_spy_id, ARRAY['e', '1', 'def'], 4);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_spy_and_assert_wrong_call_arguments()
  RETURNS void AS
$$
DECLARE
  s_spy_id VARCHAR;
  b_pass BOOLEAN := FALSE;
BEGIN
  BEGIN
    s_spy_id := pgtest.spy('pgtest_test', 'f_test_function', ARRAY['character varying', 'integer', 'text']::VARCHAR[]);
    PERFORM pgtest_test.f_test_function('a');
    PERFORM pgtest_test.f_test_function('b');
    PERFORM pgtest_test.f_test_function('c');
    PERFORM pgtest.assert_called_with_arguments(s_spy_id, ARRAY['d'], 2);
  EXCEPTION
    WHEN SQLSTATE '40005' THEN b_pass := TRUE;
  END;
  PERFORM pgtest.assert_true(b_pass, 'assert_called_with_arguments should throw exception, because arguments do not match.');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_asset_table_exists_with_existing_table()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_table_exists('pgtest_test', 'test_table');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_asset_table_does_not_exist_with_non_existing_table()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_table_does_not_exist('pgtest_test', 'test_view');
  PERFORM pgtest.assert_table_does_not_exist('pgtest_test', 'test_materialized_view');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_asset_temp_table_exists_with_existing_temp_table()
  RETURNS void AS
$$
BEGIN
  CREATE TEMP TABLE test_temp_table();
  PERFORM pgtest.assert_temp_table_exists('test_temp_table');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_asset_temp_table_does_not_exist_with_non_existing_temp_table()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_temp_table_does_not_exist('test_temp_table');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_asset_temp_table_exists_with_non_existing_temp_table()
  RETURNS void AS
$$
DECLARE
  b_pass BOOLEAN := FALSE;
BEGIN
  BEGIN
    PERFORM pgtest.assert_temp_table_exists('test_temp_table');
  EXCEPTION
    WHEN SQLSTATE '40005' THEN b_pass := TRUE;
  END;
  PERFORM pgtest.assert_true(b_pass, 'assert_temp_table_exists should throw exception, because temp table does not exist.');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_asset_temp_table_does_not_exist_with_existing_temp_table()
  RETURNS void AS
$$
DECLARE
  b_pass BOOLEAN := FALSE;
BEGIN
  BEGIN
    CREATE TEMP TABLE test_temp_table();
    PERFORM pgtest.assert_temp_table_does_not_exist('test_temp_table');
  EXCEPTION
    WHEN SQLSTATE '40005' THEN b_pass := TRUE;
  END;
  PERFORM pgtest.assert_true(b_pass, 'assert_temp_table_does_not_exist should throw exception, because temp table exists.');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_asset_view_exists_with_existing_view()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_view_exists('pgtest_test', 'test_view');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_asset_view_does_not_exist_with_non_existing_view()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_view_does_not_exist('pgtest_test', 'test_table');
  PERFORM pgtest.assert_view_does_not_exist('pgtest_test', 'test_materialized_view');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_asset_mat_view_exists_with_existing_mat_view()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_mat_view_exists('pgtest_test', 'test_materialized_view');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_asset_mat_view_does_not_exist_with_non_existing_mat_view()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_mat_view_does_not_exist('pgtest_test', 'test_table');
  PERFORM pgtest.assert_mat_view_does_not_exist('pgtest_test', 'test_view');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_relation_has_column_relations_with_existing_columns()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_relation_has_column('pgtest_test', 'test_table', 'id');
  PERFORM pgtest.assert_relation_has_column('pgtest_test', 'test_view', 'id');
  PERFORM pgtest.assert_relation_has_column('pgtest_test', 'test_materialized_view', 'id');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_relation_does_not_have_column_relations_with_non_existing_columns()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_relation_does_not_have_column('pgtest_test', 'test_table', 'not_existing_column');
  PERFORM pgtest.assert_relation_does_not_have_column('pgtest_test', 'test_view', 'not_existing_column');
  PERFORM pgtest.assert_relation_does_not_have_column('pgtest_test', 'test_materialized_view', 'not_existing_column');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_f_function_exists()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_true(pgtest.f_function_exists('pgtest_test', 'f_test_function', ARRAY['character varying', 'integer', 'text']::VARCHAR[]), 'Function should exist.');
  PERFORM pgtest.assert_false(pgtest.f_function_exists('pgtest_test', 'f_test_function', ARRAY['character varying', 'integer']::VARCHAR[]), 'Function should not exist.');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_function_exists()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_function_exists('pgtest_test', 'f_test_function', ARRAY['character varying', 'integer', 'text']::VARCHAR[]);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_function_does_not_exist()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_function_does_not_exist('pgtest_test', 'f_test_function', ARRAY['character varying', 'integer']::VARCHAR[]);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_extension_exists_with_existing_extension()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_extension_exists('plpgsql');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_extension_does_not_exist_with_non_existing_extension()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_extension_does_not_exist('non_existing_extension');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_column_type()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_column_type('pgtest_test', 'test_table', 'id', 'integer');
  PERFORM pgtest.assert_column_type('pgtest_test', 'test_view', 'id', 'integer');
  PERFORM pgtest.assert_column_type('pgtest_test', 'test_materialized_view', 'id', 'integer');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_not_column_type()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_not_column_type('pgtest_test', 'test_table', 'id', 'character varying');
  PERFORM pgtest.assert_not_column_type('pgtest_test', 'test_view', 'id', 'character varying');
  PERFORM pgtest.assert_not_column_type('pgtest_test', 'test_materialized_view', 'id', 'character varying');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_before_after()
  RETURNS void AS
$$
BEGIN
  BEGIN
    CREATE SCHEMA pgtest_test_hooks;

    CREATE TABLE pgtest_test_hooks.execution (
      type VARCHAR
    );

    CREATE OR REPLACE FUNCTION pgtest_test_hooks.before()
      RETURNS void AS
    $TEST$
    BEGIN
      INSERT INTO pgtest_test_hooks.execution(type) VALUES ('BEFORE');
    END
    $TEST$ LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path=pgtest_test_hooks, pg_temp;

    CREATE OR REPLACE FUNCTION pgtest_test_hooks.test_test()
      RETURNS void AS
    $TEST$
    BEGIN
      INSERT INTO pgtest_test_hooks.execution(type) VALUES ('TEST');
    END
    $TEST$ LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path=pgtest_test_hooks, pg_temp;

    CREATE OR REPLACE FUNCTION pgtest_test_hooks.after()
      RETURNS void AS
    $TEST$
    BEGIN
      INSERT INTO pgtest_test_hooks.execution(type) VALUES ('AFTER');
    END
    $TEST$ LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path=pgtest_test_hooks, pg_temp;

    PERFORM pgtest.f_run_test('pgtest_test_hooks', 'test_test', FALSE);
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

  PERFORM pgtest.assert_rows(
    $SQL$ VALUES ('BEFORE'), ('TEST'), ('AFTER') $SQL$
  , $SQL$ SELECT type FROM pgtest_test_hooks.execution $SQL$
  );
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_f_prepare_statement()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_equals('SELECT * FROM pgtest_test.test_table', pgtest.f_prepare_statement(' SELECT * FROM pgtest_test.test_table;'));
  PERFORM pgtest.assert_equals('VALUES(''asd'', 2)', pgtest.f_prepare_statement(' VALUES(''asd'', 2);'));
  PERFORM pgtest.assert_equals('VALUES (''asd'', 2)', pgtest.f_prepare_statement(' VALUES (''asd'', 2);'));
  PERFORM pgtest.assert_equals('SELECT * FROM table_name', pgtest.f_prepare_statement(' table_name'));
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_rows_with_matching_rows_using_values_and_select()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_rows(
    $SQL$ VALUES('a', 1),('b',2),('c',3) $SQL$,
    $SQL$ SELECT 'c', 3 UNION ALL SELECT 'a', 1 UNION ALL SELECT 'b', 2 $SQL$
  );
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_rows_with_matching_rows_using_values_and_table()
  RETURNS void AS
$$
BEGIN
  CREATE TABLE pgtest_test.rows (
    id INT
  , value TEXT
  );

  INSERT INTO pgtest_test.rows(id, value) VALUES (1, 'a'), (2, 'b');

  PERFORM pgtest.assert_rows(
    $SQL$ pgtest_test.rows $SQL$,
    $SQL$ VALUES(2, 'b'), (1, 'a') $SQL$
  );
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_rows_with_some_non_matching_rows()
  RETURNS void AS
$$
DECLARE
  b_pass BOOLEAN := FALSE;
BEGIN
  BEGIN
    PERFORM pgtest.assert_rows(
      $SQL$ VALUES('a', 1),('b',2),('d',4) $SQL$,
      $SQL$ SELECT 'c', 3 UNION SELECT 'a', 1 UNION SELECT 'e', 5 $SQL$
    );
  EXCEPTION
    WHEN SQLSTATE '40005' THEN b_pass := TRUE;
  END;
  PERFORM pgtest.assert_true(b_pass, 'Some rows should not match');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_coverage()
  RETURNS void AS
$$
BEGIN
  CREATE SCHEMA pgtest_test_functions;
  
  CREATE OR REPLACE FUNCTION pgtest_test_functions.covered()
    RETURNS void AS
  $TEST$
  BEGIN
  END
  $TEST$ LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path=pgtest_test_functions, pg_temp;
  
  CREATE OR REPLACE FUNCTION pgtest_test_functions.not_covered()
    RETURNS void AS
  $TEST$
  BEGIN
  END
  $TEST$ LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path=pgtest_test_functions, pg_temp;

  CREATE SCHEMA pgtest_test_function_tests;

  CREATE OR REPLACE FUNCTION pgtest_test_function_tests.test_covered_function()
    RETURNS void AS
  $TEST$
  BEGIN
    PERFORM pgtest_test_functions.covered();
  END
  $TEST$ LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path=pgtest_test_function_tests, pg_temp;

  CREATE OR REPLACE FUNCTION pgtest_test_function_tests.not_covered_function()
    RETURNS void AS
  $TEST$
  BEGIN
    PERFORM pgtest_test_functions.not_covered();
  END
  $TEST$ LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path=pgtest_test_function_tests, pg_temp;

  PERFORM pgtest.assert_rows(
    $SQL$ VALUES('pgtest_test_functions', 'covered', TRUE), ('pgtest_test_functions', 'not_covered', FALSE) $SQL$,
    $SQL$ SELECT * FROM pgtest.coverage(ARRAY['pgtest_test_functions']::VARCHAR[], ARRAY['pgtest_test_function_tests']::VARCHAR[]) $SQL$
  );
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_remove_table_fk_constraints()
  RETURNS void AS
$$
BEGIN
  CREATE SCHEMA pgtest_test_tables;

  CREATE TABLE pgtest_test_tables.parent (
    id INT
  , CONSTRAINT pk_parent PRIMARY KEY(id)
  );

  CREATE TABLE pgtest_test_tables.child (
    id INT
  , pid INT
  , CONSTRAINT pk_child PRIMARY KEY(id)
  , CONSTRAINT fk_child_parent FOREIGN KEY(pid) REFERENCES pgtest_test_tables.parent (id)
  );

  PERFORM pgtest.assert_table_has_fk('pgtest_test_tables', 'child', 'fk_child_parent');
  PERFORM pgtest.remove_table_fk_constraints('pgtest_test_tables', 'child');
  PERFORM pgtest.assert_table_has_not_fk('pgtest_test_tables', 'child', 'fk_child_parent');
  
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;