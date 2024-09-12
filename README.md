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
