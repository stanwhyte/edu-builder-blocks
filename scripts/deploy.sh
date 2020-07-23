#!/bin/bash
# This script will sync all of the files in the project with the remote S3
# bucket defined below.  It is helpful when doing development.

display_usage() { 
  echo -e "Usage:\ndeploy.sh -d DIRECTORY" 
  exit 1
} 

while getopts "d:h" option; do
  case ${option} in
    d) dir=$OPTARG;;
    h) display_usage;;
  esac
done

echo

if [ -z "$dir" ]
then
  display_usage
fi

source $dir/scripts/_lib.sh

echo 'Extracting the bucket name from the SSM Parameter store'
echo '-------------------------------------------------------'
extract_param bucket /Bootstrap/CloudFormation/S3/Bucket/Name
extract_param folder /Bootstrap/CloudFormation/S3/Bucket/KeyPrefix
if [ -z "$bucket" ]
then 
  echo "The bucket wasn't extracted correctly from the SSM parameter store"
  exit 1
fi 
echo "Extracted the bucket from the SSM Parameter store $bucket/$folder"

echo
echo 'Synchronizing the S3 bucket with the local files (uploading)'
echo '------------------------------------------------------------'
aws s3 sync $dir s3://$bucket/$folder --delete --exclude ".*" --exclude "submodules/*"
echo "Synchronization complete"
