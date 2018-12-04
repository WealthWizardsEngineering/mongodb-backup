#!/bin/bash
set -eo pipefail

# Default to shortest retention period
# If the day/date checks below natch, increase the retention, appropriate to the matched period. 

unset_vars() {
  unset MONGODB_REPLICASET
  unset MONGODB_PASS
  unset GPG_PHRASE
  unset ACCESS_KEY
  unset SECRET_KEY
  echo "Revoking lease: ${VAULT_ADDR}/v1/sys/leases/revoke/${AWS_LEASE_ID}"
  curl -sS --request PUT --header "X-Vault-Token: ${APPROLE_TOKEN}" \
    ${VAULT_ADDR}/v1/sys/leases/revoke/${AWS_LEASE_ID}
}

clean_environment(){
  rm -Rf /tmp/*
  unset_vars
}
trap clean_environment EXIT

# Get AWS keys
source /environment.sh

# Define how we post monitoring status messages
POST2INFLUX() {
  local data=$1
  curl -XPOST --data-binary "${data}" ${INFLUXDB_URL}
}

REPLICA_SET=${MONGODB_REPLICASET}
HOST_STR=${MONGODB_HOST}
[[ ( -n "${MONGODB_REPLICASET}" ) ]] && HOST_STR="${MONGODB_REPLICASET}/${MONGODB_HOST}"
[[ ( -n "${MONGODB_REPLICASET}" ) ]] && REPLICA_SET_STR="replicaSet=${MONGODB_REPLICASET}&"

# Generate the backup name from the date. We have opted to append a more at-a-glance friendly format to the name.
BACKUP_NAME=$(date +\%Y.\%m.\%d.\%H\%M\%S_\%A-\%d-\%B)

# ****************** figure out retention policy ******************#
# *****************************************************************#

POLICY_CYCLE=daily

# Check if it's a Monday
WEEKDAY=$(date +\%A)
case $WEEKDAY in
  "Monday")
    POLICY_CYCLE=weekly
    ;;
esac

# Check if it's the first of the month and assign cycle accordingly (and over-ride weekly, it Monday is the first of the month)
DAYMONTH=$(date +\%d.\%B)
case $DAYMONTH in 
  "01.January")
    POLICY_CYCLE=yearly
    ;;
  "01.April"|"01.July"|"01.October")
    POLICY_CYCLE=quarterly
    ;;
  "01.January"|"01.March"|"01.May"|"01.June"|"01.June"|"01.September"|"01.November"|"01.December")
    POLICY_CYCLE=monthly
    ;;
esac

# ****************** define some commands ******************#
# **********************************************************#

MONGDB_CONNECTION_URI="mongodb://${MONGODB_USER}:${MONGODB_PASS}@${MONGODB_HOST}:${MONGODB_PORT}/admin?${REPLICA_SET_STR}authSource=admin"

# build a list of which databases to backup
DATABASES=$(mongo $MONGDB_CONNECTION_URI --quiet --eval "db.getMongo().getDBNames()" | \
              egrep -v $(date +%Y-%m-%d)\|config | \
              jq -r '.[]') \
              || { POST2INFLUX "database_listing_failed,instance=${REPLICA_SET} value=true" && exit 1; }
echo "Databases to backup:"
echo $DATABASES

backup_db() {
  local db=$1

  POST2INFLUX "database_backup_started,instance=${REPLICA_SET},database=${db} value=true"

  mongodump --db $db \
    --out /tmp/${BACKUP_NAME} \
    --host ${HOST_STR} \
    --port ${MONGODB_PORT} \
    --authenticationDatabase admin \
    --username ${MONGODB_USER} \
    --password ${MONGODB_PASS} \
      || { POST2INFLUX "database_backup_failed,instance=${REPLICA_SET},database=${db} value=true" && return; }

  POST2INFLUX "database_backup_completed,instance=${REPLICA_SET},database=${db} value=true"
}

push_to_s3() {
  local db=$1

  POST2INFLUX "database_s3-put_started,instance=${REPLICA_SET},database=${db} value=true"

  s3cmd put --recursive /tmp/${BACKUP_NAME}/${db} s3://${BUCKET}/${POLICY_CYCLE}/${BACKUP_NAME}/ \
    || { POST2INFLUX "database_s3-put_failed,instance=${REPLICA_SET},database=${db} value=true" && return; }

  POST2INFLUX "database_s3-put_completed,instance=${REPLICA_SET},database=${db} value=true"
}

clean_database() {
  local db=$1
  rm -rf /tmp/${BACKUP_NAME}/${db}
}

# ****************** Now Do the Work ******************#
# *****************************************************#

# Record the time the whole instance backup started. 
echo "=> Backup started: ${BACKUP_NAME}"
POST2INFLUX "instance_backup_started,instance=${REPLICA_SET} value=true"

for db in $DATABASES; do
  backup_db $db
  push_to_s3 $db
  clean_database $db
done

POST2INFLUX "instance_backup_completed,instance=${REPLICA_SET} value=true"
echo "=> Backup done"