﻿<#
.SYNOPSIS

Install base LANSA requirements

.DESCRIPTION

This script calls a set of scripts to setup the base requirments of LANSA on a Windows Server.

It is intended to be run via remote PS on an AWS instance that has the LANSA Cookbooks git repository installed.

.EXAMPLE


#>
param (
    [Parameter(Mandatory=$true)]
    [string]
    $GitRepoPath,

    [Parameter(Mandatory=$true)]
    [string]
    $TempPath,

    [Parameter(Mandatory=$true)]
    [string]
    $LicenseKeyPassword
    )

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

$script:IncludeDir = "$GitRepoPath\scripts"

Write-Debug "script:IncludeDir = $script:IncludeDir"

# Includes
. "$Script:IncludeDir\dot-createlicense.ps1"
. "$Script:IncludeDir\dot-Add-DirectoryToEnvPathOnce.ps1"
. "$script:IncludeDir\dot-New-ErrorRecord.ps1"
. "$script:IncludeDir\dot-Get-AvailableExceptionsList.ps1"


try
{
    cmd /c schtasks /change /TN "\Microsoft\windows\application Experience\ProgramDataUpdater" /DISABLE

    $installer_file = "$GitRepoPath\PackerScripts\chef-client-12.1.1-1.msi"
    Start-Process -FilePath $installer_file -Wait 

    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\bin"
    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\embedded"
    $ENV:PATH
    cd "$GitRepoPath\Cookbooks"
    chef-client -z -o VLWebServer::IDEBase
    if ( $LASTEXITCODE -ne 0 )
    {
        $errorRecord = New-ErrorRecord System.Configuration.Install.InstallException RecipeFailure `
            InvalidData $LASTEXITCODE -Message "Chef-Client exit code = $LASTEXITCODE."
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
    CreateLicence "$TempPath\LANSADevelopmentLicense.pfx" $LicenseKeyPassword "LANSA Development License" "DevelopmentLicensePrivateKey"
    &"$Script:IncludeDir\installAwsSdk.ps1" $TempPath
    &"$Script:IncludeDir\scheduleTasks.ps1"
    &"$Script:IncludeDir\Get-StartupCmds.ps1"
    &"$Script:IncludeDir\windowsUpdatesSettings.ps1"
    &"$Script:IncludeDir\win-updates.ps1"
}
catch
{
    Write-Error ($_ | format-list | out-string)
    throw
}