#!/bin/bash

artifactsFile=$1

filename=$(basename "$artifactsFile")
access_token=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F' -H Metadata:true | jq -r .access_token)
wget --header="x-ms-version: 2019-02-02" --header="Authorization: Bearer $access_token" "$artifactsFile" -O /var/www/html/$filename