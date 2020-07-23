#!/bin/bash
# This script contains some commonly used functions

extract_param() {
  local var_name=$1
  echo "Extracting $2 to $var_name from SSM Parameter Store"
  local result="$(aws ssm get-parameter --output text --name $2 | cut -f7)"
  if [ -z "$result" ]
  then
    echo "$2 couldn't be extracted from the SSM parameter store.  Please ensure that it is populated with a value."
    exit 1
  fi
  eval $var_name=\$result
}

extract_secret() {
  local var_name=$1
  echo "Extracting $2 to $var_name from Secrets Manager"
  local result="$(aws secretsmanager get-secret-value --output text --secret-id $2 --version-stage AWSCURRENT | cut -f4)"
  if [ -z "$result" ]
  then
    echo "$2 couldn't be extracted from Secrets Manager.  Please ensure that it is populated with a value."
    exit 1
  fi
  eval $var_name=\$result
}

extract_json() {
  local var_name=$1
  echo "Pulling $2 -> $var_name from json blob"
  local result="$(echo $3 | grep -o '"'$2'" : "[^"]*' | grep -o '[^"]*$')"
  if [ -z "$result" ]
  then
    echo "$2 couldn't be extracted from the json blob.  Please double check the formatting, it should be a json string with a username and password value."
    exit 1
  fi
  eval $var_name=\$result
}
