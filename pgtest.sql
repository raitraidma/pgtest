DROP SCHEMA IF EXISTS pgtest CASCADE;
CREATE SCHEMA IF NOT EXISTS pgtest;

---------------
-- EXECUTION --
---------------
DROP SEQUENCE IF EXISTS pgtest.unique_id;
CREATE SEQUENCE pgtest.unique_id CYCLE;


CREATE OR REPLACE FUNCTION pgtest.f_get_test_functions_in_schema(s_schema_name VARCHAR)
  RETURNS TABLE (
    function_name VARCHAR
  ) AS
$$
  SELECT routine_name
  FROM information_schema.routines
  WHERE routine_schema = s_schema_name
    AND routine_type = 'FUNCTION'
    AND data_type = 'void'
    AND routine_name ~* 'test_.*'
  ORDER BY routine_name ASC;
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


CREATE OR REPLACE FUNCTION pgtest.f_json_object_values_to_array(j_json_object JSON)
  RETURNS TEXT[] AS
$$
  SELECT array_agg(j.value) FROM (SELECT (json_each_text(j_json_object)).value) j;
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_run_test(s_schema_name VARCHAR, s_function_name VARCHAR, b_rollback BOOLEAN DEFAULT TRUE)
  RETURNS varchar AS
$$
DECLARE
  s_returned_sqlstate    TEXT;
  s_message_text         TEXT;
  s_pg_exception_context TEXT;
BEGIN
  IF (pgtest.f_function_exists(s_schema_name, 'before', ARRAY[]::VARCHAR[])) THEN
    EXECUTE 'SELECT ' || s_schema_name || '.before();';
  END IF;

  EXECUTE 'SELECT ' || s_schema_name || '.' || s_function_name || '();';

  IF (pgtest.f_function_exists(s_schema_name, 'after', ARRAY[]::VARCHAR[])) THEN
    EXECUTE 'SELECT ' || s_schema_name || '.after();';
  END IF;
  
  IF (b_rollback) THEN
    RAISE EXCEPTION 'OK' USING ERRCODE = '40004';
  END IF;
  RETURN 'OK';
EXCEPTION
  WHEN SQLSTATE '40004' THEN
    RETURN 'OK';
  WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s_returned_sqlstate = RETURNED_SQLSTATE,
                            s_message_text = MESSAGE_TEXT,
                            s_pg_exception_context = PG_EXCEPTION_CONTEXT;
    RETURN f_create_error_message(s_returned_sqlstate, s_message_text, s_pg_exception_context);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_get_function_description(s_schema_name VARCHAR, s_function_name VARCHAR, s_function_argument_types VARCHAR[])
  RETURNS json AS
