#!/bin/bash
# This script will sync all of the files in the project with the remote S3
# bucket defined below.  It is helpful when doing development.

display_usage() { 
  echo -e "\nUsage:\ns3-sync.sh -d DIRECTORY -b S3BUCKETNAME -e DEV\n" 
  exit 0
} 

while getopts "d:b:e:h" option; do
  case ${option} in
    d) DIR=$OPTARG;;
    b) BUCKET=$OPTARG;;
    e) ENVIRONMENT=$OPTARG;;
    h) display_usage;;
  esac
done

if [ -z "$BUCKET" ] || [ -z "$ENVIRONMENT" ]
then 
  display_usage
fi 

# In the event that the directory wasn't populated, derive it based on the 
# location of the current script.  This assumes that the scripts folder is
# located directly off the root of the project.
if [ -z "$DIR" ] 
then 
  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."
fi 

aws s3 sync $DIR s3://$BUCKET/$ENVIRONMENT --delete --exclude ".*" --exclude "submodules/*"
