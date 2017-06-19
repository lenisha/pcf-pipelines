#!/bin/bash -e

pivnet=`ls tool-pivnet-cli/pivnet-linux-* 2>/dev/null`
echo "chmoding $pivnet"
chmod +x $pivnet

echo "Checking for needed stemcell in metadata"
ls ./pivnet-product
STEMCELL_VERSION=`cat ./pivnet-product/metadata.json | jq --raw-output '.Dependencies[] | select(.Release.Product.Name | contains("Stemcells")) | .Release.Version'`
echo "Stemcell version is $STEMCELL_VERSION"

if [ ! -z "$STEMCELL_VERSION" ]; then
  echo "Stemcell not found in metadata; checking Ops Manager diagnostic report"
  diagnostic_report=$(
    om-linux \
      --target https://$OPS_MGR_HOST \
      --username $OPS_MGR_USR \
      --password $OPS_MGR_PWD \
      --skip-ssl-validation \
      curl --silent --path "/api/v0/diagnostic_report"
  )

  stemcell=$(
    echo $diagnostic_report |
    jq \
      --arg version "$STEMCELL_VERSION" \
      --arg glob "${STEMCELL_GLOB//\*/}" \
    '.stemcells[] | select(contains($version) and contains($glob))'
  )

  if [[ -z "$stemcell" ]]; then
    echo "Downloading stemcell $STEMCELL_VERSION"
    $pivnet -k login --api-token="$PIVNET_API_TOKEN"
    $pivnet -k download-product-files -p stemcells -r $STEMCELL_VERSION -g $STEMCELL_GLOB --accept-eula

    SC_FILE_PATH=`find ./ -name *.tgz`

    if [ ! -f "$SC_FILE_PATH" ]; then
      echo "Stemcell file not found!"
      exit 1
    fi

    om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k upload-stemcell -s $SC_FILE_PATH

    echo "Removing downloaded stemcell $STEMCELL_VERSION"
    rm $SC_FILE_PATH
  fi
  
  echo "Finished stemcells"
fi

echo "Uploading product"
FILE_PATH=`find ./pivnet-product -name *.pivotal`
om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k upload-product -p $FILE_PATH
