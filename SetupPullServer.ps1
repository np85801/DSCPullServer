Find-Module xPSDesiredStateConfiguration | Install-Module

$PSrootfolder="C:\powershelldsc\powershelldsc"

$ModuleNames = @(
                    @{Name="Psdesiredstateconfiguration"},
                    @{Name="xPsdesiredstateconfiguration"}
                )

foreach($module in $ModuleNames)
{
    if(Get-Module -Name $module.name -ListAvailable)
    {
        Write-Host "$($module.name) is available"

    }
    else
    {
        Write-Host "$($module.name) is not available"

        Find-Module -Name $module.name | Install-Module 
        
    }
}

Find-Module xDscWebService | Install-Module 
mkdir C:\HTTPPullserverconfig -ErrorAction Continue

$Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName "$($env:COMPUTERNAME)"
$cert | Export-Certificate -FilePath C:\HTTPPullServerconfig\$($env:COMPUTERNAME).cer -Force

$registrationkey = ([guid]::NewGuid()).Guid


configuration DSCPullServerConfig
{
    param
    (
        [string[]]$NodeName = 'MUM-6VSD9Y2',

        [ValidateNotNullOrEmpty()]
        [string] $certificateThumbPrint,

        [Parameter(HelpMessage='This should be a string with enough entropy (randomness) to protect the registration of clients to the pull server.  We will use new GUID by default.')]
        [ValidateNotNullOrEmpty()]
        [string] $RegistrationKey   # A guid that clients use to initiate conversation with pull server
    )

    Import-DSCResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    

    Node $NodeName
    {
        WindowsFeature DSCServiceFeature
        {
            Ensure = "Present"
            Name   = "DSC-Service"
        }

        xDscWebService PSDSCPullServer
        {
            Ensure                  = "Present"
            EndpointName            = "PSDSCPullServer"
            Port                    = 8080
            PhysicalPath            = "$env:SystemDrive\inetpub\PSDSCPullServer"
            CertificateThumbPrint   = $certificateThumbPrint
            ModulePath              = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
            ConfigurationPath       = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
            State                   = "Started"
            DependsOn               = "[WindowsFeature]DSCServiceFeature"
            RegistrationKeyPath     = "$env:PROGRAMFILES\WindowsPowerShell\DscService"
            AcceptSelfSignedCertificates = $true
            Enable32BitAppOnWin64   = $false
            UseSecurityBestPractices = $false
        }

        File RegistrationKeyFile
        {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt"
            Contents        = $RegistrationKey
        }
    }
}


DSCPullServerConfig -OutputPath C:\HTTPPullServerconfig -RegistrationKey $registrationkey

DSCPullServerConfig -OutputPath C:\HTTPPullserverconfig -certificateThumbPrint $Cert.Thumbprint -RegistrationKey $registrationkey

Start-DscConfiguration -Path C:\HTTPPullServerconfig -wait -Verbose -Force

if ($credential -eq $null)
{
$credential=get-credential
}


$cimsessionoption = New-CimSessionOption -SkipCACheck -SkipCNCheck 
$cimsession = New-CimSession -ComputerName $($env:COMPUTERNAME) -SessionOption $cimsessionoption -Port 5986 -Credential $credential

#Get-DscConfiguration -CimSession $cimsession -Verbose




#Create a zip of all files from modules folder



Import-Module xPSDesiredStateConfiguration
Publish-ModuleToPullServer -Name xNetworking -OutputFolderPath "C:\Program Files\WindowsPowerShell\DscService\Modules" -ModuleBase "C:\Program Files\WindowsPowerShell\Modules\xNetworking\5.7.0.0" -Version 5.7.0.0 


Publish-ModuleToPullServer -Name ClientConfig -ModuleBase C:\Clientconfig -OutputFolderPath "C:\Program Files\WindowsPowerShell\DscService\Configuration"