$$
  WITH function_info AS (
  SELECT
    r.specific_catalog
  , r.specific_schema
  , r.specific_name
  , r.routine_schema
  , r.routine_name
  , (CASE
      WHEN r.data_type = 'ARRAY' THEN ret.data_type::VARCHAR || '[]'
      WHEN r.data_type = 'USER-DEFINED' THEN r.type_udt_schema || '.' || r.type_udt_name
      ELSE r.data_type
  END) AS routine_data_type
  , r.security_type
  , p.parameter_mode::VARCHAR
  , p.parameter_name::VARCHAR
  , (CASE
      WHEN p.data_type = 'ARRAY' THEN et.data_type::VARCHAR || '[]'
      WHEN p.data_type = 'USER-DEFINED' THEN p.udt_schema || '.' || p.udt_name
      ELSE p.data_type::VARCHAR
  END) AS parameter_data_type
  , p.parameter_default::VARCHAR
  , p.ordinal_position
  FROM information_schema.routines r
  LEFT JOIN information_schema.parameters p ON (r.specific_catalog = p.specific_catalog AND r.specific_schema = p.specific_schema AND r.specific_name = p.specific_name)
  LEFT JOIN information_schema.element_types et ON (
     (p.specific_catalog, p.specific_schema, p.specific_name, 'ROUTINE', p.dtd_identifier)
   = (et.object_catalog, et.object_schema, et.object_name, et.object_type, et.collection_type_identifier)
  )
  LEFT JOIN information_schema.element_types ret ON (
     (r.specific_catalog, r.specific_schema, r.specific_name, 'ROUTINE', r.dtd_identifier)
   = (ret.object_catalog, ret.object_schema, ret.object_name, ret.object_type, ret.collection_type_identifier)
  )
  WHERE r.routine_schema = s_schema_name
    AND r.routine_name = s_function_name
    AND r.routine_type = 'FUNCTION'
), function_descriptions AS (
  SELECT DISTINCT
    fi.routine_schema
  , fi.routine_name
  , (CASE
       WHEN fi.routine_data_type <> 'record' THEN fi.routine_data_type
       ELSE 'TABLE (' ||
         (SELECT array_to_string(array_agg(fi_pm.parameter_name || ' ' || fi_pm.parameter_data_type ORDER BY fi_pm.ordinal_position ASC), ',')
          FROM function_info fi_pm
          WHERE (fi.specific_catalog, fi.specific_schema, fi.specific_name, 'OUT') = (fi_pm.specific_catalog, fi_pm.specific_schema, fi_pm.specific_name, fi_pm.parameter_mode)
         )
       || ')'
     END) AS routine_data_type
  , fi.security_type
  , (SELECT coalesce(array_agg(fi_pm.parameter_mode ORDER BY fi_pm.ordinal_position ASC), ARRAY[]::VARCHAR[]) FROM function_info fi_pm
     WHERE (fi.specific_catalog, fi.specific_schema, fi.specific_name, 'IN') = (fi_pm.specific_catalog, fi_pm.specific_schema, fi_pm.specific_name, fi_pm.parameter_mode)
    ) AS parameter_modes
  , (SELECT coalesce(array_agg(fi_pm.parameter_name ORDER BY fi_pm.ordinal_position ASC), ARRAY[]::VARCHAR[]) FROM function_info fi_pm
     WHERE (fi.specific_catalog, fi.specific_schema, fi.specific_name, 'IN') = (fi_pm.specific_catalog, fi_pm.specific_schema, fi_pm.specific_name, fi_pm.parameter_mode)
    ) AS parameter_names
  , (SELECT coalesce(array_agg(fi_pm.parameter_data_type ORDER BY fi_pm.ordinal_position ASC), ARRAY[]::VARCHAR[]) FROM function_info fi_pm
     WHERE (fi.specific_catalog, fi.specific_schema, fi.specific_name, 'IN') = (fi_pm.specific_catalog, fi_pm.specific_schema, fi_pm.specific_name, fi_pm.parameter_mode)
    ) AS parameter_data_types
  , (SELECT coalesce(array_agg(fi_pm.parameter_default ORDER BY fi_pm.ordinal_position ASC), ARRAY[]::VARCHAR[]) FROM function_info fi_pm
     WHERE (fi.specific_catalog, fi.specific_schema, fi.specific_name, 'IN') = (fi_pm.specific_catalog, fi_pm.specific_schema, fi_pm.specific_name, fi_pm.parameter_mode)
    ) AS parameter_defaults
  FROM function_info fi
) SELECT row_to_json(fd)
  FROM function_descriptions fd
  WHERE fd.parameter_data_types = s_function_argument_types;
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_relation_exists(s_schema_name VARCHAR, s_table_name VARCHAR, s_table_type VARCHAR)
  RETURNS boolean AS
$$
  SELECT EXISTS ( SELECT 1
                  FROM pg_class c
                  LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
                  WHERE n.nspname LIKE s_schema_name
                  AND c.relname = s_table_name
                  AND c.relkind = s_table_type);
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_extension_exists(s_extension_name VARCHAR)
  RETURNS boolean AS
$$
  SELECT EXISTS(SELECT 1 FROM pg_catalog.pg_extension WHERE extname = s_extension_name);
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_column_type(s_schema_name VARCHAR, s_relation_name VARCHAR, s_column_name VARCHAR)
  RETURNS varchar AS
$$
  SELECT pg_catalog.format_type(t.oid, NULL)
  FROM pg_catalog.pg_class c
  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  LEFT JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid
  LEFT JOIN pg_catalog.pg_type t ON a.atttypid = t.oid
  WHERE c.relkind IN ('v', 'm', 'r')
    AND n.nspname = s_schema_name
    AND c.relname = s_relation_name
    AND a.attname = s_column_name
    AND a.attnum > 0
    AND NOT a.attisdropped;
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_function_exists(s_schema_name VARCHAR, s_function_name VARCHAR, s_function_argument_types VARCHAR[])
  RETURNS boolean AS
$$
  SELECT pgtest.f_get_function_description(s_schema_name, s_function_name, s_function_argument_types) IS NOT NULL;
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_get_function_parameters(j_original_function_description JSON)
  RETURNS varchar AS
