#!/bin/bash

set -e

CONFIG=$(cat config.json)
AWS=$(echo "${CONFIG}" | jq -r '.aws')
BACKUP_DATE=$(date +"%Y-%m-%dT%H:%M:%S%Z")

# Set environment vars for awscli
export AWS_ACCESS_KEY_ID=$(echo "${AWS}" | jq -r '.access_key_id')
export AWS_SECRET_ACCESS_KEY=$(echo "${AWS}" | jq -r '.secret_access_key')
export AWS_DEFAULT_REGION=$(echo "${AWS}" | jq -r '.region')

# Loop servers
for SERVER_ENCODED in $(echo "${CONFIG}" | jq -r '.servers[] | @base64'); do
  SERVER=$(echo "${SERVER_ENCODED}" | base64 -d)

  S3_BUCKET=$(echo "${SERVER}" | jq -r '.s3_bucket')
  EXCLUDE=$(echo "${SERVER}" | jq -r '.exclude')
  PARAMS="--host=$(echo "${SERVER}" | jq -r '.host') \
    --port=$(echo "${SERVER}" | jq -r '.port') \
    --user=$(echo "${SERVER}" | jq -r '.user') \
    --password=$(echo "${SERVER}" | jq -r '.password')"

  # Get databases
  EXCLUDE_SQL="('$(echo "${EXCLUDE}" | sed -e "s/\s\+/','/g")')"
  DATABASES=$(mysql ${PARAMS} \
    -e "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ${EXCLUDE_SQL}" \
    -s --skip-column-names)

  for DATABASE in ${DATABASES}; do
    DUMP_FILE=$(mktemp)

    mysqldump ${PARAMS} --set-gtid-purged=OFF --triggers --routines --events --single-transaction --quick \
      --databases ${DATABASE} \
    | gzip > ${DUMP_FILE}

    aws s3 mv ${DUMP_FILE} s3://${S3_BUCKET}/${BACKUP_DATE}/${DATABASE}.sql.gz
  done

done