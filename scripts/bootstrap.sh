#!/bin/bash
# This script performs the initial provisioning of the S3 bucket that will
# contain the CloudFormation templates and setup instructions.  In addition
# it replaces the REGION and BUCKET text contained in the default README.md
# file with the correct values.

# Once completed, the README.md file's instructions may be followed in order
# to provision the desired workloads.

display_usage() { 
  echo -e "Usage:\nbootstrap.sh -d DIRECTORY"
  echo
  echo -e "For example:\nbootstrap.sh -d /path/to/project" 
  exit 1
} 

echo

while getopts "d:h" option; do
  case ${option} in
    d) dir=$OPTARG;;
    h) display_usage;;
  esac
done

if [ -z "$dir" ]
then 
  display_usage
fi 

source $dir/scripts/_lib.sh

echo
echo 'Launching the Bootstrap stack'
echo '-----------------------------'
stack=$(aws cloudformation create-stack --stack-name bootstrap --template-body file://$dir/templates/deploy/bootstrap.yaml)

if [ -z "$stack" ]
then
  echo -e "Couldn't create the CloudFormation stack."
  exit 1
fi

echo "Wait until the bootstrap CloudFormation stack has deployed successfully."
read -p 'Press any key to continue once the stack has deployed...' -n 1 -r nul

echo
echo 'Extracting parameters from SSM Parameter Store'
echo '----------------------------------------------'
extract_param bucket /Bootstrap/CloudFormation/S3/Bucket/Name
extract_param region /Bootstrap/CloudFormation/S3/Bucket/Region

echo
echo 'Replace the BUCKET and REGION text in the README.md with values'
echo '---------------------------------------------------------------'
sed "s/BUCKET/$bucket/g" "$dir/README.md" > "$dir/README.md.tmp"
sed "s/REGION/$region/g" "$dir/README.md.tmp" > "$dir/README.md"
rm "$dir/README.md.tmp"
echo -e "Executed replacement in README.md with BUCKET->$bucket and REGION->$region"
