#!/bin/bash
set -e

cd pcfawsops-terraform-state-get
  db_host=$(terraform output --json | jq --raw-output '.sql_instance_ip.value')
cd -

if [ -z "$db_host" ]; then
  echo Failed to get SQL instance IP from Terraform state file
  exit 1
fi

sed -i \
  -e "s/{{db_host}}/${db_host}/g" \
  -e "s/{{gcloud_sql_instance_username}}/${pcf_opsman_admin}/g" \
  -e "s/{{gcloud_sql_instance_password}}/${pcf_opsman_passwd}/g" \
  -e "s/{{gcp_storage_access_key}}/${gcp_storage_access_key}/g" \
  -e "s/{{gcp_storage_secret_key}}/${gcp_storage_secret_key}/g" \
  json_file/ert.json