$$
DECLARE
  s_parameters VARCHAR := '';
  s_parameter_modes VARCHAR[];
  s_parameter_names VARCHAR[];
  s_parameter_data_types VARCHAR[];
  s_parameter_defaults VARCHAR[];
  i_position INT;
BEGIN
  SELECT
    array_agg(f2.parameter_mode) AS parameter_modes
  , array_agg(f2.parameter_name) AS parameter_names
  , array_agg(f2.parameter_data_type) AS parameter_data_types
  , array_agg(f2.parameter_default) AS parameter_defaults
  INTO
    s_parameter_modes, s_parameter_names, s_parameter_data_types, s_parameter_defaults
  FROM (
    SELECT
      json_array_elements_text(j_original_function_description->'parameter_modes') AS parameter_mode
    , json_array_elements_text(j_original_function_description->'parameter_names') AS parameter_name
    , json_array_elements_text(j_original_function_description->'parameter_data_types') AS parameter_data_type
    , json_array_elements_text(j_original_function_description->'parameter_defaults') AS parameter_default
  ) f2;

  IF (s_parameter_data_types[1] IS NULL) THEN
    RETURN '';
  END IF;

  FOR i_position IN 1 .. array_length(s_parameter_data_types, 1) LOOP
    IF (i_position > 1) THEN
      s_parameters := s_parameters || ', ';
    END IF;
    s_parameters := s_parameters || coalesce(s_parameter_modes[i_position], '') || ' '
                                 || coalesce(s_parameter_names[i_position], '') || ' '
                                 || coalesce(s_parameter_data_types[i_position], '') || ' '
                                 || coalesce(' DEFAULT ' || s_parameter_defaults[i_position], '');
  END LOOP;

  RETURN s_parameters;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_create_mock_function(s_mock_id VARCHAR, j_original_function_description JSON, s_mock_function_schema_name VARCHAR, s_mock_function_name VARCHAR)
  RETURNS void AS
$$
DECLARE
  s_call_method VARCHAR := 'RETURN';
BEGIN
  IF ((j_original_function_description->>'routine_data_type') = 'void') THEN
    s_call_method := 'PERFORM';
  ELSIF ((j_original_function_description->>'routine_data_type') LIKE 'TABLE%') THEN
    s_call_method := 'RETURN QUERY SELECT * FROM';
  END IF;

  EXECUTE format('CREATE FUNCTION %1$s.%2$s(%3$s)
                    RETURNS %4$s AS
                  $MOCK$
                  DECLARE
                    s_mock_id VARCHAR := ''%5$s'';
                    s_arguments JSON;
                  BEGIN
                    s_arguments := to_json(ARRAY[%9$s]::TEXT[]);
                    
                    UPDATE temp_pgtest_mock
                    SET times_called = times_called + 1
                      , called_with_arguments = array_to_json(array_append(array(SELECT * FROM json_array_elements(called_with_arguments)), s_arguments))
                    WHERE mock_id = s_mock_id;

                    %6$s %7$s.%8$s(%9$s);
                  END
                  $MOCK$ LANGUAGE plpgsql
                    SECURITY %10$s
                    SET search_path=%1$s, pg_temp;'
  , j_original_function_description->>'routine_schema'
  , j_original_function_description->>'routine_name'
  , pgtest.f_get_function_parameters(j_original_function_description)
  , j_original_function_description->>'routine_data_type'
  , s_mock_id
  , s_call_method
  , s_mock_function_schema_name
  , s_mock_function_name
  , (SELECT string_agg(t.names, ',') FROM (SELECT json_array_elements_text(j_original_function_description->'parameter_names') AS names) t)
  , j_original_function_description->>'security_type'
  );
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_mock_or_spy(s_type VARCHAR, s_original_function_schema_name VARCHAR, s_original_function_name VARCHAR, s_function_argument_types VARCHAR[], s_mock_function_schema_name VARCHAR DEFAULT NULL, s_mock_function_name VARCHAR DEFAULT NULL)
  RETURNS varchar AS
$$
DECLARE
  s_mock_id VARCHAR := 'pgtest_mock_' || md5(random()::text) || '_' || nextval('pgtest.unique_id');
  j_original_function_description JSON;
