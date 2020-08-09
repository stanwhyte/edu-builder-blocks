#!/bin/bash
# This script simply prints the instructions for how one should configure
# AWS SSO to use with an AppStream Stack created by the EDU Builder Blocks
# project.

display_usage() { 
  echo -e "Usage:\ncreate-appstream-sso-stack.sh -d DIRECTORY -n STACKNAME" 
  exit 1
} 

while getopts "d:n:h" option; do
  case ${option} in
    d) dir=$OPTARG;;
    n) stackname=$OPTARG;;
    h) display_usage;;
  esac
done

echo

if [ -z "$dir" ] || [ -z "$stackname" ]
then
  display_usage
fi

if ! [[ "$stackname" =~ ^[0-9A-Za-z]+$ ]]
then
  echo "The stack name must be an alphanumeric value."
  exit 1
fi

source $dir/scripts/_lib.sh

accountid=$(aws sts get-caller-identity --output text | cut -f1)
if [ -z "$accountid" ]
then
  echo -e "Could not extract the account id from the aws cli."
  exit 1
fi

echo "Extracting variables from SSM parameter store"
echo "---------------------------------------------"
extract_param region /Bootstrap/CloudFormation/S3/Bucket/Region
extract_param bucket_url /Bootstrap/CloudFormation/S3/Bucket/Url

echo ""
echo "Configure AWS SSO AppStream Application"
echo "---------------------------------------"
relaystate="https://appstream2.$region.aws.amazon.com/saml?stack=$stackname&accountId=$accountid"
echo "Follow these intructions to create the AWS SSO application for AppStream "
echo "2.0 and download the metadata."
echo ""
echo "1. From the AWS SSO Dashboard, choose Applications from the left pane."
echo "2. Choose Add a new application."
echo "3. On the Add New Application page, search for and select AppStream 2.0"
echo "4. Enter a display name, for example 'Engineering Lab'. This name "
echo "   appears in the user portal."
echo "5. Provide an optional description."
echo "6. In the AWS SSO metadata section, choose Download to the right of the "
echo "   AWS SSO SAML metadata file section. This is the metadata file that is "
echo "   used to create the IAM Identity Provider later on in this setup."
echo "7. In the Application Properties section, keep Application start URL as "
echo "   blank, and enter the AppStream 2.0 Relay State URL:  "
echo "     $relaystate"
echo "8. Save the Application.  You should receive a confirmation that the new "
echo "   application has been saved."

echo ""
echo "Creating AppStream identity provider"
echo "------------------------------------"
read -p 'Enter path to metadata file (i.e. /foo/metadata.xml): ' metadata
if ! [[ -f "$metadata" ]]
then
  echo "The file $metadata does not appear to be a valid file path."
  echo "Please run the script again, and enter a valid path to the metadata"
  echo "generated in the previous step."
  exit 1
fi

