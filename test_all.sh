set -e
for test in $(ls lua/*_test.lua); do
  lua -e "package.path=package.path .. \";./lua/?.lua\"" ${test}
done
