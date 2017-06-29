#!/bin/bash

set -eux


export ROOT_DIR=`pwd`
export SCRIPT_DIR=$(dirname $0)

TILE_RELEASE=`om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k available-products | grep p-redis`

PRODUCT_NAME=`echo $TILE_RELEASE | cut -d"|" -f2 | tr -d " "`
PRODUCT_VERSION=`echo $TILE_RELEASE | cut -d"|" -f3 | tr -d " "`

om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k stage-product -p $PRODUCT_NAME -v $PRODUCT_VERSION

function fn_get_azs {
     local azs_csv=$1
     echo $azs_csv | awk -F "," -v braceopen='{' -v braceclose='}' -v name='"name":' -v quote='"' -v OFS='"},{"name":"' '$1=$1 {print braceopen name quote $0 quote braceclose}'
}

function fn_json_string_array {
  local cslist=$1
  echo $cslist | awk -F "[ \t]*,[ \t]*" -v bracketopen='[' -v bracketclose=']' -v quote='"'  -v OFS='","' '$1=$1 {print bracketopen quote $0 quote bracketclose}'
}

TILE_AVAILABILITY_ZONES=$(fn_get_azs $TILE_AZS_REDIS)


NETWORK=$(cat <<-EOF
{
  "singleton_availability_zone": {
    "name": "$TILE_AZ_REDIS_SINGLETON"
  },
  "other_availability_zones": [
    $TILE_AVAILABILITY_ZONES
  ],
  "network": {
    "name": "$NETWORK_NAME"
  },
  "service_network": {
    "name": "$TILE_SERVICE_NETWORK_NAME"
  }
}
EOF
)

AZ_PLACEMENT=$(fn_json_string_array "$TILE_AZ_REDIS_PLAN")

PROPERTIES=$(cat <<-EOF
{
  ".properties.small_plan_selector.active.az_single_select": {
    "value": $AZ_PLACEMENT
  },
  ".properties.small_plan_selector.active.vm_type": {
    "value": "large.disk" 
  },
  ".properties.small_plan_selector.active.disk_size": {
    "value": "30 GB"
  },
  ".properties.medium_plan_selector": {
    "value": "Plan Inactive"
  },
  ".properties.large_plan_selector": {
    "value": "Plan Inactive"
  }
}
EOF
)



om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k configure-product -n $PRODUCT_NAME -p "$PROPERTIES" -pn "$NETWORK" 
