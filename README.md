--------------------------------------------------------------------------------

Overview
========

This project outlines the instructions and supporting tools required to deploy the AWS environment and integrate it with the campus network.  It is intended that this repository should be maintained consistently such that the environment mentioned may be redeployed following the instructions provided.

Note that the CloudFormation templates provided depend on SSM Parameter references.  The impact of this is that only one instance may be deployed within a single AWS region / account.  If additional environments are desired, they may be deployed into another AWS region or account.

```
        ╔AWS══════════════════╗  
        ║ ┏━━━━━━━┓           ║   
   ╭╌╌╌╌╫╌┨AWS SSO┃           ║
   ╎    ║ ┗━━━━━━━┛           ║  ╔Remote╗
┏━━┷━┓  ║ ┏━━━━━━━━━━┓   ┏━━┓ ║  ║ ┏━━┓ ║
┃User┠╌╌╫╌┨Shibboleth┠╌╌╌┨AD┠╌╫╌╌╫╌┨AD┃ ║
┗━━┯━┛  ║ ┗━━━━━━━━━━┛   ┗┯━┛ ║  ║ ┗━━┛ ║
   ╎    ║ ┏━━━┓           ╎   ║  ╚══════╝
   ├╌╌╌╌╫╌┨RDP┠╌╌╌╌╌╌╌╌╌╌╌┤   ║
   ╎    ║ ┗━━━┛           ╎   ║
   ╎    ║ ┏━━━━━━━━━┓     ╎   ║
   ├╌╌╌╌╫╌┨Appstream┠╌╌╌╌╌┤   ║
   ╎    ║ ┗━━━━━━━━━┛     ╎   ║
   ╎    ║ ┏━━━━━━━━━━┓    ╎   ║
   ╰╌╌╌╌╫╌┨Workspaces┠╌╌╌╌╯   ║
        ║ ┗━━━━━━━━━━┛        ║
        ╚═════════════════════╝
```

The remainder of this document outlines how to deploy the environment and workloads, the design decisions and architectural choices that are implemented, and some roadmap items.


--------------------------------------------------------------------------------

Getting Started
===============

Prerequisites
-------------

In order to complete the deployment of all workloads listed below, ensure the following prerequisites have been completed:

1. The commands and scripts below assume a Unix-based operating system.
1. [Create](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair) a new keypair if necessary to allow access to any EC2 instances subsequently created.
1. Select the desired region to be used for all regional workload deployments, using the [regional product services](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/) table to ensure all desired services are available.  It is recommended initial testing be performed in the `us-east-1` region as it has all services available. 
1. [Create](https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html) a user with administrative privileges.
1. [Install](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) and [configure](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) the AWS command line interface, setting the default region for the profile to be the one selected above.  Note:  The v2 of the AWS CLI is required, version 1 is not supported.
1. Optionally, [configure](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html) the `AWS_PROFILE` environment variable in the current shell if multiple profiles are being used.  This step is unnecessary if the default profile is being used.
1. Clone the EDU Builder Blocks project `git clone https://github.com/aws-samples/edu-builder-blocks.git` to establish a local copy of the project.
1. Use the `./scripts/bootstrap.sh -d /path/to/project -b BUCKET -f cfn/` script to create an S3 bucket and modify this README.md file to point to the correct region, s3 bucket name, and s3 bucket key prefix.
1. Use the `./scripts/build.sh -d /path/to/project` script to update all of the submodules to the latest version and prepare the project for deployment.


Deployment
----------

Note that for each of the steps below, the step must complete before initiating the subsequent step.  
1. Use the `./scripts/deploy.sh -d /path/to/project` script to synchronize the current project with the S3 bucket.
1. Deploy the [Bootstrap](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2Fcfn%2Ftemplates%2Fdeploy%2Fbootstrap.yaml&stackName=bootstrap&param_BucketName=BUCKET&param_BucketRegion=REGION) stack to populate the SSM Parameter Store with the location of the CloudFormation templates and supporting code.
1. Deploy the [Foundation](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2Fcfn%2Ftemplates%2Fdeploy%2Ffoundation.yaml&stackName=foundation) stack and complete manual configuration changes as appropriate:
    * Configure the DNS authoritative name server for the external zone to delegate responsibility to AWS.