BEGIN
  j_original_function_description := pgtest.f_get_function_description(s_original_function_schema_name, s_original_function_name, s_function_argument_types);
  IF (j_original_function_description IS NULL) THEN
    RAISE EXCEPTION 'Could not find function to spy: %.%(%)', s_original_function_schema_name, s_original_function_name, array_to_string(s_function_argument_types, ',');
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS temp_pgtest_mock(
    mock_id VARCHAR UNIQUE
  , times_called INT DEFAULT 0
  , called_with_arguments JSON DEFAULT '[]'::JSON
  ) ON COMMIT DROP;

  INSERT INTO temp_pgtest_mock(mock_id) VALUES (s_mock_id);

  EXECUTE 'ALTER FUNCTION ' || s_original_function_schema_name || '.' || s_original_function_name || '(' || array_to_string(s_function_argument_types, ',') || ') RENAME TO ' || s_original_function_name || '_' || s_mock_id || ';';

  IF (s_type = 'SPY') THEN
    PERFORM pgtest.f_create_mock_function(s_mock_id, j_original_function_description, s_original_function_schema_name, s_original_function_name || '_' || s_mock_id);
  ELSIF (s_type = 'MOCK') THEN
    PERFORM pgtest.f_create_mock_function(s_mock_id, j_original_function_description, s_mock_function_schema_name, s_mock_function_name);
  ELSE
    RAISE EXCEPTION 'Unknown type: %', s_type;
  END IF;

  RETURN s_mock_id;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_get_called_times(s_mock_id VARCHAR)
  RETURNS int AS
$$
DECLARE
  i_actual_times_called INT;
BEGIN
  SELECT times_called
  INTO i_actual_times_called
  FROM temp_pgtest_mock
  WHERE mock_id = s_mock_id;

  RETURN i_actual_times_called;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_prepare_statement(s_statement text)
  RETURNS text AS
$$
DECLARE
  s_cleaned_statement TEXT := btrim(rtrim(s_statement, ';'));
  s_match_1 TEXT := '^[[:space:]]*(SELECT)[[:space:]]';
  s_match_2 TEXT := '^[[:space:]]*(VALUES)[[:space:]]*\(';
BEGIN
  IF ((s_cleaned_statement ~* s_match_1) OR (s_cleaned_statement ~* s_match_2)) THEN
    RETURN s_cleaned_statement;
  END IF;
  RETURN 'SELECT * FROM ' || s_cleaned_statement;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION pgtest.fails(s_message TEXT)
  RETURNS void AS
$$
BEGIN
  RAISE EXCEPTION '%', s_message USING ERRCODE = '40005';
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.run_tests(s_schema_names VARCHAR[])
  RETURNS int AS
$$
DECLARE
  s_function_name VARCHAR;
  s_schema_name VARCHAR;
  t_test_suite_start_time TIMESTAMP;
  t_test_suite_end_time TIMESTAMP;
  t_test_start_time TIMESTAMP;
  t_test_end_time TIMESTAMP;
  s_test_result VARCHAR;
  i_test_count INT := 0;
  i_error_count INT := 0;
  s_failed_tests TEXT[];
BEGIN
  t_test_suite_start_time := clock_timestamp();

  FOREACH s_schema_name IN ARRAY s_schema_names LOOP
    RAISE NOTICE 'Running tests in schema: %', s_schema_name;
    FOR s_function_name IN (SELECT function_name FROM pgtest.f_get_test_functions_in_schema(s_schema_name))
    LOOP
      i_test_count := i_test_count + 1;
      RAISE NOTICE 'Running test: %.%', s_schema_name, s_function_name;
      t_test_start_time := clock_timestamp();
      s_test_result := pgtest.f_run_test(s_schema_name, s_function_name);
      t_test_end_time := clock_timestamp();
      RAISE NOTICE '(%) %', (t_test_end_time-t_test_start_time), s_test_result;
      IF (s_test_result <> 'OK') THEN
        i_error_count := i_error_count + 1;
        s_failed_tests := array_append(s_failed_tests, s_schema_name || '.' || s_function_name);
      END IF;
    END LOOP;
  END LOOP;

  t_test_suite_end_time := clock_timestamp();

  IF (array_length(s_failed_tests, 1) > 0) THEN
    RAISE NOTICE E'Failed tests:\n%', array_to_string(s_failed_tests, E'\n');
  END IF;

  RAISE NOTICE 'Executed % tests of which % failed in %', i_test_count, i_error_count, (t_test_suite_end_time - t_test_suite_start_time);
  RAISE EXCEPTION 'PgTest ended.';
EXCEPTION
  WHEN OTHERS THEN
    RETURN i_error_count;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.run_tests(s_schema_name VARCHAR)
  RETURNS int AS