idpname="SSO_AppStream_$stackname"
echo "Creating saml-provider $idpname with metadata at $metadata"
idp=$(aws iam create-saml-provider --output text --saml-metadata-document file://$metadata --name $idpname)

if [ -z "$idp" ]
then
  echo -e "Couldn't create the saml provider, please delete $idp to proceed."
  exit 1
fi

echo "Storing the saml-provider arn into the SSM Parameter store"
parameter=$(aws ssm put-parameter --description "The arn of the IDP used to protect the $stackname AppStream stack" --name /AppStream/$stackname/IAM/SamlProvider/Arn --value $idp --type String --overwrite)
if [ -z "$parameter" ]
then
  echo "The idp arn couldn't be stored into the SSM parameter store"
  exit 1
fi
echo "Successfully stored the saml-provider arn into /AppStream/$stackname/IAM/SamlProvider/Arn resulting in $parameter"


echo ""
echo "Create the AppStream stack"
echo "--------------------------"
echo "Visit the URL below to deploy the CloudFormation template for the "
echo "AppStream 2.0 stack and wait for it to complete.  Once complete,"
echo "press 'ENTER' at the prompt below to continue the deployment."
echo "   https://$region.console.aws.amazon.com/cloudformation/home?region=$region#/stacks/quickcreate?templateUrl=${bucket_url}templates/deploy/appstream.yaml&stackName=appstream-$stackname&param_AppStreamStackName=$stackname"
echo ""
echo "Wait until the CloudFormation template has deployed successfully."
read -p 'Press any key to continue once the stack has deployed...' -n 1 -r nul

echo ""
echo "Extracting variables from SSM parameter store"
echo "---------------------------------------------"
extract_param idp_arn /AppStream/$stackname/IAM/SamlProvider/Arn
extract_param stack_role /AppStream/$stackname/IAM/Role/Arn

echo ""
echo "Finalize configuration of AWS SSO AppStream Application"
echo "-------------------------------------------------------"
echo "Next, we must navigate back to the AWS SSO console, to the application"
echo "we previously created so that we can configure the Attribute Mappings."
echo ""
echo "1. In the left pane, choose Applications."
echo "2. Choose the application that was created in the first step above"
echo "   (i.e. Engineering Lab)."
echo "3. Choose the Attribute mappings tab."
echo "4. Ensure that the following three entries are present:"
echo "   - Subject"
echo "     \${user:subject}"
echo "     persistent"
echo "   - https://aws.amazon.com/SAML/Attributes/RoleSessionName"
echo "     \${user:subject}"
echo "     unspecified"
echo "   - https://aws.amazon.com/SAML/Attributes/Role"
echo "     $stack_role,$idp_arn"
echo "     unspecified"
echo "5. Choose Save Changes"
echo ""
echo "With this configuration, the user's login to AWS SSO will be presented"
echo "to AppStream and must match the user principal name (UPN) in the "
echo "username@domain.com format.  The user must then login to Active"
echo "Directory with their password stored in Active Directory."
echo "Note that the IAM Role ARN and the Identity Provider ARN will"
echo "be presented to AppStream and used to allow the user access to the"
echo "AppStream Stack created above."

echo ""
echo "Assign users access to the new application in AWS SSO"
echo "-----------------------------------------------------"
echo "The following instructions assume that access to the stack above will"
echo "be granted using the internal SSO directory."
echo ""
echo "To create users in this directory choose Directory from the left hand "
echo "pane from the AWS SSO dashboard."
echo ""
echo "In this example, users are created and assigned to the 'Engineering Lab'"
echo "application using a directory group."
echo ""
echo "On the Users tab, choose Add user."
echo ""
echo "Complete the user details and choose either to send the user an email "
echo "with password setup instructions, or generate a one-time password that "
echo "the user can reset at first login."
echo ""
echo "Complete the wizard to add the user."
echo ""
echo "Repeat this process for the users that need AppStream 2.0 stack access."
echo ""
echo "Next, choose the Groups tab."
echo ""
echo "Choose Create group. Use some logical value for the name and description"
echo "such as 'EngineeringStudents' and a description of 'Students in the "
echo "college of engineering'."
echo "Choose Create"
echo "Next, click on the EngineeringStudents group and choose Add users."
echo "Select the users that require access to the stack and choose Add user(s)."
echo ""
echo "Back on the AWS SSO dashboard, choose Applications in the left hand pane."
echo "Click on the application (i.e. EngineeringLab)."
echo "Choose the Assigned users tab and select Assign users"
echo "Select the Groups tab, select the ExampleStack group previously created, "
echo "and select Assign users"
echo ""
echo "You have now successfully created users in the AWS SSO dedicated "
echo "directory and assigned them to an AppStream 2.0 SAML application in "
echo "AWS SSO."
echo ""
echo "The users can now login using the SSO User portal URL and access "
echo "should see a link for the Engineering Lab application.  Once that link"
echo "is clicked, the user will see the home page for the AppStream session,"
echo "including the applications available.  Clicking those applications will"
echo "launch the application in the browser."