1. Deploy the [Simulated Active Directory](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2Fcfn%2Ftemplates%2Fdeploy%2Factive-directory-simulated.yaml&stackName=ad-simulated) stack to simulate the on-premises Active Directory environment.
1. Deploy the [Active Directory](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2Fcfn%2Ftemplates%2Fdeploy%2Factive-directory.yaml&stackName=ad) stack and optionally deploy the [Remote Desktop Portal (RDP)](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2Fcfn%2Ftemplates%2Fdeploy%2Frdp.yaml&stackName=rdp) stack, which should be removed after completion of testing activities.  Complete manual configuration tasks as required:
    * If required, create CNAME entries in appropriate DNS locations to complete external certificate creation for AD LDAP certificate
    * Execute the `./scripts/create-ad-connector.sh` script to create an Active Directory Connector pointing to the two domain controllers.  Note, this step is required for Workspaces and AppStream, but not for the basic Shibboleth use cases.
    * If deploying AppStream, use the RDP instance to create an ou=AppStream entry, and create a test user account with the UserPrincipalName set to a value in an email format - i.e. `test@example.com`
1. Deploy the [Shibboleth](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2Fcfn%2Ftemplates%2Fdeploy%2Fshibboleth.yaml&stackName=shib) stack and complete manual deployment tasks as appropriate:
    * If required, create CNAME entries in appropriate DNS locations to complete external certificate creation for the SSO certificate
    * Increase number of required Shibboleth desired tasks as [documented](https://github.com/aws-samples/aws-refarch-shibboleth#update-the-desired-task-count)
1. Complete configuration instructions to enable SSO and establish Shibboleth as the trusted IDP.  Instructions for these tasks may be found [here](https://github.com/aws-samples/aws-refarch-shibboleth#adding-aws-sso-support-to-your-idp).
1. Deploy the [Appstream Preparation](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2Fcfn%2Ftemplates%2Fdeploy%2Fappstream-prep.yaml&stackName=appstream-prep) stack which establishes some required components to enable an AppStream Image Builder to be created and joined to the Active Directory domain.
1. Deploy the [Appstream](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2Fcfn%2Ftemplates%2Fdeploy%2Fappstream.yaml&stackName=appstream) stack which deploys the AppStream Fleet and connects it to the Image created in the previous step and complete the following steps to connect it with AWS SSO.
    * Follow the [instructions](https://aws.amazon.com/blogs/desktop-and-application-streaming/enable-federation-with-aws-single-sign-on-and-amazon-appstream-2-0/) starting with step 3 to connect AWS SSO with AppStream environment.
    * Create a user in the AppStream user store whose user id and email match the UserPrincipalName created in the AD step above.
1. Deploy the [Workspaces](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2Fcfn%2Ftemplates%2Fdeploy%2Fworkspaces.yaml&stackName=workspaces) stack and complete manual steps to connect to the Workspaces instance:
    * In the AWS console, navigate to the WorkSpaces -> Workspaces tab.
    * Click the checkbox next to the new Workspace, and the Actions -> Invite User.
    * Follow the instructions in the popup to connect to your new Workspace.



--------------------------------------------------------------------------------

Design
======


Foundation
----------

The foundations workload consists of a core set of AWS services designed to allow subsequent workloads avoid the most basic configuration tasks.  In addition to establishing a basic AWS footprint, it also establishes the core mechanisms for connecting the AWS environment to the remote / simulated remote site environment via a transit gateway peering connection.  Following are some of more pertinent AWS services deployed as part of this workload.

```
        ╔AWS══════════════════╗
┏━━━━┓  ║                     ║
┃User┠╌╌╫╌                   ╌╫╌
┗━━━━┛  ║                     ║
        ╚═════════════════════╝
```

Following is a depiction of the primary AWS services deployed as part of this workload.

```

            ┏━━━━━━━━━━━━━━━━┓ 
            ┃Internet Gateway┃
            ┗━━━━━━━┯━━━━━━━━┛
┏AZ1╍╍╍╍╍╍╍╍╍╍╍╍╍╍┓ ╎ ┏AZ2╍╍╍╍╍╍╍╍╍╍╍╍╍╍┓
╏ ╔Public═══════╗ ╏ ╎ ╏ ╔Public═══════╗ ╏
╏ ║┏━━━━━━━━━━━┓║ ╏ ╎ ╏ ║┏━━━━━━━━━━━┓║ ╏
╏ ║┃NAT Gateway┠╫╌╂╌┴╌╂╌╫┨NAT Gateway┃║ ╏
╏ ║┗━━━━━━━┯━━━┛║ ╏   ╏ ║┗━━━━━━━┯━━━┛║ ╏
╏ ╚════════╪════╝ ╏   ╏ ╚════════╪════╝ ╏
╏ ╔NAT═════╪════╗ ╏   ╏ ╔NAT═════╪════╗ ╏
╏ ║        O    ║ ╏   ╏ ║        O    ║ ╏
╏ ╚═════════════╝ ╏   ╏ ╚═════════════╝ ╏
╏ ╔Private══════╗ ╏   ╏ ╔Private══════╗ ╏
╏ ╚═════════════╝ ╏   ╏ ╚═════════════╝ ╏
╏ ╔TG═══════════╗ ╏   ╏ ╔TG═══════════╗ ╏
╏ ║           O╌╫╌╂╌┬╌╂╌╫╌O           ║ ╏
╏ ╚═════════════╝ ╏ ╎ ╏ ╚═════════════╝ ╏
┗╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍┛ ╎ ┗╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍┛
            ┏━━━━━━━┷━━━━━━━━┓ 
            ┃Transit Gateway ┃
            ┗━━━━━━━┯━━━━━━━━┛
  ┏━━━━━━━━━━━━━━━━┓╎┏━━━━━━━━━━━━━━━━┓
  ┃Customer Gateway┠┴┨Customer Gateway┃
  ┗━━━━━━━━━━━━━━━━┛ ┗━━━━━━━━━━━━━━━━┛                 
```

The following table provides additional detail on the AWS services as configured.

|#|Service                    |
|-|---------------------------|
|1|Virtual Private Cloud (VPC)|
|1|Internet Gateway           |
|2|NAT Gateway                |
|8|Subnet                     |
|1|Transit Gateway            |
|2|Customer Gateway           |
|1|DNS - External Zone        |
|1|DNS - Internal Zone        |

The following table outlines the allocation of the various CIDR blocks for each subnet.  

|Subnet Name      |AZ 1       |AZ 2       |
|-----------------|-----------|-----------|
|Transit Gateway  |`.0.0/28  `|`.0.16/28 `|
|Public           |`.64.0/19 `|`.96.0/19 `|
|NAT              |`.128.0/19`|`.160.0/19`|
|Private          |`.192.0/19`|`.244.0/19`|

Note that IP space is left available in the `.0.0/19` block, with the exception of the Transit Gateway subnets. These blocks may be used by other workloads requiring dedicated subnet space.


Active Directory Simulated
--------------------------

The simulated remote site is a deployment of an AWS VPC with public/private subnets and two attached nat gateways.  Deployed into the network is a pair of Active Directory domain controllers. This deployment is an execution of a slightly modified [AWS Active Directory quickstart](https://docs.aws.amazon.com/quickstart/latest/active-directory-ds/scenario-1.html) with some parameters preopulated. 

Following are the parts of the above architecture deployed in this step.

```
                                 ╔Remote╗
                                 ║ ┏━━┓ ║
                                ╌╫╌┨AD┃ ║
                                 ║ ┗━━┛ ║
                                 ╚══════╝
```

Active Directory
----------------

The Active Directory workload can be deployed in two different variations.  In the first variation, AWS configurations are deployed to route all Active Directory traffic through the Transit Gateway into the remote site.  While this deployment approach allows for non-intrusive testing and is functionally complete, it carries the downside of a dependency on the network connection and bandwidth for all Active Directory traffic and is thus not recommended for production workloads.

```
        ╔AWS══════════════════╗  
        ║                     ║  
        ║               ╌╌┬╌╌╌╫╌╌
        ║                 ╎   ║  
        ║                 ╎   ║ 
        ╚═════════════════════╝  
```

In the second deployment variation, new Active Directory domain controllers are provisionied into AWS and joined to the Active Directory forest located in the remote site. With this approach, new domain controller entries are added to the Active Directory forest (and are not removed upon stack deletion), and only replication traffic is implemented across the network connection between sites.  With this approach, the solution can withstand temporary network outages.

```
        ╔AWS══════════════════╗  
        ║                ┏━━┓ ║  
        ║               ╌┨AD┠╌╫╌╌
        ║                ┗┯━┛ ║  
        ║                 ╎   ║ 
        ╚═════════════════════╝  
```


Remote Desktop Protocol (RDP)
-----------------------------

The RDP workload is a temporary workload that may be deployed to test that the configured Active Directory environment is available for domain joining operations.  In addition, it may be deployed temporarily to perform management of users and computers, and general Active Directory domain administration.

```
        ╔AWS══════════════════╗
┏━━━━┓  ║                     ║
┃User┃  ║                     ║
┗━━┯━┛  ║                     ║
   ╎    ║ ┏━━━┓           ╎   ║
   ╰╌╌╌╌╫╌┨RDP┠╌╌╌╌╌╌╌╌╌╌╌╯   ║
        ║ ┗━━━┛               ║
        ╚═════════════════════╝
```


AWS Workspaces
--------------

Amazon WorkSpaces is a managed, secure Desktop-as-a-Service (DaaS) solution. You can use Amazon WorkSpaces to provision either Windows or Linux desktops in just a few minutes and quickly scale to provide thousands of desktops to workers across the globe. You can pay either monthly or hourly, just for the WorkSpaces you launch, which helps you save money when compared to traditional desktops and on-premises VDI solutions. Amazon WorkSpaces helps you eliminate the complexity in managing hardware inventory, OS versions and patches, and Virtual Desktop Infrastructure (VDI), which helps simplify your desktop delivery strategy. With Amazon WorkSpaces, your users get a fast, responsive desktop of their choice that they can access anywhere, anytime, from any supported device.

In this deployment of AWS Workspaces, a single workspaces is provisioned and assigned to a user.  Note that this workload requires the AD Connector to be provisioned as part of the Active Directory workload, and also depends on the Foundation workload for proper operation.

```
        ╔AWS══════════════════╗
┏━━━━┓  ║                     ║
┃User┃  ║                     ║
┗━━┯━┛  ║                     ║
   ╎    ║ ┏━━━━━━━━━━┓    ╎   ║
   ╰╌╌╌╌╫╌┨Workspaces┠╌╌╌╌╯   ║
        ║ ┗━━━━━━━━━━┛        ║
        ╚═════════════════════╝
```


Shibboleth
----------
 
The Shibboleth workload connects to the Microsoft Active Directory environment using the configured LDAP load balancer, and deploys a Single Sign On capability with a commonly used software package in the Education space.


```
        ╔AWS══════════════════╗
┏━━━━┓  ║ ┏━━━━━━━━━━┓        ║
┃User┠╌╌╫╌┨Shibboleth┠╌╌      ║
┗━━━━┛  ║ ┗━━━━━━━━━━┛        ║
        ╚═════════════════════╝
```



AWS Single Sign-On (SSO)
------------------------

Finally, follow the instructions in the Shibboleth quickstart to integrate the AWS SSO solution with Shibboleth, achieving end-to-end SSO into AWS from the trusted Shibboleth IDP.

```
        ╔AWS══════════════════╗
┏━━━━┓  ║ ┏━━━━━━━━━━┓        ║
┃User┠╌╌╫╌┨Shibboleth┃        ║
┗━━┯━┛  ║ ┗━━━━━━━━━━┛        ║
   ╎    ║ ┏━━━━━━━┓           ║
   ╰╌╌╌╌╫╌┨AWS SSO┃           ║
        ║ ┗━━━━━━━┛           ║
        ╚═════════════════════╝
```

--------------------------------------------------------------------------------

License
=======

This library is licensed under the MIT-0 License. See the LICENSE file.


