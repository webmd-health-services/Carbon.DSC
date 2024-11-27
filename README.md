<!--markdownlint-disable MD012 no-multiple-blanks-->

# Carbon.DSC README

## Overview

The "Carbon.DSC" module contains a few helpful DSC resources and many functions that improve working with DSC and
authoring DSC resources.


## System Requirements

* Windows PowerShell 5.1 and .NET 4.6.2+
* PowerShell 7+ on Windows


## Installing

To install globally:

```powershell
Install-Module -Name 'Carbon.DSC'
Import-Module -Name 'Carbon.DSC'
```

To install privately:

```powershell
Save-Module -Name 'Carbon.DSC' -Path '.'
Import-Module -Name '.\Carbon.DSC'
```

## DSC Resources

* `Carbon_EnvironmentVariable`: manages environment variables.
* `Carbon_FirewallRule`: manages firewall rules.
* `Carbon_Group`: manages local groups and group members.
* `Carbon_IniFile`: manages INI files.
* `Carbon_Permission`: manages permissions on files, registry keys, and private keys (on certificates in the Windows
  certificate stores).
* `Carbon_Privilege`: manages user privileges.
* `Carbon_ScheduledTask`: manages scheduled tasks.
* `Carbon_Service`: manages Windows services.


## Functions

* `Clear-CDscLocalResourceCache`: clears the local DSC resource cache.
* `Clear-CMofAuthoringMetadata`: removes authoring metadata from .mof files.
* `Copy-CDscResource`: copies DSC resources to a DSC pull server/share, creating required checksum files.
* `Get-CDscError`: gets DSC errors from a computer's event log.
* `Get-CDscWinEvent`: gets events from the DSC Windows event log.
* `Initialize-CLcm`: configures a computer's DSC Local Configuration Manager (LCM).
* `Start-CDscPullConfiguration`: performs a configuraiton check on a computer that is using DSC's pull refresh mode.
* `Test-CDscTargetResource`: determines if a target resource is out of date compared to a desired resource.
* `Write-CDscError`: takes DSC error events and writes them as PowerShell errors.

## Developing

We use [Whiskey](https://github.com/webmd-health-services/Whiskey/wiki) to script our builds. You can find the build
script in the whiskey.yml file. We use [AppVeyor](https://ci.appveyor.com/project/WebMD-Health-Services/carbon-dsc) to
run our builds. You can find AppVeyor script in appveyor.yml.

To get your local environment setup, run `.\build.ps1` from an administrator PowerShell prompt. Once the Pester tests
start running, you can quit the build or wait for them to finish. A full build should take less than 10 minutes. You can
check AppVeyor to see current approximate build times. If any tests are failing, reach out to the team to help figure
out why.

All code should have tests that are written using Pester 5. We recommend installing a global instance of the Pester 5
PowerShell module.

When you're developing and testing DSC resources, PowerShell expects the module containing the DSC resources to be in
the global `PSModulePath` environment variable. Use the `Start-CarbonDscTest.ps1` script to get your machine configured
so that the Carbon.DSC module you're working on gets added to PowerShell's module path. When you're done developing,
run `Complete-CarbonDscTest.ps1` to undo this configuration change. Note that a full build runs both scripts so you'll
still need to run `Start-CarbonDscTest.ps1` despite running a full build.
