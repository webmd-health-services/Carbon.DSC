<#
.SYNOPSIS
Gets the Carbon tests ready to run.

.DESCRIPTION
The `Start-CarbonTest.ps1` script makes sure that Carbon can be loaded automatically by the local configuration manager. When running under Appveyor, it adds the current directory to the `PSModulePath` environment variable. Otherwise, it creates a junction to Carbon into the Modules directory where modules get installed.

Run `Complete-CarbonTest.ps1` to reverse the changes this script makes.
#>
[CmdletBinding()]
param(
)

#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'Carbon.DSC' -Resolve) `
              -Function @('Clear-CDscLocalResourceCache') `
              -Verbose:$false

$psModulesPath = Join-Path -Path $PSScriptRoot -ChildPath 'Carbon.DSC\Modules' -Resolve

Import-Module -Name (Join-Path -Path $psModulesPath -ChildPath 'Carbon' -Resolve) `
              -Function @('Get-CCimInstance', 'Get-CPowerShellModuleInstallPath', 'Install-CJunction') `
              -Verbose:$false

$psModulesPath = Join-Path -Path $PSScriptRoot -ChildPath 'PSModules' -Resolve

Import-Module -Name (Join-Path -Path $psModulesPath -ChildPath 'Carbon.FileSystem' -Resolve) `
              -Function @('Grant-CNtfsPermission') `
              -Verbose:$false

$installRoot = Get-CPowerShellModuleInstallPath
$carbonModuleRoot = Join-Path -Path $installRoot -ChildPath 'Carbon.DSC'
Install-CJunction -Link $carbonModuleRoot -Target (Join-Path -Path $PSScriptRoot -ChildPath 'Carbon.DSC' -Resolve)

if( (Test-Path -Path 'env:APPVEYOR') )
{
    Grant-CNtfsPermission -Path ($PSScriptRoot | Split-Path) -Identity 'Everyone' -Permission 'FullControl'
    Grant-CNtfsPermission -Path ('C:\Users\appveyor\Documents') -Identity 'Everyone' -Permission 'FullControl'

    $wmiprvse = Get-Process -Name 'wmiprvse'
    #$wmiprvse | Format-Table
    $wmiprvse | Stop-Process -Force
    #Get-Process -Name 'wmiprvse' | Format-Table
}

configuration Yolo
{
    node 'localhost'
    {
        Script AvailableModules
        {
            GetScript = {
                return @{ PID = $PID }

            }

            SetScript = {

            }

            TestScript =  {
                $PID | Write-Verbose
                Get-Module -ListAvailable | Format-Table | Out-String | Write-Verbose
                Get-DscResource | Format-Table | Out-String | Write-Verbose
                return $true
            }

        }
    }
}

#$dscOutputRoot = Join-Path -Path $PSScriptRoot -ChildPath '.output\Yolo'
#& Yolo -OutputPath $dscOutputRoot
#Start-DscConfiguration -Wait -Verbose -Path $dscOutputRoot -ComputerName 'localhost'

#Get-Module -ListAvailable | Format-Table

#$modulePaths = $env:PSModulePath -split ';'
#$modulePaths

#Get-ChildItem $modulePaths | Format-Table

#Get-DscResource | Format-Table

Clear-CDscLocalResourceCache
