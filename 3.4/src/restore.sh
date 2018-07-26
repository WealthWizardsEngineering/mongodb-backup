#!/bin/bash
set -eo pipefail

unset_vars() {
  unset MONGODB_REPLICASET
  unset SERVER_SIDE_ENCRYPTION_KMS_ID
  unset MONGODB_PASS
  unset GPG_PHRASE
  unset ACCESS_KEY
  unset SECRET_KEY
}

clean_environment(){
  rm -Rf /tmp/${BUCKET}
  unset_vars
}
trap clean_environment EXIT

if [[ ${MONGODB_DB} = all ]] ; then
  S3_BACKUP_NAME="${BUCKET}/${POLICY_CYCLE}/${BACKUP_NAME}"
  RESTORE_PATH="/tmp/${BUCKET}/${BACKUP_NAME}/"
  RESTORE_DB=""
else
  S3_BACKUP_NAME="${BUCKET}/${POLICY_CYCLE}/${BACKUP_NAME}/${MONGODB_DB}"
  RESTORE_PATH="/tmp/${BUCKET}/${MONGODB_DB}/"
  RESTORE_DB="--db ${MONGODB_DB}"
fi


POST2INFLUX="curl -XPOST --data-binary @- ${INFLUXDB_URL}"

REPLICA_SET=${MONGODB_REPLICASET}
HOST_STR=${MONGODB_HOST}
[[ ( -n "${MONGODB_REPLICASET}" ) ]] && HOST_STR="${MONGODB_REPLICASET}/${MONGODB_HOST}"
[[ ( -n "${MONGODB_REPLICASET}" ) ]] && REPLICA_SET_STR="replicaSet=${MONGODB_REPLICASET}&"

INFLUXDB_HOSTPORT="influx.wealthwizards.io:8086"
CMD_MKDIR="mkdir -p /tmp/${BUCKET}"

MONGDB_CONNECTION_URI="mongodb://${MONGODB_USER}:${MONGODB_PASS}@${MONGODB_HOST}:${MONGODB_PORT}/admin?${REPLICA_SET_STR}authSource=admin"

CMD_S3_GET="/usr/bin/s3cmd -e \
 --server-side-encryption -r \
 get s3://${S3_BACKUP_NAME} \
 /tmp/${BUCKET}"

CMD_RESTORE="mongorestore \
 --host ${HOST_STR} \
 --port ${MONGODB_PORT} \
 --authenticationDatabase admin \
 --username ${MONGODB_USER} \
 --password ${MONGODB_PASS} \
 ${RESTORE_DB} ${RESTORE_PATH}"

echo "=> Restore database ${MONGODB_DB}"
${CMD_MKDIR}
${CMD_S3_GET}
${CMD_RESTORE}
echo "Restore complete"
echo "=> Done"
