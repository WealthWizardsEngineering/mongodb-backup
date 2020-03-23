#!/bin/bash
set -eo pipefail

unset_vars() {
  unset MONGODB_REPLICASET
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

HOST_STR=${MONGODB_HOST}
[[ ( -n "${MONGODB_REPLICASET}" ) ]] && HOST_STR="${MONGODB_REPLICASET}/${MONGODB_HOST}"
[ -z "${MONGODB_USE_RDS_SSL}" ] || MONGODB_SSL_STR="--ssl --sslCAFile /etc/ssl/certs/rds-combined-ca-bundle.pem"

CMD_MKDIR="mkdir -p /tmp/${BUCKET}"

CMD_S3_GET="s3cmd get --recursive s3://${S3_BACKUP_NAME} /tmp/${BUCKET}"

CMD_RESTORE="mongorestore \
 --host ${HOST_STR} \
 --port ${MONGODB_PORT} ${MONGODB_SSL_STR} \
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
