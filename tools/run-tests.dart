// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// MEASURE=0
// STARTTIME=
// ACCUMULATOR=0
// if [[ $1 == "--measure" ]]; then
//   MEASURE=1
//   STARTTIME=`date +%s.%N`
//   shift
// fi
// 
// if [[ -d $1 || -f $1 ]]; then
//    TESTNAME=$1
// fi
// 
// T20="./t20"
// TESTS_DIR="tests"
// FLAGS_FILE=".flags"
// SUCCESSES=0
// FAILURES=0
// SKIPPED=0
// TICK=$(echo -ne '\x27\x14' | iconv -f utf-16be)
// CROSS=$(echo -ne '\x27\x18' | iconv -f utf-16be)
// MINUS=$(echo -ne '\x00\xF7' | iconv -f utf-16be)
// export T20_COMPILER_ENABLE_ASSERTS=1
// 
// function runtests()
// {
//   local dir=$1
//   local subdir=$2
//   local expectation=$3
//   local flags=
//   if [[ -f "$dir/$subdir/$FLAGS_FILE" ]]; then
//     flags=$(head -n 1 "$dir/$subdir/$FLAGS_FILE")
//   fi
//   echo -e "\033[1m== Running tests in $dir/$subdir ==\033[0m"
//   for file in $(ls "$dir/$subdir" | grep "\.t20$"); do
//     local test="$dir/$subdir/$file"
//     if grep -q ";; SKIP" $test; then
//       echo -e "\033[1;33m$MINUS\033[0m ${elapsed_str}$test"
//       SKIPPED=$(($SKIPPED + 1))
//       continue
//     fi
//     runtest "$flags" "$test" $expectation
//   done
// }
// 
// function runtest()
// {
//     local flags=$1
//     local test=$2
//     local expectation=$3
// 
//     local starttime=
//     local endtime=
//     local elapsed=
//     local elapsed_str=
// 
//     local stdout_log=$(mktemp)
//     local stderr_log=$(mktemp)
// 
//     local cmd="$T20 $flags $test > $stdout_log 2> $stderr_log"
//     if [[ $MEASURE -eq 1 ]]; then
//       starttime=`date +%s.%N`
//     fi
//     eval $cmd
//     actual=$?
//     if [[ $MEASURE -eq 1 ]]; then
//       endtime=`date +%s.%N`
//       elapsed=`echo "$endtime - $starttime" | bc`
//       local elapsed_fmt=`echo $elapsed | awk -F"." '{print $1"."substr($2,1,3)}'`
//       elapsed_str="[${elapsed_fmt}s] "
//       ACCUMULATOR=`echo "$ACCUMULATOR + $elapsed" | bc`
//     fi
// 
// 
//     if [[ $actual -eq $expectation ]]; then
//       echo -e "\033[1;32m$TICK\033[0m ${elapsed_str}$test"
//       SUCCESSES=$(($SUCCESSES + 1))
//     else
//       FAILURES=$(($FAILURES + 1))
//       echo -e "\033[1;31m$CROSS\033[0m ${elapsed_str}$test"
//       echo "command: $cmd"
//       echo "exit code: $actual"
//       echo -n "stdout:"
//       if [[ -s $stdout_log ]]; then
//         echo ""
//         cat $stdout_log | sed 's/^/    /'
//       else
//         echo " (empty)"
//       fi
//       echo -n "stderr:"
//       if [[ -s $stderr_log  ]]; then
//         echo ""
//         cat $stderr_log | sed 's/^/    /'
//       else
//         echo " (empty)"
//       fi
//     fi
// 
//     rm -f $stdout_log
//     rm -f $stderr_log
// }
// 
// if [[ -d $TESTNAME ]]; then
//     if [[ -d "$TESTNAME/pass" ]]; then
//         runtests $TESTNAME "pass" 0
//     elif [[ $(basename $TESTNAME) == "pass" ]]; then
//         runtests $TESTNAME "" 0
//     fi
// 
//     if [[ -d "$TESTNAME/fail" ]]; then
//         runtests $TESTNAME "fail" 10
//     elif [[ $(basename $TESTNAME) == "fail" ]]; then
//         runtests $TESTNAME "" 10
//     fi
// elif [[ -f $TESTNAME ]]; then
//     directory=$(dirname $TESTNAME)
//     expectation=$(basename $directory)
//     if [[ $expectation == "pass" ]]; then
//         if [[ -f "$(dirname $TESTNAME)/$FLAGS_FILE" ]]; then
//             flags=$(head -n 1 "$(dirname $TESTNAME)/$FLAGS_FILE")
//             runtest "$flags" $TESTNAME 0
//         else
//             runtest "" $TESTNAME 0
//         fi
//     elif [[ $expectation == "fail" ]]; then
//         if [[ -f "$(dirname $TESTNAME)/$FLAGS_FILE" ]]; then
//             flags=$(head -n 1 "$(dirname $TESTNAME)/$FLAGS_FILE")
//             runtest "$flags" $TESTNAME 10
//         else
//             runtest "" $TESTNAME 10
//         fi
//     else
//         echo "Cannot run test script without an expectation."
//     fi
// else
//     for dir in $(ls -d $TESTS_DIR/*); do
//         # Run pass and fail tests, if they exists.
//         if [[ -d "$dir/pass" ]]; then
//             runtests $dir "pass" 0
//         fi
// 
//         if [[ -d "$dir/fail" ]]; then
//             runtests $dir "fail" 10
//         fi
//     done
// fi
// 
// echo -e "\033[1m== Summary ==\033[0m"
// echo -e "# \033[1;32m$TICK\033[0m successes: $SUCCESSES"
// echo -e "# \033[1;31m$CROSS\033[0m  failures: $FAILURES\033[0m"
// echo -e "# \033[1;33m$MINUS\033[0m   skipped: $SKIPPED\033[0m"
// if [[ $MEASURE -eq 1 ]]; then
//   ENDTIME=`date +%s.%N`
//   ELAPSED=`echo "$ENDTIME - $STARTTIME" | bc`
//   ELAPSED_FMT=`echo $ELAPSED | awk -F"." '{print $1"."substr($2,1,3)}'`
//   ACCUMULATED_FMT=`echo $ACCUMULATOR | awk -F"." '{print $1"."substr($2,1,3)}'`
//   OVERHEAD=`echo "$ELAPSED - $ACCUMULATOR" | bc | awk -F"." '{print $1"."substr($2,1,3)}'`
//   echo -e "\033[1m== Running time statistics ==\033[0m"
//   echo "# Total running time: ${ELAPSED_FMT}s"
//   echo "# Accumulated test running time: ${ACCUMULATED_FMT}s"
//   echo "# Test script overhead: ${OVERHEAD}s"
// fi
// 
// if [[ $FAILURES -ne 0 ]]; then
//   exit 1
// else
//   exit 0
// fi