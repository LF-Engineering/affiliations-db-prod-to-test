#!/bin/bash
if [ -z "$DIR" ]
then
  DIR="${HOME}/go/src/github.com/LF-Engineering/affiliations-db-prod-to-test"
fi
cd "$DIR" || exit 1
prod_access="`cat DB.prod.secret`"
test_access="`cat DB.test.secret`"
# test_access="`cat DB.local.secret`"
if [ -z "${prod_access}" ]
then
  echo "$0: missing prod DB access secret"
  exit 1
fi
if [ -z "${test_access}" ]
then
  echo "$0: missing test DB access secret"
  exit 2
fi
fn=./dump.sql
function cleanup {
  rv=$?
  # cat "${fn}"
  ls -l "${fn}"
  if [ "${rv}" = "0" ]
  then
    rm -f "${fn}" 1>/dev/null 2>&1
  fi
  exit $rv
}
trap cleanup EXIT
date
echo 'dumping from prod'
> "${fn}"
if [ -z "${SKIP_TX}" ]
then
  echo "SET SESSION innodb_lock_wait_timeout=3600;" >> "${fn}"
  #echo "SET GLOBAL innodb_lock_wait_timeout=3600;" >> "${fn}"
  echo "BEGIN;" >> "${fn}"
fi
echo "DELETE FROM changes_cache;" >> "${fn}"
tables="matching_blacklist slug_mapping countries organizations domains_organizations uidentities uidentities_archive profiles profiles_archive identities identities_archive enrollments enrollments_archive"
for table in $tables
do
  echo "DELETE FROM ${table};" >> "${fn}"
done
for table in $tables
do
  date
  echo "dumping ${table}"
  cmd="mysqldump --no-tablespaces --no-create-info --compact --skip-triggers ${prod_access} \"${table}\" >> \"${fn}\""
  # echo "${cmd}"
  eval "${cmd}" || exit 3
done
echo "DELETE FROM changes_cache;" >> "${fn}"
if [ -z "${SKIP_TX}" ]
then
  echo "COMMIT;" >> "${fn}"
  #echo "SET GLOBAL innodb_lock_wait_timeout=120;" >> "${fn}"
fi
date
echo 'restoring to test'
cmd="mysql -A ${test_access} < \"${fn}\""
# echo "${cmd}"
eval "${cmd}" || exit 4
date
echo 'done'