$$
BEGIN
  RETURN pgtest.run_tests(ARRAY[s_schema_name]);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.run_tests_like(s_schema_name_pattern VARCHAR)
  RETURNS int AS
$$
  SELECT pgtest.run_tests(array_agg(schema_name)) FROM (
    SELECT schema_name::VARCHAR AS schema_name
    FROM information_schema.schemata
    WHERE schema_name LIKE s_schema_name_pattern
    ORDER BY schema_name
  ) t
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;

----------------
-- ASSERTIONS --
----------------

CREATE OR REPLACE FUNCTION pgtest.assert_equals(x_expected_value ANYELEMENT, x_actual_value ANYELEMENT, s_message TEXT DEFAULT 'Expected: %1$s. But was: %2$s.')
  RETURNS void AS
$$
BEGIN
  IF (NOT(x_expected_value = x_actual_value)
      OR (x_expected_value IS NULL AND x_actual_value IS NOT NULL)
      OR (x_expected_value IS NOT NULL AND x_actual_value IS NULL)
  ) THEN
    PERFORM pgtest.fails(format(s_message, x_expected_value, x_actual_value));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_not_equals(x_not_expected_value ANYELEMENT, x_actual_value ANYELEMENT, s_message TEXT DEFAULT 'Not expected: %1$s. But was: %2$s.')
  RETURNS void AS
$$
BEGIN
  IF (x_not_expected_value = x_actual_value) THEN
    PERFORM pgtest.fails(format(s_message, x_not_expected_value, x_actual_value));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_true(b_value BOOLEAN, s_message TEXT DEFAULT 'Expected: TRUE. But was: FALSE.')
  RETURNS void AS
$$
BEGIN
  IF (NOT(b_value)) THEN
    PERFORM pgtest.fails(s_message);
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_false(b_value BOOLEAN, s_message TEXT DEFAULT 'Expected: FALSE. But was: TRUE.')
  RETURNS void AS
$$
BEGIN
  IF (b_value) THEN
    PERFORM pgtest.fails(s_message);
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_null(x_value ANYELEMENT, s_message TEXT DEFAULT 'Expected: NULL. But was: %1$s.')
  RETURNS void AS
$$
BEGIN
  IF (x_value IS NOT NULL) THEN
    PERFORM pgtest.fails(format(s_message, x_value));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_not_null(x_value ANYELEMENT, s_message TEXT DEFAULT 'Not expected to be NULL.')
  RETURNS void AS
$$
BEGIN
  IF (x_value IS NULL) THEN
    PERFORM pgtest.fails(s_message);
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_rows(s_expected_result_query TEXT, s_actual_result_query TEXT, s_message TEXT DEFAULT 'Expected row: %1$s. Actual row: %2$s.')
  RETURNS void AS
$$
DECLARE
  s_expected_result_query TEXT := pgtest.f_prepare_statement(s_expected_result_query);
  s_actual_result_query TEXT := pgtest.f_prepare_statement(s_actual_result_query);
  s_error_messages TEXT := '';
  r_record RECORD;
BEGIN
  FOR r_record IN EXECUTE '(' || s_expected_result_query || ') EXCEPT (' || s_actual_result_query || ')' LOOP
    s_error_messages := s_error_messages || format(s_message, r_record, '()') || E'\n';
  END LOOP;

  FOR r_record IN EXECUTE '(' || s_actual_result_query || ') EXCEPT (' || s_expected_result_query || ')' LOOP
    s_error_messages := s_error_messages || format(s_message, '()', r_record) || E'\n';
  END LOOP;

  PERFORM pgtest.assert_equals('', s_error_messages, btrim(s_error_messages));
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_table_exists(s_schema_name VARCHAR, s_table_name VARCHAR, s_message TEXT DEFAULT 'Table %1$s.%2$s does not exist.')
  RETURNS void AS
$$
BEGIN
  IF (NOT pgtest.f_relation_exists(s_schema_name, s_table_name, 'r')) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_table_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_table_does_not_exist(s_schema_name VARCHAR, s_table_name VARCHAR, s_message TEXT DEFAULT 'Table %1$s.%2$s exists.')
  RETURNS void AS
$$
BEGIN
  IF (pgtest.f_relation_exists(s_schema_name, s_table_name, 'r')) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_table_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_temp_table_exists(s_table_name VARCHAR, s_message TEXT DEFAULT 'Temp table %1$s does not exist.')
  RETURNS void AS
