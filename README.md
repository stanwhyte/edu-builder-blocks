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

Development (DEV)
-----------------

The development environment is intended to be easily destroyed and recreated.  Further, it depends on a simulated remote site deployed in AWS to complement the normal AWS infrastructure.  As such the instructions below vary slightly from the higher level environments.

1. Create an S3 bucket in the region of choice, and run the `scripts/s3-sync.sh` script to load this project into the new S3 bucket.
1. Deploy the [Bootstrap](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET_NAME_HERE.s3.us-east-2.amazonaws.com%2FDEV%2Ftemplates%2Fdeploy%2Fbootstrap.yaml&stackName=dev-bootstrap&param_BucketName=BUCKET_NAME_HERE&param_BucketPartition=aws&param_BucketRegion=us-east-2&param_BucketUrlSuffix=amazonaws.com&param_Env=DEV&param_KeyPrefix=DEV%2F) stack to populate the SSM Parameter Store with the location of the CloudFormation templates and supporting code.
1. Deploy the [Foundation](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET_NAME_HERE.s3.us-east-2.amazonaws.com%2FDEV%2Ftemplates%2Fdeploy%2Ffoundation.yaml&stackName=dev-foundation&param_CfnUrl=%2FDEV%2FBootstrap%2FCloudFormation%2FS3%2FBucket%2FUrl&param_DnsExternalZoneName=dev.aws.example.com&param_DnsInternalZoneName=example.com&param_Env=DEV&param_TransitGatewayAsn=64512&param_VpcCidrPrefix=10.0) stack and complete manual configuration changes as appropriate:
    * Configure the DNS authoritative name server for the external zone to delegate responsibility to AWS.
1. Deploy the [Simulated Active Directory](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET_NAME_HERE.s3.us-east-2.amazonaws.com%2FDEV%2Ftemplates%2Fdeploy%2Factive-directory-simulated.yaml&stackName=dev-ad-simulated&param_ADServer1InstanceType=m5.xlarge&param_ADServer1NetBIOSName=DC1&param_ADServer1PrivateIP=192.168.0.10&param_ADServer2InstanceType=m5.xlarge&param_ADServer2NetBIOSName=DC2&param_ADServer2PrivateIP=192.168.0.74&param_CfnUrl=%2FDEV%2FBootstrap%2FCloudFormation%2FS3%2FBucket%2FUrl&param_DomainAdminUser=DomainAdmin&param_DomainDNSName=ad.example.com&param_DomainNetBIOSName=example&param_Env=DEV&param_KeyPairName=KEYPAIRNAME&param_VpcCidrPrefix=192.168.0) stack to simulate the on-premises Active Directory environment.
1. Deploy the [Active Directory](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET_NAME_HERE.s3.us-east-2.amazonaws.com%2FDEV%2Ftemplates%2Fdeploy%2Factive-directory.yaml&stackName=dev-ad&param_AdminUser=DomainAdmin&param_CfnUrl=%2FDEV%2FBootstrap%2FCloudFormation%2FS3%2FBucket%2FUrl&param_DCRemoteIp1=192.168.0.10&param_DCRemoteIp2=192.168.0.74&param_Domain=ad.example.com&param_Env=DEV&param_InstanceType=m5.xlarge&param_KeyPairName=KEYPAIRNAME&param_LdapSubdomain=ldap-dev&param_NetBIOS=example&param_NetBIOSPrefix=AWSDC&param_TargetLocation=Remote&param_WINFULLBASE=%2Faws%2Fservice%2Fami-windows-latest%2FWindows_Server-2019-English-Full-Base) stack and optionally deploy the [Remote Desktop Portal (RDP)](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET_NAME_HERE.s3.us-east-2.amazonaws.com%2FDEV%2Ftemplates%2Fdeploy%2Frdp.yaml&stackName=dev-rdp&param_CfnUrl=%2FDEV%2FBootstrap%2FCloudFormation%2FS3%2FBucket%2FUrl&param_Env=DEV&param_KeyPairName=KEYPAIRNAME&param_LatestAmiId=%2Faws%2Fservice%2Fami-windows-latest%2FWindows_Server-2016-English-Full-Base&param_NumberOfRDGWHosts=1&param_RDGWCIDR=69.231.74.30%2F32&param_RDGWInstanceType=t2.large) stack, which should be removed after completion of testing activities.  Complete manual configuration tasks as required:
    * If required, create CNAME entries in appropriate DNS locations to complete external certificate creation for AD LDAP certificate
1. Deploy the [Shibboleth](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/quickcreate?templateUrl=https%3A%2F%2FBUCKET_NAME_HERE.s3.us-east-2.amazonaws.com%2FDEV%2Ftemplates%2Fdeploy%2Fshibboleth.yaml&stackName=dev-shib&param_CfnUrl=%2FDEV%2FBootstrap%2FCloudFormation%2FS3%2FBucket%2FUrl&param_CodeCommitRepoName=shibboleth&param_Env=DEV&param_LDAPBaseDN=DC%3Dad%2CDC%3Dexample%2CDC%3Dcom&param_LDAPReadOnlyUser=domainadmin%40ad.example.com&param_LDAPUrl=ldaps%3A%2F%2Fldap-dev.example.com%3A636&param_LaunchType=Fargate&param_SealerKeyVersionCount=10&param_Subdomain=sso-dev) stack and complete manual deployment tasks as appropriate:
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

