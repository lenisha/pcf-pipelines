#!/bin/bash
set -e

json_file="json_file/ert.json"

#############################################################
#################### GCP Auth  & functions ##################
#############################################################
echo $gcp_svc_acct_key > /tmp/blah
gcloud auth activate-service-account --key-file /tmp/blah
rm -rf /tmp/blah

gcloud config set project $gcp_proj_id
gcloud config set compute/region $gcp_region


#############################################################
# get GCP unique SQL instance ID & set params in JSON       #
#############################################################
gcloud_sql_instance_cmd="gcloud sql instances list --format json | jq --raw-output '.[] | select(.instance | startswith(\"${terraform_prefix}\")) | .instance'"
gcloud_sql_instance=$(eval ${gcloud_sql_instance_cmd})
gcloud_sql_instance_ip=$(gcloud sql instances list | grep ${gcloud_sql_instance} | awk '{print$4}')
perl -pi -e "s/{{db_host}}/${gcloud_sql_instance_ip}/g" ${json_file}

perl_cmd="perl -pi -e \"s/{{gcloud_sql_instance_username}}/${pcf_opsman_admin}/g\" ${json_file}"
perl_cmd=$(echo $perl_cmd | sed 's/\@/\\@/g')
eval $perl_cmd

perl_cmd="perl -pi -e \"s/{{gcloud_sql_instance_password}}/${pcf_opsman_admin_passwd}/g\" ${json_file}"
perl_cmd=$(echo $perl_cmd | sed 's/\@/\\@/g')
eval $perl_cmd

#############################################################
# Set GCP Storage Setup for GCP Buckets                     #
#############################################################

perl -pi -e "s|{{gcp_storage_access_key}}|${gcp_storage_access_key}|g" ${json_file}
perl -pi -e "s|{{gcp_storage_secret_key}}|${gcp_storage_secret_key}|g" ${json_file}
