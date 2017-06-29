#!/bin/bash

set -e


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
  }
  "service network": {
    "name": "$NETWORK_NAME"
  }
}
EOF
)


PROPERTIES=$(cat <<-EOF
{
  ".properties.small_plan_selector.active.az_single_select": {
    "value": "$TILE_AZ_REDIS_SINGLETON"
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
