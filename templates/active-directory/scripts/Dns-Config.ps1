[CmdletBinding()]
# Incoming Parameters for Script, CloudFormation\SSM Parameters being passed in
param(
    [Parameter(Mandatory=$true)]
    [string]$ADServerNetBIOSName,
    
    [Parameter(Mandatory=$true)]
    [string]$ADServerPrivateIP,

    [Parameter(Mandatory=$true)]
    [string]$ExternalDomainControllerIp,

    [Parameter(Mandatory=$true)]
    [string]$DomainDNSName,

    [Parameter(Mandatory=$true)]
    [string]$ADAdminSecParam
)

# PowerShell DSC Configuration Block to config DNS Settings on Domain Controller
Configuration DnsConfig {
    
    # Importing DSC Modules needed for Configuration
    Import-Module -Name PSDesiredStateConfiguration
    Import-Module -Name NetworkingDsc
    Import-Module -Name ComputerManagementDsc
    
    # Importing All DSC Resources needed for Configuration
    Import-DscResource -Module PSDesiredStateConfiguration
    Import-DscResource -Module NetworkingDsc
    Import-DscResource -Module ComputerManagementDsc
    
    # DNS Settings for Domain Controller
    Node $ADServer {
        DnsServerAddress DnsServerAddress {
            Address        = $ExternalDomainControllerIp, $ADServerPrivateIP
            InterfaceAlias = 'Primary'
            AddressFamily  = 'IPv4'
        }
    }
}

# Formatting Computer names as FQDN
$ADServer = $ADServerNetBIOSName + "." + $DomainDNSName

# Getting Password from Secrets Manager for AD Admin User
$ADAdminPassword = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $ADAdminSecParam).SecretString
# Creating Credential Object
$Credentials = (New-Object PSCredential($ADAdminPassword.UserName,(ConvertTo-SecureString $ADAdminPassword.Password -AsPlainText -Force)))

# Setting Cim Sessions for Host
$VMSession = New-CimSession -Credential $Credentials -ComputerName $ADServer -Verbose

# Generating MOF File
DnsConfig -OutputPath 'C:\AWSQuickstart\DnsConfig'

# No Reboot Needed, Processing Configuration from Script using pre-created Cim Sessions
Start-DscConfiguration -Path 'C:\AWSQuickstart\DnsConfig' -CimSession $VMSession -Wait -Verbose -Force

