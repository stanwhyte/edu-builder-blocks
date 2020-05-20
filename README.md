--------------------------------------------------------------------------------

Overview
========

This project outlines the instructions and supporting tools required to deploy the AWS environment and integrate it with the campus network.  Instructions are provided for each of the supported environments.  It is intended that this repository should be maintained consistently such that each of the environments mentioned may be redeployed following the instructions provided.

Note that the CloudFormation templates provided depend on SSM Parameter references and use the environment name as part of the naming convention.  The impact of this is that only one instance of each environment may be deployed within a single AWS region / account.  If additional environments are desired, they may be deployed into another AWS region or account.

In each of the environments, a Shibboleth workload is deployed, which interacts with a cluster of Active Directory domain controllers that are joined to the Active Directory forest located in the remote site (on-premises).

```
        ╔AWS══════════════════╗  ╔Remote╗
┏━━━━┓  ║ ┏━━━━━━━━━━┓   ┏━━┓ ║  ║ ┏━━┓ ║
┃User┠╌╌╫╌┨Shibboleth┠╌╌╌┨AD┠╌╫╌╌╫╌┨AD┃ ║
┗━━┯━┛  ║ ┗━━━━━━━━━━┛   ┗┯━┛ ║  ║ ┗━━┛ ║
   ╎    ║ ┏━━━┓           ╎   ║  ╚══════╝
   ├╌╌╌╌╫╌┨RDP┠╌╌╌╌╌╌╌╌╌╌╌╯   ║
   ╎    ║ ┗━━━┛               ║
   ╎    ║ ┏━━━━━━━┓           ║
   ╰╌╌╌╌╫╌┨AWS SSO┃           ║
        ║ ┗━━━━━━━┛           ║
        ╚═════════════════════╝
```

The remainder of this document outlines how to deploy the environment, the design decisions and architectural choices that are implemented, and some roadmap items.


--------------------------------------------------------------------------------

Getting Started
===============

Prerequisites
-------------

In order to complete the deployment of all workloads listed below, ensure the following prerequisites have been completed:

1. Select the desired region to be used for all regional workload deployments, using the [regional product services](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/) table to ensure all desired workloads are available.  It is recommended initial testing be performed in the `us-east-1` region as it has all services available. 
1. [Create](https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html) a user with administrative privileges.
1. [Install](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) and [configure](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) the AWS command line interface.
1. Clone the EDU Builder Blocks project `git clone https://github.com/aws-samples/edu-builder-blocks.git` to establish a local copy of the project and change into the correct directory `cd edu-builder-blocks`.
1. [Create](https://docs.aws.amazon.com/AmazonS3/latest/gsg/CreatingABucket.html) an S3 bucket in the region of choice.  
1. Search and replace the BUCKET string in the current file (README.md) with the new bucket name `sed -i '' 's/BUCKET/my-bucket-name/' README.md`.
1. Search and replace the REGION string in the current file (README.md) with the selected region `sed -i '' 's/REGION/us-east-1/' README.md`.
1. Use the `./scripts/build-submodules.sh -d .` script to update all of the submodules to the latest version and sync them with the `external/` folder.
1. Use the `./scripts/s3-sync.sh -d . -b BUCKET -e DEV` script to synchronize the current project with the S3 bucket.


Development (DEV)
-----------------

The development environment is intended to be easily destroyed and recreated.  Further, it depends on a simulated remote site deployed in AWS to complement the normal AWS infrastructure.  As such the instructions below vary slightly from the higher level environments.

1. Deploy the [Bootstrap](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2FDEV%2Ftemplates%2Fdeploy%2Fbootstrap.yaml&stackName=dev-bootstrap&param_BucketName=BUCKET&param_BucketRegion=REGION) stack to populate the SSM Parameter Store with the location of the CloudFormation templates and supporting code.
1. Deploy the [Foundation](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2FDEV%2Ftemplates%2Fdeploy%2Ffoundation.yaml&stackName=dev-foundation) stack and complete manual configuration changes as appropriate:
    * Configure the DNS authoritative name server for the external zone to delegate responsibility to AWS.
1. Deploy the [Simulated Active Directory](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2FDEV%2Ftemplates%2Fdeploy%2Factive-directory-simulated.yaml&stackName=dev-ad-simulated) stack to simulate the on-premises Active Directory environment.
1. Deploy the [Active Directory](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2FDEV%2Ftemplates%2Fdeploy%2Factive-directory.yaml&stackName=dev-ad) stack and optionally deploy the [Remote Desktop Portal (RDP)](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2FDEV%2Ftemplates%2Fdeploy%2Frdp.yaml&stackName=dev-rdp) stack, which should be removed after completion of testing activities.  Complete manual configuration tasks as required:
    * If required, create CNAME entries in appropriate DNS locations to complete external certificate creation for AD LDAP certificate
1. Deploy the [Shibboleth](https://REGION.console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET.s3.amazonaws.com%2FDEV%2Ftemplates%2Fdeploy%2Fshibboleth.yaml&stackName=dev-shib) stack and complete manual deployment tasks as appropriate:
    * If required, create CNAME entries in appropriate DNS locations to complete external certificate creation for the SSO certificate
    * Increase number of required Shibboleth desired tasks as [documented](external/aws-refarch-shibboleth/README.md)
1. Complete configuration instructions to enable SSO and establish Shibboleth as the trusted IDP.  Instructions for these tasks may be found [here](external/aws-refarch-shibboleth/README.md).



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

