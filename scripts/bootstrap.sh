#!/bin/bash
# This script performs the initial provisioning of the S3 bucket that will
# contain the CloudFormation templates and setup instructions.  In addition
# it replaces the REGION and BUCKET text contained in the default README.md
# file with the correct values.

# Once completed, the README.md file's instructions may be followed in order
# to provision the desired workloads.

display_usage() { 
  echo -e "\nUsage:\nbootstrap.sh -e ENVIRONMENT -b S3BUCKETNAME -d DIRECTORY\n"
  echo -e "For example:\nbootstrap.sh -e DEV -b foobucket -d /foo/baz" 
  exit 1
} 

while getopts "d:b:e:h" option; do
  case ${option} in
    d) dir=$OPTARG;;
    b) bucket=$OPTARG;;
    e) env=$OPTARG;;
    h) display_usage;;
  esac
done

if [ -z "$bucket" ] || [ -z "$env" ]
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
echo -e "Using the following working directory: $dir \n"


# Obtain the current region from the AWS CLI profile (the active one)
region=$(aws configure get region)
if [ -z "$region" ]
then 
  echo -e "Could not extract the region from the aws cli settings."
  exit 1
fi 
echo -e "Obtained the following region from the AWS cli active profile: $region.  To change the active profile, set the AWS_PROFILE as described at https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html\n"


# Create an S3 bucket in the selected region
cmd="aws s3api create-bucket --bucket $bucket --region $region --acl private --output text"

# The LocationConstraint must be applied for non-default region
if [ "us-east-1" != "$region" ]
then 
  cmd="$cmd --create-bucket-configuration LocationConstraint=$region"
fi 

echo -e "Creating the S3 bucket\n"
results=$($cmd)
if [ -z "$results" ]
then 
  echo -e "Terminating because there was an error creating the S3 bucket.\n"
  exit 1
fi 

echo -e "Storing the bucket name and region in the SSM Parameter Store\n"
# Store the chosen region and bucket names in the SSM Parameter Store
bucketparameter=$(aws ssm put-parameter --description 'The S3 bucket name in which the CloudFormation templates will be stored' --name /$env/Bootstrap/CloudFormation/S3/Bucket/Name --value $bucket --type String --overwrite)
regionparameter=$(aws ssm put-parameter --description 'The region for the S3 bucket in which the CloudFormation templates will be stored' --name /$env/Bootstrap/CloudFormation/S3/Bucket/Region --value $region --type String --overwrite)

if [ -z "$bucketparameter" ] || [ -z "$regionparameter" ]
then
  echo "One of the two SSM Parameters for bucket or region could not be stored"
  exit 1
fi

# Search and replace the REGION and BUCKET values in the README.md
echo -e "Replacing the BUCKET and REGION text in the README.md with values.\n"
sed -i '.bak' "s/BUCKET/$bucket/g" "$dir/README.md"
sed -i '' "s/REGION/$region/g" "$dir/README.md"
