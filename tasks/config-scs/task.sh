#!/bin/bash

set -e


TILE_RELEASE=`om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k available-products | grep p-spring-cloud-services`

PRODUCT_NAME=`echo $TILE_RELEASE | cut -d"|" -f2 | tr -d " "`
PRODUCT_VERSION=`echo $TILE_RELEASE | cut -d"|" -f3 | tr -d " "`

om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k stage-product -p $PRODUCT_NAME -v $PRODUCT_VERSION

function fn_get_azs {
     local azs_csv=$1
     echo $azs_csv | awk -F "," -v braceopen='{' -v braceclose='}' -v name='"name":' -v quote='"' -v OFS='"},{"name":"' '$1=$1 {print braceopen name quote $0 quote braceclose}'
}

TILE_AVAILABILITY_ZONES=$(fn_get_azs $TILE_AZS_SCS)


NETWORK=$(cat <<-EOF
{
  "singleton_availability_zone": {
    "name": "$TILE_AZ_SCS_SINGLETON"
  },
  "other_availability_zones": [
    $TILE_AVAILABILITY_ZONES
  ],
  "network": {
    "name": "$NETWORK_NAME"
  }
}
EOF
)



TILE_PROPERTIES=$(cat <<-EOF
{
  ".deploy-service-broker.broker_max_instances": {
    "value": ${SCS_MAX_INSTANCES:-100}
  },
  #".deploy-service-broker.buildpack": {
  #  "value": "$SCS_BROKER_APP_BUILDPACK"
  #},
  ".deploy-service-broker.disable_cert_check": {
    "value": ${SCS_SKIP_SSL_VALIDATION:-false}
  },
  ".deploy-service-broker.instances_app_push_timeout": {
    "value": ${SCS_APP_PUSH_TIMEOUT_MINUTES:-null}
  }
}
EOF
)

om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k configure-product -n $PRODUCT_NAME -p "$PROPERTIES" -pn "$NETWORK"
