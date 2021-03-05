#!/bin/bash
if [ -z "$DIR" ]
then
  DIR="${HOME}/go/src/github.com/LF-Engineering/affiliations-db-prod-to-test"
fi
cd "$DIR" || exit 1
prod_access="`cat DB.prod.secret`"
# test_access="`cat DB.test.secret`"
test_access="`cat DB.local.secret`"
fn=/tmp/dump.sql
function cleanup {
  cat "${fn}"
  # rm -f "${fn}" 1>/dev/null 2>&1
}
trap cleanup EXIT
date
echo 'dumping from prod'
echo "BEGIN;" > "${fn}"
for table in countries
do
  date
  echo "dumping ${table}"
  echo "DELETE FROM ${table};" >> "${fn}"
  cmd="mysqldump --no-create-info --compact ${prod_access} \"${table}\" >> \"${fn}\""
  echo "${cmd}"
  eval "${cmd}" || exit 2
done
echo "COMMIT;" >> "${fn}"
date
echo 'restoring to test'
cmd="mysql ${test_access} < \"${fn}\""
echo "${cmd}"
eval "${cmd}" || exit 3
date
echo 'done'