$$
BEGIN
  IF (NOT pgtest.f_relation_exists('pg_temp%', s_table_name, 'r')) THEN
    PERFORM pgtest.fails(format(s_message, s_table_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_temp_table_does_not_exist(s_table_name VARCHAR, s_message TEXT DEFAULT 'Temp table %1$s exists.')
  RETURNS void AS
$$
BEGIN
  IF (pgtest.f_relation_exists('pg_temp%', s_table_name, 'r')) THEN
    PERFORM pgtest.fails(format(s_message, s_table_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_view_exists(s_schema_name VARCHAR, s_view_name VARCHAR, s_message TEXT DEFAULT 'View %1$s.%2$s does not exist.')
  RETURNS void AS
$$
BEGIN
  IF (NOT pgtest.f_relation_exists(s_schema_name, s_view_name, 'v')) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_view_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_view_does_not_exist(s_schema_name VARCHAR, s_view_name VARCHAR, s_message TEXT DEFAULT 'View %1$s.%2$s exists.')
  RETURNS void AS
$$
BEGIN
  IF (pgtest.f_relation_exists(s_schema_name, s_view_name, 'v')) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_view_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_mat_view_exists(s_schema_name VARCHAR, s_mat_view_name VARCHAR, s_message TEXT DEFAULT 'Materialized view %1$s.%2$s does not exist.')
  RETURNS void AS
$$
BEGIN
  IF (NOT pgtest.f_relation_exists(s_schema_name, s_mat_view_name, 'm')) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_mat_view_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_mat_view_does_not_exist(s_schema_name VARCHAR, s_mat_view_name VARCHAR, s_message TEXT DEFAULT 'Materialized view %1$s.%2$s exists.')
  RETURNS void AS
$$
BEGIN
  IF (pgtest.f_relation_exists(s_schema_name, s_mat_view_name, 'm')) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_mat_view_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.f_relation_has_column(s_schema_name VARCHAR, s_relation_name VARCHAR, s_column_name VARCHAR)
  RETURNS boolean AS
$$
  SELECT EXISTS ( SELECT 1
                  FROM pg_catalog.pg_class c
                  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                  LEFT JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid
                  WHERE c.relkind IN ('v', 'm', 'r')
                  AND n.nspname = s_schema_name
                  AND c.relname = s_relation_name
                  AND a.attname = s_column_name
                  AND a.attnum > 0
                  AND NOT a.attisdropped);
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_relation_has_column(s_schema_name VARCHAR, s_relation_name VARCHAR, s_column_name VARCHAR, s_message TEXT DEFAULT 'Table "%1$s.%2$s" does not have column "%3$s".')
  RETURNS void AS
$$
BEGIN
  IF (NOT pgtest.f_relation_has_column(s_schema_name, s_relation_name, s_column_name)) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_relation_name, s_column_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_relation_does_not_have_column(s_schema_name VARCHAR, s_relation_name VARCHAR, s_column_name VARCHAR, s_message TEXT DEFAULT 'Table "%1$s.%2$s" has column "%3$s".')
  RETURNS void AS
$$
BEGIN
  IF (pgtest.f_relation_has_column(s_schema_name, s_relation_name, s_column_name)) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_relation_name, s_column_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_function_exists(s_schema_name VARCHAR, s_function_name VARCHAR, s_function_argument_types VARCHAR[] DEFAULT ARRAY[]::VARCHAR[], s_message TEXT DEFAULT 'Function "%1$s.%2$s(%3$s)" does not exist.')
  RETURNS void AS
$$
BEGIN
  IF (NOT pgtest.f_function_exists(s_schema_name, s_function_name, s_function_argument_types)) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_function_name, array_to_string(s_function_argument_types, ', ')));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_function_does_not_exist(s_schema_name VARCHAR, s_function_name VARCHAR, s_function_argument_types VARCHAR[] DEFAULT ARRAY[]::VARCHAR[], s_message TEXT DEFAULT 'Function "%1$s.%2$s(%3$s)" exists.')
  RETURNS void AS
$$
BEGIN
  IF (pgtest.f_function_exists(s_schema_name, s_function_name, s_function_argument_types)) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_function_name, array_to_string(s_function_argument_types, ', ')));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_extension_exists(s_extension_name VARCHAR, s_message TEXT DEFAULT 'Extension "%1$s" does not exist.')
  RETURNS void AS
