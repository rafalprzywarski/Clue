set -e
for test in $(ls lua/*_test.lua); do
  (cd lua; lua ../${test})
done
