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


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_query_equals_compares_resultset_against_correct_query()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_query_equals(ARRAY[
    ARRAY['a','b'],
    ARRAY['c','d']
  ],
  'SELECT ''a'', ''b''
   UNION ALL
   SELECT ''c'', ''d''
  '
  );
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_simple_mock_1_mock_changes_function_implementation()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_true(pgtest_test.f_test_function('a'));
  PERFORM pgtest.simple_mock('pgtest_test', 'f_test_function', 'character varying, integer, text', 'pgtest_test', 'f_test_function_mock');
  PERFORM pgtest.assert_false(pgtest_test.f_test_function('a'));
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_simple_mock_2_mock_is_rolled_back_after_previous_test()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_true(pgtest_test.f_test_function('a'));
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
  PERFORM pgtest.assert_mock_called(s_mock_id, 3);
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
  PERFORM pgtest.assert_mock_called_with_arguments(s_mock_id, ARRAY['b', '1', 'def'], 1);
  PERFORM pgtest.assert_mock_called_with_arguments(s_mock_id, ARRAY['c', '1', 'def'], 2);
  PERFORM pgtest.assert_mock_called_with_arguments(s_mock_id, ARRAY['d', '1', 'def'], 3);
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
    PERFORM pgtest.assert_mock_called_with_arguments(s_mock_id, ARRAY['d'], 2);
  EXCEPTION
    WHEN SQLSTATE '40005' THEN b_pass := TRUE;
  END;
  PERFORM pgtest.assert_true(b_pass, 'assert_mock_called_with_arguments should throw exception, because arguments do not match.');
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


CREATE OR REPLACE FUNCTION pgtest_test.test_before_after()
  RETURNS void AS
$$
BEGIN
  BEGIN
    CREATE SCHEMA pgtest_test_hooks;

    CREATE TABLE pgtest_test_hooks.execution (
      id INT
    , type VARCHAR
    );

    CREATE OR REPLACE FUNCTION pgtest_test_hooks.before()
      RETURNS void AS
    $TEST$
    BEGIN
      INSERT INTO pgtest_test_hooks.execution(id, type) VALUES (2, 'BEFORE');
    END
    $TEST$ LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path=pgtest_test_hooks, pg_temp;

    CREATE OR REPLACE FUNCTION pgtest_test_hooks.test_test()
      RETURNS void AS
    $TEST$
    BEGIN
      INSERT INTO pgtest_test_hooks.execution(id, type) VALUES (3, 'TEST');
    END
    $TEST$ LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path=pgtest_test_hooks, pg_temp;

    CREATE OR REPLACE FUNCTION pgtest_test_hooks.after()
      RETURNS void AS
    $TEST$
    BEGIN
      INSERT INTO pgtest_test_hooks.execution(id, type) VALUES (4, 'AFTER');
    END
    $TEST$ LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path=pgtest_test_hooks, pg_temp;

    PERFORM set_config('pgtest.test_rollback_enabled', 'false', false);

    PERFORM pgtest.f_run_test('pgtest_test_hooks', 'test_test');
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

  PERFORM set_config('pgtest.test_rollback_enabled', 'true', false);

  PERFORM pgtest.assert_query_equals(ARRAY[
    ARRAY['2','BEFORE'],
    ARRAY['3','TEST'],
    ARRAY['4','AFTER']
  ], 'SELECT id, type FROM pgtest_test_hooks.execution ORDER BY id ASC');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


SELECT pgtest.run_tests('pgtest_test');