$$
BEGIN
  IF (NOT pgtest.f_extension_exists(s_extension_name)) THEN
    PERFORM pgtest.fails(format(s_message, s_extension_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_extension_does_not_exist(s_extension_name VARCHAR, s_message TEXT DEFAULT 'Extension "%1$s" exists.')
  RETURNS void AS
$$
BEGIN
  IF (pgtest.f_extension_exists(s_extension_name)) THEN
    PERFORM pgtest.fails(format(s_message, s_extension_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_column_type(s_schema_name VARCHAR, s_relation_name VARCHAR, s_column_name VARCHAR, s_expected_column_type VARCHAR, s_message TEXT DEFAULT 'Column "%3$s" in table "%1$s.%2$s" expects to be type of "%4$s", but is type of "%5$s".')
  RETURNS void AS
$$
DECLARE
  s_actual_column_type VARCHAR := pgtest.f_column_type(s_schema_name, s_relation_name, s_column_name);
BEGIN
  IF (NOT (s_actual_column_type = s_expected_column_type)) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_relation_name, s_column_name, s_expected_column_type, s_actual_column_type));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_not_column_type(s_schema_name VARCHAR, s_relation_name VARCHAR, s_column_name VARCHAR, s_not_expected_column_type VARCHAR, s_message TEXT DEFAULT 'Column "%3$s" in table "%1$s.%2$s" expects not to be type of "%4$s", but it is.')
  RETURNS void AS
$$
DECLARE
  s_actual_column_type VARCHAR := pgtest.f_column_type(s_schema_name, s_relation_name, s_column_name);
BEGIN
  IF (s_actual_column_type = s_not_expected_column_type) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_relation_name, s_column_name, s_not_expected_column_type));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_table_has_fk(s_schema_name VARCHAR, s_table_name VARCHAR, s_constraint_name VARCHAR, s_message TEXT DEFAULT 'Table "%1$s.%2$s" expects to have foreign key "%3$s", but it has not.')
  RETURNS void AS
$$
BEGIN
  IF (NOT EXISTS (SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
      AND table_schema = s_schema_name 
      AND table_name = s_table_name
      AND constraint_name = s_constraint_name)) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_table_name, s_constraint_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_table_has_not_fk(s_schema_name VARCHAR, s_table_name VARCHAR, s_constraint_name VARCHAR, s_message TEXT DEFAULT 'Table "%1$s.%2$s" expects not to have foreign key "%3$s", but it has.')
  RETURNS void AS
$$
BEGIN
  IF (EXISTS (SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
      AND table_schema = s_schema_name 
      AND table_name = s_table_name
      AND constraint_name = s_constraint_name)) THEN
    PERFORM pgtest.fails(format(s_message, s_schema_name, s_table_name, s_constraint_name));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


------------------
-- MOCK AND SPY --
------------------
CREATE OR REPLACE FUNCTION pgtest.spy(s_original_function_schema_name VARCHAR, s_original_function_name VARCHAR, s_function_argument_types VARCHAR[])
  RETURNS varchar AS
$$
BEGIN
  RETURN pgtest.f_mock_or_spy('SPY', s_original_function_schema_name, s_original_function_name, s_function_argument_types);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.mock(s_original_function_schema_name VARCHAR, s_original_function_name VARCHAR, s_function_argument_types VARCHAR[], s_mock_function_schema_name VARCHAR, s_mock_function_name VARCHAR)
  RETURNS varchar AS
$$
BEGIN
  RETURN pgtest.f_mock_or_spy('MOCK', s_original_function_schema_name, s_original_function_name, s_function_argument_types, s_mock_function_schema_name, s_mock_function_name);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_called(s_mock_id VARCHAR, i_expected_times_called INT DEFAULT 1, s_message TEXT DEFAULT 'Function expected to be called %1$s time(s). But it was called %2$s time(s).')
  RETURNS void AS
$$
DECLARE
  i_actual_times_called INT := pgtest.f_get_called_times(s_mock_id);
BEGIN
  IF (i_actual_times_called IS NULL) THEN
    PERFORM pgtest.fails(format('Mock with id "%" not found.', s_mock_id));
  ELSIF (i_expected_times_called < 0) THEN
    PERFORM pgtest.fails(format('Expected times called must be >= 0 not %.', i_expected_times_called));
  ELSIF (i_expected_times_called <> i_actual_times_called) THEN
    PERFORM pgtest.fails(format(s_message, i_expected_times_called, i_actual_times_called));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_called_at_least_once(s_mock_id VARCHAR, s_message TEXT DEFAULT 'Function expected to be called at least once.')
  RETURNS void AS
