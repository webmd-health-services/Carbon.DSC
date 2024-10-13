# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

$psModulesPath = Join-Path -Path $PSScriptRoot -ChildPath '..\..' -Resolve
Import-Module -Name (Join-Path -Path $psModulesPath -ChildPath 'Carbon' -Resolve) `
              -Function @('Install-CGroup', 'Get-CGroup', 'Test-CGroup', 'Uninstall-CGroup')

Import-Module -Name (Join-Path -Path $psModulesPath -ChildPath 'Carbon.Accounts' -Resolve) `
              -Function @('Resolve-CIdentity', 'Resolve-CIdentityName')

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    Set-StrictMode -Version 'Latest'

    $group = Get-CGroup -Name $Name -ErrorAction Ignore

    $ensure = 'Absent'
    $description = $null
    $members = @()
    if( $group )
    {
        $description = $group.Description
        $members = $group.Members
        $ensure = 'Present'
    }

    @{
        Name = $Name
        Ensure = $ensure
        Description = $description
        Members = $members
    }
}

function Set-TargetResource
{
    <#
    .SYNOPSIS
    DSC resource for configuring local Windows groups.

    .DESCRIPTION
    The `Carbon_Group` resource installs and uninstalls groups. It can also modify members of existing groups.

    The group is installed when `Ensure` is set to `Present`. Group's members are updated based on the values of both `Members` and `EnsureMembers` properties, where `Members` lists users and `EnsureMemebers` controls how the list is used. If `EnsureMembers` is set to `Exact`, the group is configured to have the exact members specified. If set to `Present`, the specified members are added to the group if they are not members already. If set to `Absent`, the specified members are removed from the group if they are members of it. Defaults to `Exact`. Because DSC resources run under the LCM which runs as `System`, local system accounts must have access to the directories where both new and existing member accounts can be found.

    The group is removed when `Ensure` is set to `Absent`. When removing a group, all other properties are ignored.

    The `Carbon_Group` resource was added in Carbon 2.1.0.

    .LINK
    Add-CGroupMember

    .LINK
    Install-CGroup

    .LINK
    Remove-CGroupMember

    .LINK
    Test-CGroup

    .LINK
    Uninstall-CGroup

    .EXAMPLE
    >
    Demonstrates how to install a group and set its members.

        Carbon_Group 'CreateFirstOrder'
        {
            Name = 'FirstOrder';
            Description = 'On to victory!';
            Ensure = 'Present';
            Members = @( 'FO\SupremeLeaderSnope', 'FO\KRen' );
        }

    .EXAMPLE
    >
    Demonstrates how to uninstall a group.

        Carbon_Group 'RemoveRepublic
        {
            Name = 'Republic';
            Ensure = 'Absent';
        }

    .EXAMPLE
    >
    Demonstrates how to add members to an existing group.

        Carbon_Group 'AddVader'
        {
            Name = 'SithOrder';
            Ensure = 'Present';
            EnsureMembers = 'Present';
            Members = @( 'SO\DarthVader' );
        }

    .EXAMPLE
    >
    Demonstrates how to remove members from an existing group.

        Carbon_Group 'RemoveAnakin'
        {
            Name = 'JediOrder';
            Ensure = 'Present';
            EnsureMembers = 'Absent';
            Members = @( 'JO\ASkywalker' );
        }

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [parameter(Mandatory=$true)]
        [String]
        # The name of the group.
        $Name,

        [String]
        # A description of the group. Only used when adding/updating a group (i.e. when `Ensure` is `Present`).
        $Description,

        [ValidateSet("Present","Absent")]
        [String]
        # Should be either `Present` or `Absent`. If set to `Present`, a group is configured and membership configured. If set to `Absent`, the group is removed.
        $Ensure,

        # Controls how the list of users, given in the `Members` property, gets used. Should be either `Exact`, `Present` or `Absent`. If set to `Exact`, the group is configured to have the exact members specified. If set to `Present`, the specified members are added to the group if they are not members already. If set to `Absent`, the specified members are removed from the group if they are members of it.
        [ValidateSet('Exact','Present','Absent')]
        [String] $EnsureMembers = 'Exact',

        [string[]]
        # A list of users, which is used according to value of `EnsureMembers`. Only used when adding/updating a group (i.e. when `Ensure` is `Present`).
        $Members = @()
    )

    Set-StrictMode -Version 'Latest'

    if( $Ensure -eq 'Absent' )
    {
        Uninstall-CGroup -Name $Name
        return
    }

    $memberNames = @()
    if ($Members)
    {
        $memberNames = $Members | Resolve-MemberName
    }
    $currentMemberNames = @((Get-TargetResource -Name $Name).Members | Resolve-PrincipalName)

    $membershipChanges = Resolve-MembershipChange -EnsureMembers $EnsureMembers `
                                                  -MemberNames $memberNames `
                                                  -CurrentMemberNames $currentMemberNames
    $membersToInstall = @($currentMemberNames;$membershipChanges.ToAdd)

    $group = Install-CGroup -Name $Name -Description $Description -Member $membersToInstall -PassThru
    if( -not $group )
    {
        return
    }

    try
    {
        $membersToRemove = $group.Members | Where-Object {
                                                            $memberName = Resolve-PrincipalName -Principal $_
                                                            return $membershipChanges.ToRemove -contains $memberName
                                                         }
        if( $membersToRemove )
        {
            foreach( $memberToRemove in $membersToRemove )
            {
                Write-Verbose -Message ('[{0}] Members      {1} ->' -f $Name,(Resolve-PrincipalName -Principal $memberToRemove))
                $group.Members.Remove( $memberToRemove )
            }

            if( $PSCmdlet.ShouldProcess( ('local group {0}' -f $Name), 'remove members' ) )
            {
                $group.Save()
            }
        }
    }
    finally
    {
        $group.Dispose()
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $Name,

        [String]
        $Description = $null,

        [ValidateSet("Present","Absent")]
        [String]
        $Ensure = "Present",

        [ValidateSet('Exact','Present','Absent')]
        [String] $EnsureMembers = 'Exact',

        [string[]]
        $Members = @()
    )

    Set-StrictMode -Version 'Latest'

    $resource = Get-TargetResource -Name $Name

    # Do we need to delete the group?
    if( $Ensure -eq 'Absent' -and $resource.Ensure -eq 'Present' )
    {
        Write-Verbose -Message ('[{0}] Group is present but should be absent.' -f $Name)
        return $false
    }

    # Is it already gone?
    if( $Ensure -eq 'Absent' -and $resource.Ensure -eq 'Absent' )
    {
        return $true
    }

    # Do we need to create the group?
    if( $Ensure -eq 'Present' -and $resource.Ensure -eq 'Absent' )
    {
        Write-Verbose -Message ('[{0}] Group is absent but should be present.' -f $Name)
        return $false
    }

    # Is the group out-of-date?
    $upToDate = $true
    if( $Description -ne $resource.Description )
    {
        Write-Verbose -Message ('[{0}] [Description] ''{1}'' != ''{2}''' -f $Name,$Description,$resource.Description)
        $upToDate = $false
    }

    $memberNames = @()
    if ($Members)
    {
        $memberNames = $Members | Resolve-MemberName
    }
    $currentMemberNames = @($resource.Members | Resolve-PrincipalName)

    $membershipChanges = Resolve-MembershipChange -EnsureMembers $EnsureMembers `
                                                  -MemberNames $memberNames `
                                                  -CurrentMemberNames $currentMemberNames

    if ($membershipChanges.ToAdd)
    {
        $upToDate = $false
        foreach ($memberName in $membershipChanges.ToAdd)
        {
            Write-Verbose -Message ('[{0}] [Members] {1} is absent but should be present' -f $Name,$memberName)
        }
    }
    if ($membershipChanges.ToRemove)
    {
        $upToDate = $false
        foreach ($memberName in $membershipChanges.ToRemove)
        {
            Write-Verbose -Message ('[{0}] [Members] {1} is present but should be absent' -f $Name,$memberName)
        }
    }
    return $upToDate
}

