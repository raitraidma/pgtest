#!/bin/bash

test_result=`(psql -d pgtest -U postgres -t -c "SELECT pgtest.run_tests('pgtest_test');")`
exit $test_result;