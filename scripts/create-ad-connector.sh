#!/bin/bash
# This script will create an AD Connector, pointing to the current customer
# managed active directory instances (as stored in the SSM Parameter store)

display_usage() { 
  echo -e "\nUsage:\ncreate-ad-connector.sh -e DEV\n" 
  exit 0
} 

while getopts "e:h" option; do
  case ${option} in
    e) env=$OPTARG;;
    h) display_usage;;
  esac
done

if [ -z "$env" ]
then
  echo "The environment wasn't set properly"
  display_usage  
fi

extract_param() {
  local var_name=$1
  echo "/$env$2 -> $var_name"
  local result="$(aws ssm get-parameter --output text --name /$env$2 | cut -f6)"
  if [ -z "$result" ]
  then
    echo "$env$2 couldn't be extracted from the SSM parameter store.  Please ensure that it is populated with a value."
    exit 1
  fi
  eval $var_name=\$result
}

extract_secret() {
  local var_name=$1
  echo "$2 -> $var_name"
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
  echo "$2 -> $var_name"
  local result="$(echo $3 | grep -o '"'$2'" : "[^"]*' | grep -o '[^"]*$')"
  if [ -z "$result" ]
  then
    echo "$2 couldn't be extracted from the secret.  Please double check the formatting, it should be a json string with a username and password value."
    exit 1
  fi
  eval $var_name=\$result
}


echo "Extracting variables from SSM parameter store"
echo "---------------------------------------------"
extract_param name /ActiveDirectory/Domain/DNS/Name
extract_param shortname /ActiveDirectory/Domain/NetBIOS/Name
extract_param vpcid /Foundation/EC2/VPC/Id
extract_param adsubnet1 /ActiveDirectory/1/EC2/Subnet/Id
extract_param adsubnet2 /ActiveDirectory/2/EC2/Subnet/Id
extract_param natsubnet1 /Foundation/NAT/1/EC2/Subnet/Id
extract_param natsubnet2 /Foundation/NAT/2/EC2/Subnet/Id
extract_param dc1 /ActiveDirectory/DomainController/Primary/1/IpAddress
extract_param dc2 /ActiveDirectory/DomainController/Primary/2/IpAddress
extract_param secretid /ActiveDirectory/DomainAdmin/SecretsManager/Secret/Id

echo ""
echo "Extracting values from Secrets Manager"
echo "--------------------------------------"
extract_secret secretvalue $secretid

echo ""
echo "Populating variables with secrets"
echo "---------------------------------"
extract_json adminid username "$secretvalue"
extract_json adminpassword password "$secretvalue"

echo ""
echo "Creating the Active Directory Connector"
echo "---------------------------------------"
directoryid=$(aws ds connect-directory --name $name --short-name $shortname --description 'Created by script create-ad-connector.sh' --size Small --connect-settings VpcId=$vpcid,SubnetIds=$adsubnet1,$adsubnet2,CustomerDnsIps=$dc1,$dc2,CustomerUserName=$adminid --password $adminpassword)

echo "Successfully created directory $directoryid, will wait for activation"

# Wait until the new directory is active
status=Activating
printf "Activating"
until [ $status == Active ]
do
  printf "." 
  status=$(aws ds describe-directories --output text --directory-ids $directoryid | head -1 | cut -f 12)
  sleep 5
done
printf "\n"

echo ""
echo "Registering AD Connector with workspaces"
echo "----------------------------------------"
registered=$(aws workspaces register-workspace-directory --directory-id $directoryid --subnet-ids $natsubnet1 $natsubnet2 --enable-work-docs --enable-self-service --tenancy SHARED) 
echo "Successfully registered AD connector with workspaces $registered"

echo ""
echo "Storing new SSM Parameter with directory id"
echo "-------------------------------------------"
parameter=$(aws ssm put-parameter --description 'The id of the AD connector that points to the primary domain' --name /$env/ActiveDirectory/Domain/DirectoryService/Connector/Id --value $directoryid --type String --overwrite)
if [ -z "$parameter" ]
then
  echo "The directory id couldn't be stored into the SSM parameter store"
  exit 1
fi

echo "Successfully stored the directory id into /$env/ActiveDirectory/Domain/DirectoryService/Connector/Id resulting in $parameter"
