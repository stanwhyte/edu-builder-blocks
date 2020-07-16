#!/bin/bash
# This script will sync all of the files in the project with the remote S3
# bucket defined below.  It is helpful when doing development.

display_usage() { 
  echo -e "\nUsage:\ns3-sync.sh -d DIRECTORY -e DEV\n" 
  exit 0
} 

while getopts "d:e:h" option; do
  case ${option} in
    d) dir=$OPTARG;;
    e) env=$OPTARG;;
    h) display_usage;;
  esac
done

if [ -z "$env" ]
then 
  display_usage
fi 

# In the event that the directory wasn't populated, derive it based on the 
# location of the current script.  This assumes that the scripts folder is
# located directly off the root of the project.
if [ -z "$dir" ] 
then 
  dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."
fi 

extract_param() {
  local var_name=$1
  echo "/$env$2 -> $var_name"
  local result="$(aws ssm get-parameter --output text --name /$env$2 | cut -f7)"
  if [ -z "$result" ]
  then
    echo "$env$2 couldn't be extracted from the SSM parameter store.  Please ensure that it is populated with a value."
    exit 1
  fi
  eval $var_name=\$result
}

echo "Extracting the bucket name from the SSM Parameter store"
extract_param bucket /Bootstrap/CloudFormation/S3/Bucket/Name
if [ -z "$bucket" ]
then 
  echo "The bucket wasn't extracted correctly from the SSM parameter store"
  exit 1
fi 

echo "Synchronizing the S3 bucket with the local files (uploading)"
aws s3 sync $dir s3://$bucket/$env --delete --exclude ".*" --exclude "submodules/*"
