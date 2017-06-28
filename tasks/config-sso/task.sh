#!/bin/bash

set -eux


export ROOT_DIR=`pwd`
export SCRIPT_DIR=$(dirname $0)

TILE_RELEASE=`om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k available-products | grep Pivotal_Single_Sign-On_Service`

PRODUCT_NAME=`echo $TILE_RELEASE | cut -d"|" -f2 | tr -d " "`
PRODUCT_VERSION=`echo $TILE_RELEASE | cut -d"|" -f3 | tr -d " "`

om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k stage-product -p $PRODUCT_NAME -v $PRODUCT_VERSION

TILE_AVAILABILITY_ZONES=$(fn_get_azs $TILE_AZS_SSO)


NETWORK=$(cat <<-EOF
{
  "singleton_availability_zone": {
    "name": "$TILE_AZ_SSO_SINGLETON"
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

RESOURCES=$(cat <<-EOF
{
  "deploy-service-broker": {
    "instance_type": {"id": "automatic"},
    "instances" : 1
  },
  "destroy-broker": {
    "instance_type": {"id": "automatic"},
    "instances" : 1
  }
}
EOF
)

om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k configure-product -n $PRODUCT_NAME  -pn "$NETWORK" -pr "$RESOURCES"
