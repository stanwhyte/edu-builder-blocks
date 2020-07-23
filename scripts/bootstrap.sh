#!/bin/bash
# This script performs the initial provisioning of the S3 bucket that will
# contain the CloudFormation templates and setup instructions.  In addition
# it replaces the REGION and BUCKET text contained in the default README.md
# file with the correct values.

# Once completed, the README.md file's instructions may be followed in order
# to provision the desired workloads.

display_usage() { 
  echo -e "Usage:\nbootstrap.sh -b S3BUCKETNAME -f S3KEYPREFIX -d DIRECTORY"
  echo
  echo -e "For example:\nbootstrap.sh -b foobucket -f cfn/ -d /path/to/project" 
  exit 1
} 

echo

while getopts "f:d:b:h" option; do
  case ${option} in
    d) dir=$OPTARG;;
    b) bucket=$OPTARG;;
    f) folder=$OPTARG;;
    h) display_usage;;
  esac
done

if [ -z "$bucket" ] || [ -z "$dir" ]
then 
  display_usage
fi 

source $dir/scripts/_lib.sh

echo 'Obtain the current region from the active AWS CLI profile'
echo '---------------------------------------------------------'
region=$(aws configure get region)
if [ -z "$region" ]
then 
  echo -e "Could not extract the region from the aws cli settings."
  exit 1
fi 
echo "Obtained $region from the active AWS CLI profile.  To change the active profile, set the AWS_PROFILE as described at https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html"

# Create an S3 bucket in the selected region
cmd="aws s3api create-bucket --bucket $bucket --region $region --acl private --output text"

# The LocationConstraint must be applied for non-default region
if [ "us-east-1" != "$region" ]
then 
  cmd="$cmd --create-bucket-configuration LocationConstraint=$region"
fi 

echo
echo 'Create the S3 bucket'
echo '--------------------'
results=$($cmd)
if [ -z "$results" ]
then 
  echo  "Terminating because there was an error creating the S3 bucket."
  exit 1
fi 
echo -e "Created the S3 bucket with results $results"

echo
echo 'Store the bucket, folder, and region in the SSM Parameter Store'
echo '---------------------------------------------------------------'
bucketparameter=$(aws ssm put-parameter --description 'The S3 bucket name in which the CloudFormation templates will be stored' --name /Bootstrap/CloudFormation/S3/Bucket/Name --value $bucket --type String --overwrite)
regionparameter=$(aws ssm put-parameter --description 'The region for the S3 bucket in which the CloudFormation templates will be stored' --name /Bootstrap/CloudFormation/S3/Bucket/Region --value $region --type String --overwrite)
keyprefixparameter=$(aws ssm put-parameter --description 'The key prefix for the S3 bucket in which the CloudFormation templates will be stored' --name /Bootstrap/CloudFormation/S3/Bucket/KeyPrefix --value $folder --type String --overwrite)

echo -e "Results were bucket: $bucketparameter, keyprefix: $keyprefixparameter,  and region: $regionparameter"
if [ -z "$bucketparameter" ] || [ -z "$regionparameter" ] || [ -z "$keyprefixparameter" ]
then
  echo "One of the SSM Parameters for the S3 bucket could not be stored"
  exit 1
fi

echo
echo 'Replace the BUCKET and REGION text in the README.md with values'
echo '---------------------------------------------------------------'
sed -i '.bak' "s/BUCKET/$bucket/g" "$dir/README.md"
sed -i '' "s/REGION/$region/g" "$dir/README.md"
echo -e "Completed replacement in README.md with BUCKET->$bucket and REGION->$region"