$$
DECLARE
  i_actual_times_called INT := pgtest.f_get_called_times(s_mock_id);
BEGIN
  IF (i_actual_times_called = 0) THEN
    PERFORM pgtest.fails(s_message);
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_called_with_arguments(s_mock_id VARCHAR, s_expected_arguments TEXT[], i_call_time INT, s_message TEXT DEFAULT 'Function expected to be called %1$s. time with arguments %2$s. But they were %3$s.')
  RETURNS void AS
$$
DECLARE
  i_actual_times_called INT;
  j_called_with_arguments JSON;
  s_actual_arguments TEXT[];
BEGIN
  SELECT times_called, called_with_arguments
  INTO i_actual_times_called, j_called_with_arguments
  FROM temp_pgtest_mock
  WHERE mock_id = s_mock_id;

  IF (i_call_time > i_actual_times_called) THEN
    PERFORM pgtest.fails(format('Checking for parameters in call number % but only % call(s) were made.', i_call_time, i_actual_times_called));
  ELSIF (i_call_time < 1) THEN
    PERFORM pgtest.fails(format('Call time must be >= 1 not %.', i_call_time));
  END IF;

  SELECT array(SELECT json_array_elements_text((j_called_with_arguments)->(i_call_time-1))) INTO s_actual_arguments;

  IF (NOT(array(SELECT json_array_elements_text((j_called_with_arguments)->(i_call_time-1))) = s_expected_arguments)) THEN
    PERFORM pgtest.fails(format(s_message, i_call_time, s_expected_arguments, s_actual_arguments));
  END IF;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.assert_called_with_arguments(s_mock_id VARCHAR, s_expected_arguments TEXT[], s_message TEXT DEFAULT 'Function expected to be called with arguments %1$s.')
  RETURNS void AS
$$
DECLARE
  j_called_with_arguments JSON;
  s_actual_arguments TEXT[];
  j_argument_list JSON;
BEGIN
  SELECT called_with_arguments
  INTO j_called_with_arguments
  FROM temp_pgtest_mock
  WHERE mock_id = s_mock_id;

  FOR j_argument_list IN SELECT * FROM json_array_elements(j_called_with_arguments)
  LOOP
    IF (array(SELECT json_array_elements_text(j_argument_list)) = s_expected_arguments) THEN
      RETURN;
    END IF;
  END LOOP;
  
  PERFORM pgtest.fails(format(s_message, s_expected_arguments));
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;

-------------
-- HELPERS --
-------------
CREATE OR REPLACE FUNCTION pgtest.remove_table_fk_constraints(s_schema_name VARCHAR, s_table_name VARCHAR)
  RETURNS void AS
$$
DECLARE
  s_constraint_name VARCHAR;
BEGIN
  FOR s_constraint_name IN (
    SELECT constraint_name
    FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
      AND table_schema = s_schema_name 
      AND table_name = s_table_name
  ) LOOP
    EXECUTE 'ALTER TABLE ' || s_schema_name || '.' || s_table_name || ' DROP CONSTRAINT ' || s_constraint_name;
  END LOOP;
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


CREATE OR REPLACE FUNCTION pgtest.coverage(s_function_schemas VARCHAR[], s_test_schemas VARCHAR[])
RETURNS TABLE (
  schema_name VARCHAR
, function_name VARCHAR
, is_covered BOOLEAN
) AS $$
  SELECT
    fun_n.nspname::VARCHAR AS schema_name
  , fun_p.proname::VARCHAR AS function_name
  , count(test_n.nspname) > 0 AS is_covered
  FROM pg_proc fun_p
  JOIN pg_namespace fun_n ON fun_n.oid = fun_p.pronamespace
  LEFT JOIN pg_proc test_p ON (test_p.proname ~* 'test_.*' AND test_p.prosrc ~* ('.*' || fun_p.proname || '\s*\(.*'))
  LEFT JOIN pg_namespace test_n ON (test_n.nspname = ANY(s_test_schemas) AND test_n.oid = test_p.pronamespace)
  WHERE fun_n.nspname = ANY(s_function_schemas)
  GROUP BY fun_n.nspname, fun_p.proname
$$ LANGUAGE sql
  SECURITY DEFINER
  SET search_path=pgtest, pg_temp;


DO LANGUAGE plpgsql $$
BEGIN
  RAISE NOTICE 'PgTest installed!';
END
$$;