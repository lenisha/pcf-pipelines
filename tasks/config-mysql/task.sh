#!/bin/bash

set -e


export ROOT_DIR=`pwd`
export SCRIPT_DIR=$(dirname $0)

TILE_RELEASE=`om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k available-products | grep p-mysql`

PRODUCT_NAME=`echo $TILE_RELEASE | cut -d"|" -f2 | tr -d " "`
PRODUCT_VERSION=`echo $TILE_RELEASE | cut -d"|" -f3 | tr -d " "`

om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k stage-product -p $PRODUCT_NAME -v $PRODUCT_VERSION

function fn_get_azs {
     local azs_csv=$1
     echo $azs_csv | awk -F "," -v braceopen='{' -v braceclose='}' -v name='"name":' -v quote='"' -v OFS='"},{"name":"' '$1=$1 {print braceopen name quote $0 quote braceclose}'
}

TILE_AVAILABILITY_ZONES=$(fn_get_azs $TILE_AZS_MYSQL)


NETWORK=$(cat <<-EOF
{
  "singleton_availability_zone": {
    "name": "$TILE_AZ_MYSQL_SINGLETON"
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

# Use MYSQL_TILE_LBR_IP & MYSQL_TILE_STATIC_IPS from nsx-edge-list
# PROPERTIES=$(cat <<-EOF
# {
#   ".proxy.static_ips": {
#     "value": "$TILE_MYSQL_PROXY_IPS"
#   },
#   ".cf-mysql-broker.bind_hostname": {
#     "value": "$TILE_MYSQL_PROXY_VIP"
#   },
#   ".properties.optional_protections.enable.recipient_email": {
#     "value": "$TILE_MYSQL_MONITOR_EMAIL"
#   }
# }
# EOF
# )

PROPERTIES=$(cat <<-EOF
{
  ".proxy.static_ips": {
    "value": "$MYSQL_TILE_STATIC_IPS"
  },
  ".cf-mysql-broker.bind_hostname": {
    "value": "$MYSQL_TILE_LBR_IP"
  },
  ".properties.optional_protections.enable.recipient_email": {
    "value": "$TILE_MYSQL_MONITOR_EMAIL"
  },
  ".properties.syslog": {
    "value": "disabled"
  }
}
EOF
)

RESOURCES=$(cat <<-EOF
{
  "proxy": {
    "instance_type": {"id": "automatic"},
    "instances" : $TILE_MYSQL_PROXY_INSTANCES
  },
  "backup-prepare": {
    "instance_type": {"id": "automatic"},
    "instances" : $TILE_MYSQL_BACKUP_PREPARE_INSTANCES
  },
  "monitoring": {
    "instance_type": {"id": "automatic"},
    "instances" : $TILE_MYSQL_MONITORING_INSTANCES
  },
  "cf-mysql-broker": {
    "instance_type": {"id": "automatic"},
    "instances" : $TILE_MYSQL_BROKER_INSTANCES
  }
}
EOF
)


om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k configure-product -n $PRODUCT_NAME -p "$PROPERTIES" -pn "$NETWORK" -pr "$RESOURCES"