function Resolve-MembershipChange
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Exact','Present','Absent')]
        [String] $EnsureMembers,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [String[]] $MemberNames,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [String[]] $CurrentMemberNames
    )

    $alreadyMembers = @($MemberNames | Where-Object { $_ -in $CurrentMemberNames })
    $extraMembers = @($CurrentMemberNames | Where-Object { $_ -notin $MemberNames })
    $newMembers = @($MemberNames | Where-Object { $_ -notin $CurrentMemberNames })

    $membersToAdd = $null
    $membersToRemove = $null
    if ($EnsureMembers -eq 'Present')
    {
        $membersToAdd = $newMembers
        $membersToRemove = @()
    }
    elseif ($EnsureMembers -eq 'Absent')
    {
        $membersToAdd = @()
        $membersToRemove = $alreadyMembers
    }
    else
    {
        $membersToAdd = $newMembers
        $membersToRemove = $extraMembers
    }

    return @{
        ToAdd = $membersToAdd
        ToRemove = $membersToRemove
    }
}

function Resolve-MemberName
{
    param(
        [Parameter(Mandatory, VAlueFromPipeline=$true)]
        [String]
        $Name
    )

    process
    {
        Resolve-CIdentityName -Name $Name
    }
}

function Resolve-PrincipalName
{
    param(
        [Parameter(Mandatory, ValueFromPipeline=$true)]
        $Principal
    )

    process
    {
        Resolve-CIdentity -SID $Principal.Sid.Value | Select-Object -ExpandProperty 'FullName'
    }
}

Export-ModuleMember -Function *-TargetResource

