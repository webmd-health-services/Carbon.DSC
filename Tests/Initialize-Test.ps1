<#
.SYNOPSIS
Gets things ready for your tests to run.

.DESCRIPTION
The `Initialize-Test.ps1` script gets your tests ready to run by:

* Importing the module you're testing.
* Importing your test helper module.
* Importing any other module dependencies your tests have.

Execute this script as the first thing in each of your test fixtures:

    #Requires -Version 5.1
    Set-StrictMode -Version 'Latest'

    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)
#>
[CmdletBinding()]
param(
)

$originalVerbosePref = $Global:VerbosePreference
$originalWhatIfPref = $Global:WhatIfPreference

$Global:VerbosePreference = $VerbosePreference = 'SilentlyContinue'
$Global:WhatIfPreference = $WhatIfPreference = $false

try
{
    $modules = [ordered]@{
        'Carbon.DSC' = '..\Carbon.DSC';
        'Carbon.DSCTestHelper' = 'Carbon.DSCTestHelper';
    }
    foreach( $moduleName in $modules.Keys )
    {
        $module = Get-Module -Name $moduleName
        $modulePath = Join-Path $PSScriptRoot -ChildPath $modules[$moduleName] -Resolve
        if( $module )
        {
            # Don't constantly reload modules on the build server.
            if( (Test-Path -Path 'env:WHS_CI') -and $module.Path.StartsWith($modulePath) )
            {
                continue
            }

            Write-Verbose -Message ('Removing module "{0}".' -f $moduleName)
            Remove-Module -Name $moduleName -Force
        }

        Write-Verbose -Message ('Importing module "{0}" from "{1}".' -f $moduleName,$modulePath)
        Import-Module -Name $modulePath
    }
}
finally
{
    $Global:VerbosePreference = $originalVerbosePref
    $Global:WhatIfPreference = $originalWhatIfPref
}

$psModulesPath = Join-Path -Path $PSScriptRoot -ChildPath '..\Carbon.DSC\Modules' -Resolve

Import-Module -Name (Join-Path -Path $psModulesPath -ChildPath 'Carbon' -Resolve) `
              -Function @('Install-CUser', 'Test-CUser') `
              -Verbose:$false

$password = 'Tt6QML1lmDrFSf'
[pscredential]$global:CarbonTestUser =
    [pscredential]::New('CDscTestUser', (ConvertTo-SecureString -String $password -AsPlainText -Force))

if( -not (Test-CUser -Username $CarbonTestUser.UserName) )
{
    Install-CUser -Credential $CarbonTestUser -Description 'User used during Carbon tests.'

    $usedCredential = $false
    while( $usedCredential -ne $CarbonTestUser.UserName )
    {
        try
        {
            Write-Verbose -Message ("Attempting to launch process as ""$($CarbonTestUser.UserName)"".") -Verbose
            $usedCredential =
                Start-Job -ScriptBlock { [Environment]::UserName } -Credential $CarbonTestUser  |
                Wait-Job |
                Receive-Job
        }
        catch
        {
            Start-Sleep -Milliseconds 100
        }
    }
}