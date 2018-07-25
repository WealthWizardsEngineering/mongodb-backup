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
POST2INFLUX="curl -XPOST --data-binary @- ${INFLUXDB_URL}"

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
              grep -v $(date +%Y-%m-%d) | \
              jq -r '.[]') \
              || { echo -n "database_listing_failed,instance=${REPLICA_SET} value=true" | ${POST2INFLUX} && exit 1; }
echo "Databases to backup:"
echo $DATABASES

# Use this to perform the backup
CMD_BACKUP="mongodump --out /tmp/${BACKUP_NAME} \
 --host ${HOST_STR} \
 --port ${MONGODB_PORT} \
 --authenticationDatabase admin \
 --username ${MONGODB_USER} \
 --password ${MONGODB_PASS}"

# Push to S3 bucket
CMD_S3_PUT="/usr/bin/s3cmd \
 -r put /tmp/${BACKUP_NAME}/${item_str} \
 s3://${BUCKET}/${POLICY_CYCLE}/${BACKUP_NAME}/"


# ****************** Now Do the Work ******************#
# *****************************************************#

# Record the time the whole instance backup started. 
echo "=> Backup started: ${BACKUP_NAME}"
echo -n "instance_backup_started,instance=${REPLICA_SET} value=true" | ${POST2INFLUX}

# Get a list of databases on this host

for item in ${DATABASES}
do
  # Strip remaining quotes
  item_str="${item%\"}"
  echo "Database: ${item_str}"
  echo -n "database_backup_started,instance=${REPLICA_SET},database=${item_str} value=true" | $POST2INFLUX
  ${CMD_BACKUP} --db ${item_str} || { echo -n "database_backup_failed,instance=${REPLICA_SET},database=${item_str} value=true" | $POST2INFLUX; }
  echo -n "database_backup_completed,instance=${REPLICA_SET},database=${item_str} value=true" | $POST2INFLUX
  echo -n "database_s3-put_started,instance=${REPLICA_SET},database=${item_str} value=true" | $POST2INFLUX
  ${CMD_S3_PUT} || { echo -n "database_s3-put_failed,instance=${REPLICA_SET},database=${item_str} value=true" | $POST2INFLUX; }
  echo -n "database_s3-put_completed,instance=${REPLICA_SET},database=${item_str} value=true" | $POST2INFLUX
  rm -Rf /tmp/*
done

echo -n "instance_backup_completed,instance=${REPLICA_SET} value=true" | $POST2INFLUX
echo "=> Backup done"