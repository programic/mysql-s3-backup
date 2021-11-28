#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

config=$(cat config.json)
aws=$(echo "${config}" | jq -r '.aws')
backup_date=$(date +"%Y-%m-%dT%H:%M:%S%Z")

# Set environment vars for awscli
export AWS_ACCESS_KEY_ID=$(echo "${aws}" | jq -r '.access_key_id')
export AWS_SECRET_ACCESS_KEY=$(echo "${aws}" | jq -r '.secret_access_key')
export AWS_DEFAULT_REGION=$(echo "${aws}" | jq -r '.region')

# Loop servers
for server_encoded in $(echo "${config}" | jq -r '.servers[] | @base64'); do
  server=$(echo "${server_encoded}" | base64 -d)

  s3_bucket=$(echo "${server}" | jq -r '.s3_bucket')
  exclude=$(echo "${server}" | jq -r '.exclude')
  login_params="--host=$(echo "${server}" | jq -r '.host') \
    --port=$(echo "${server}" | jq -r '.port') \
    --user=$(echo "${server}" | jq -r '.user') \
    --password=$(echo "${server}" | jq -r '.password')"

  # Get available databases, skip excluded
  exclude_sql="('$(echo "${exclude}" | sed -e "s/\s\+/','/g")')"
  databases=$(mysql ${login_params} \
    -e "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ${exclude_sql}" \
    -s --skip-column-names)

  # Loop databases
  for database in ${databases}; do
    dump_file=$(mktemp)

    # Backup single database
    mysqldump ${login_params} \
      --set-gtid-purged=OFF --triggers --routines --events --single-transaction --quick \
      --databases ${database} \
    | gzip > ${dump_file}

    # Upload backup to AWS S3
    aws s3 mv ${dump_file} s3://${s3_bucket}/${backup_date}/${database}.sql.gz
  done

done

# Send pingback after backup is finished
pingback=$(echo "${config}" | jq -r '.pingback')
pingback_url=$(echo "${pingback}" | jq -r '.url')
pingback_retry=$(echo "${pingback}" | jq -r '.retry')

if [[ $pingback_url ]]; then
  curl --retry ${pingback_retry} ${pingback_url}
fi