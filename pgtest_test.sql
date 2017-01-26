DROP SCHEMA IF EXISTS pgtest_test CASCADE;
CREATE SCHEMA pgtest_test;

CREATE OR REPLACE FUNCTION pgtest_test.f_test_function()
  RETURNS boolean AS
$$
  SELECT true;
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;

CREATE OR REPLACE FUNCTION pgtest_test.f_test_function_mock()
  RETURNS boolean AS
$$
  SELECT false;
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;

-----------
-- Tests --
-----------
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


CREATE OR REPLACE FUNCTION pgtest_test.test_assert_equals_compares_same_text()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_equals('some text', 'some text');
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
    PERFORM pgtest.assert_equals('some text', 'some other text');
  EXCEPTION
    WHEN OTHERS THEN b_pass := TRUE;
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
  PERFORM pgtest.assert_not_equals('some text', 'some other text');
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
    PERFORM pgtest.assert_not_equals('some text', 'some text');
  EXCEPTION
    WHEN OTHERS THEN b_pass := TRUE;
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
    PERFORM pgtest.assert_equals('some text', 'some other text');
  EXCEPTION
    WHEN OTHERS THEN
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
    PERFORM pgtest.assert_equals('some text', 'some other text', 'First: %1$s. Second: %2$s.');
  EXCEPTION
    WHEN OTHERS THEN
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


CREATE OR REPLACE FUNCTION pgtest_test.test_mock_1_mock_changes_function_implementation()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_true(pgtest_test.f_test_function());
  PERFORM pgtest.mock('pgtest_test', 'f_test_function', '', 'pgtest_test', 'f_test_function_mock');
  PERFORM pgtest.assert_false(pgtest_test.f_test_function());
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


CREATE OR REPLACE FUNCTION pgtest_test.test_mock_2_mock_is_rolled_back_after_previous_test()
  RETURNS void AS
$$
BEGIN
  PERFORM pgtest.assert_true(pgtest_test.f_test_function());
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest_test, pg_temp;


SELECT pgtest.run_tests('pgtest_test');