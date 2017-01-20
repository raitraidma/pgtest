CREATE SCHEMA IF NOT EXISTS pgtest;

---------------
-- EXECUTION --
---------------
CREATE OR REPLACE FUNCTION pgtest.f_get_functions_in_schema(s_schema_name VARCHAR)
  RETURNS TABLE (
    function_name VARCHAR
  ) AS
$$
  SELECT routine_name
  FROM information_schema.routines
  WHERE routine_schema = s_schema_name
    AND routine_type = 'FUNCTION'
    AND data_type = 'void';
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_create_error_message(s_returned_sqlstate TEXT, s_message_text TEXT, s_pg_exception_context TEXT)
  RETURNS varchar AS
$$
DECLARE
  s_logging_level VARCHAR;
  s_error_message VARCHAR;
BEGIN
  SHOW client_min_messages INTO s_logging_level;
  s_error_message := 'ERROR' || coalesce(' (' || s_returned_sqlstate || ')', '') || ': ' || coalesce(s_message_text, '');

  IF (upper(s_logging_level) IN ('DEBUG', 'LOG', 'INFO')) THEN
    s_error_message := s_error_message || E'\n' || coalesce(s_pg_exception_context, '');
  END IF;

  RETURN s_error_message;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_run_test(s_schema_name VARCHAR, s_function_name VARCHAR)
  RETURNS varchar AS
$$
DECLARE
  s_returned_sqlstate    TEXT;
  s_message_text         TEXT;
  s_pg_exception_context TEXT;
BEGIN
  EXECUTE 'SELECT ' || s_schema_name || '.' || s_function_name || '();';
  RETURN 'OK';
EXCEPTION
  WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s_returned_sqlstate = RETURNED_SQLSTATE,
                            s_message_text = MESSAGE_TEXT,
                            s_pg_exception_context = PG_EXCEPTION_CONTEXT;
  RETURN f_create_error_message(s_returned_sqlstate, s_message_text, s_pg_exception_context);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.run_tests(s_schema_name VARCHAR)
  RETURNS int AS
$$
DECLARE
  s_function_name VARCHAR;
  t_start_time TIMESTAMP;
  t_end_time TIMESTAMP;
  s_test_result VARCHAR;
  i_test_count INT := 0;
  i_error_count INT := 0;
BEGIN
  t_start_time := clock_timestamp();

  RAISE NOTICE 'Running tests in schema: %', s_schema_name;
  FOR s_function_name IN (SELECT function_name FROM pgtest.f_get_functions_in_schema(s_schema_name))
  LOOP
    i_test_count := i_test_count + 1;
    RAISE NOTICE 'Running test: %.%', s_schema_name, s_function_name;
    s_test_result := pgtest.f_run_test(s_schema_name, s_function_name);
    RAISE NOTICE '%', s_test_result;
    IF (s_test_result <> 'OK') THEN
      i_error_count := i_error_count + 1;
    END IF;
  END LOOP;

  t_end_time := clock_timestamp();
  RAISE NOTICE 'Executed % tests of which % failed in %', i_test_count, i_error_count, (t_end_time - t_start_time);

  RETURN i_error_count;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;

----------------
-- ASSERTIONS --
----------------

DO $BODY$
DECLARE
  s_data_type_name VARCHAR;
BEGIN
  FOR s_data_type_name IN (
    SELECT unnest(ARRAY['BIGINT', 'BIT', 'BOOLEAN', 'CHAR', 'VARCHAR', 'DOUBLE PRECISION', 'INT', 'REAL', 'SMALLINT', 'TEXT', 'TIME', 'TIMETZ', 'TIMESTAMP', 'TIMESTAMPTZ', 'XML'])
  ) LOOP
    EXECUTE format('CREATE OR REPLACE FUNCTION pgtest.assert_equals(s_expected_value %s, s_real_value %1$s)
                      RETURNS void AS
                    $$
                    BEGIN
                      IF (NOT(s_expected_value = s_real_value)) THEN
                        RAISE EXCEPTION ''Expected: %%. But was: %%'', s_expected_value, s_real_value;
                      END IF;
                    END
                    $$ LANGUAGE plpgsql
                      SECURITY DEFINER
                      SET search_path=pgtest, pg_temp;', s_data_type_name);

    EXECUTE format('CREATE OR REPLACE FUNCTION pgtest.assert_not_equals(s_not_expected_value %s, s_real_value %1$s)
                      RETURNS void AS
                    $$
                    BEGIN
                      IF (s_not_expected_value = s_real_value) THEN
                        RAISE EXCEPTION ''Not expected: %%. But was: %%'', s_not_expected_value, s_real_value;
                      END IF;
                    END
                    $$ LANGUAGE plpgsql
                      SECURITY DEFINER
                      SET search_path=pgtest, pg_temp;', s_data_type_name);
  END LOOP;
END
$BODY$;


CREATE OR REPLACE FUNCTION pgtest.assert_true(b_value BOOLEAN)
  RETURNS void AS
$$
BEGIN
  IF (NOT(b_value)) THEN
    RAISE EXCEPTION 'Expected: TRUE. But was: FALSE';
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_false(b_value BOOLEAN)
  RETURNS void AS
$$
BEGIN
  IF (b_value) THEN
    RAISE EXCEPTION 'Expected: FALSE. But was: TRUE';
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


DO language plpgsql $$
BEGIN
  RAISE NOTICE 'PgTest installed!';
END
$$;
