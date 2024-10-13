
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

    $psModulesPath = Join-Path -Path $PSScriptRoot -ChildPath '..\Carbon.DSC' -Resolve
    Import-Module -Name (Join-Path -Path $psModulesPath -ChildPath 'Carbon' -Resolve) `
                  -Function @('Get-CGroup', 'Install-CUser', 'Install-CGroup', 'Test-CGroup') `
                  -Verbose:$false

    Import-Module -Name (Join-Path -Path $psModulesPath -ChildPath 'Carbon.Accounts' -Resolve) `
                  -Function @('Resolve-CIdentity') `
                  -Verbose:$false

    $script:groupName = 'CarbonGroupTest'
    $script:username1 = $CarbonTestUser.UserName
    $script:username2 = 'CarbonTestUser2'
    $script:username3 = 'CarbonTestUser3'
    $script:user1 = $null
    $script:user2 = $null
    $script:user3 = $null
    $script:description = 'Group for testing Carbon''s Group DSC resource.'

    Start-CarbonDscTestFixture 'Group'
    $script:user1 = Resolve-CIdentity -Name $CarbonTestUser.UserName
    $password = ConvertTo-SecureString -String 'P@ssw0rd1' -Force -AsPlainText
    $script:user2 = Install-CUser -Credential ([pscredential]::New($script:username2,$password)) `
                                  -Description 'Carbon test user' `
                                  -PassThru
    $script:user3 = Install-CUser -Credential ([pscredential]::New($script:username3,$password)) `
                                  -Description 'Carbon test user' `
                                  -PassThru
    Install-CGroup -Name $script:groupName -Description $script:description -Member $script:username1,$script:username2
}

AfterAll {
    Stop-CarbonDscTestFixture
}

Describe 'Carbon_Group' {
    BeforeEach {
        $Global:Error.Clear()
    }

    It 'get target resource' {
        $admins = Get-CGroup -Name 'Administrators'

        $groupName = 'Administrators'
        $resource = Get-TargetResource -Name $groupName
        $resource | Should -Not -BeNullOrEmpty
        $groupName | Should -Be $resource.Name
        $resource.Description | Should -Be $admins.Description
        Assert-DscResourcePresent $resource

        $resource.Members.Count | Should -Be $admins.Members.Count
        $resourceMembers = $resource.Members | ForEach-Object { Resolve-CIdentity -Name $_ }

        $resourceMembers.Sid | Should -Be $admins.Members.Sid
    }

    It 'get target resource does not exist' {
        $resource = Get-TargetResource -Name 'fubarsnafu'
        $resource | Should -Not -BeNullOrEmpty
        $resource.Name | Should -Be 'fubarsnafu'
        $resource.Description | Should -BeNullOrEmpty
        $resource.Members | Should -BeNullOrEmpty
        Assert-DscResourceAbsent $resource
    }

    It 'test target resource' {
        $result = Test-TargetResource -Name $script:groupName `
                                      -Description $script:description `
                                      -Members ($script:username1,$script:username2)
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeTrue

        $result = Test-TargetResource -Name $script:groupName -Ensure Absent
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeFalse

        # expected to be out of date with no properties passed
        $result = Test-TargetResource -Name $script:groupName
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeFalse

        $result = Test-TargetResource -Name $script:groupName -Members ($script:username1,$script:username2) -Description $script:description
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeTrue

        # Now, make sure if group has extra member we get false
        $result = Test-TargetResource -Name $script:groupName -Members ($script:username1) -Description $script:description
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeFalse

        # Now, make sure if group is missing a member we get false
        $result = Test-TargetResource -Name $script:groupName -Members ($script:username1,$script:username2,$script:username3) -Description $script:description
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeFalse

        # Now, make sure if group description is different we get false
        $result = Test-TargetResource -Name $script:groupName -Members ($script:username1,$script:username2) -Description 'a new description'
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeFalse

        # We get false even if members are same when Should -be absent
        $result = Test-TargetResource -Name $script:groupName -Members $script:username1,$script:username2 -Ensure Absent
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeFalse

        # We get false even if description is the same when Should -be absent
        $result = Test-TargetResource -Name $script:groupName -Description $script:description -Ensure Absent
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeFalse

        # EnsureMembers='Present'
        $commonSetupArgs = @{
            Name = $script:groupName;
            Ensure = 'Present';
            Description = $script:description;
            EnsureMembers = 'Present';
        }

        $result = Test-TargetResource -Members @() @commonSetupArgs
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeTrue -Because 'the specified members list is empty'

        $result = Test-TargetResource -Members $script:username1,$script:username2 @commonSetupArgs
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeTrue -Because 'the specified members list matches the current group members list'

        $result = Test-TargetResource -Members $script:username2 @commonSetupArgs
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeTrue -Because 'all specified members exist in the current group members list'

        $result = Test-TargetResource -Members $script:username3 @commonSetupArgs
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeFalse -Because 'all specified members do not exist in the current group members list'

        $result = Test-TargetResource -Members $script:username2,$script:username3 @commonSetupArgs
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeFalse -Because 'only some specified members exist in the current group members list'

        # EnsureMembers='Absent'
        $commonSetupArgs = @{
            Name = $script:groupName;
            Ensure = 'Present';
            Description = $script:description;
            EnsureMembers = 'Absent';
        }

        $result = Test-TargetResource -Members @() @commonSetupArgs
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeTrue -Because 'the specified members array is empty'

        $result = Test-TargetResource -Members $script:username3 @commonSetupArgs
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeTrue -Because 'all specified members do not exist in the current group members list'

        $result = Test-TargetResource -Members $script:username1,$script:username2 @commonSetupArgs
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeFalse -Because 'the specified members list matches the current group members list'

        $result = Test-TargetResource -Members $script:username2 @commonSetupArgs
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeFalse -Because 'all specified members exist in the current group members list'

        $result = Test-TargetResource -Members $script:username2,$script:username3 @commonSetupArgs
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeFalse -Because 'only some specified members exist in the current group members list'
    }

    It 'set target resource' {
        $VerbosePreference = 'Continue'

        $script:groupName = 'TestCarbonGroup01'

        # Test for group creation
        Set-TargetResource -Name $script:groupName -Ensure 'Present'

        $group = Get-CGroup -Name $script:groupName
        $group | Should -Not -BeNullOrEmpty
        $group.Name | Should -Be $script:groupName
        $group.Description | Should -BeNullOrEmpty
        $group.Members.Count | Should -Be 0

        # Change members
        ## EnsureMembers='Exact'
        foreach ($i in 0..1)
        {
            Set-TargetResource -Name $script:groupName -Members $script:username1 -Ensure 'Present'
        }

        $group = Get-CGroup -Name $script:groupName
        $group | Should -Not -BeNullOrEmpty
        $group.Name | Should -Be $script:groupName
        $group.Description | Should -BeNullOrEmpty
        $group.Members.Count | Should -Be 1
        $group.Members.Sid | Should -Be $script:user1.Sid

        ## EnsureMembers='Present'
        foreach ($i in 0..1)
        {
            Set-TargetResource -Name $script:groupName -EnsureMembers 'Present' -Members $script:username2 -Ensure 'Present'
        }

        $group = Get-CGroup -Name $script:groupName
        $group | Should -Not -BeNullOrEmpty
        $group.Name | Should -Be $script:groupName
        $group.Description | Should -BeNullOrEmpty
        $group.Members.Count | Should -Be 2
        ($group.Members.Sid -contains $script:user1.Sid) | Should -BeTrue -Because "$script:username1 is an existing member"
        ($group.Members.Sid -contains $script:user2.Sid) | Should -BeTrue -Because "$script:username2 should have been added to the group"

        ## EnsureMembers='Absent'
        foreach ($i in 0..1)
        {
            Set-TargetResource -Name $script:groupName -EnsureMembers 'Absent' -Members $script:username2 -Ensure 'Present'
        }

        $group = Get-CGroup -Name $script:groupName
        $group | Should -Not -BeNullOrEmpty
        $group.Name | Should -Be $script:groupName
        $group.Description | Should -BeNullOrEmpty
        $group.Members.Count | Should -Be 1
        ($group.Members.Sid -notcontains $script:user2.Sid) | Should -BeTrue -Because "$script:username2 should have been removed to the group"
        ($group.Members.Sid -contains $script:user1.Sid) | Should -BeTrue -Because "$script:username1 is an existing member"

        # Change description
        Set-TargetResource -Name $script:groupName -Members $script:username1 -Description 'group description' -Ensure 'Present'

        $group = Get-CGroup -Name $script:groupName
        $group | Should -Not -BeNullOrEmpty
        $group.Name | Should -Be $script:groupName
        $group.Description | Should -Be 'group description'
        $group.Members.Count | Should -Be 1
        $group.Members[0].Sid | Should -Be $script:user1.Sid

        # expected to add member
        Set-TargetResource -Name $script:groupName -Members $script:username1,$script:username2 -Description 'group description' -Ensure 'Present'
        $group = Get-CGroup -Name $script:groupName
        $group | Should -Not -BeNullOrEmpty
        $group.Name | Should -Be $script:groupName
        $group.Description | Should -Be 'group description'
        $group.Members.Count | Should -Be 2
        ($group.Members.Sid -contains $script:user1.Sid) | Should -BeTrue
        ($group.Members.Sid -contains $script:user2.Sid) | Should -BeTrue

        # expected to support whatif for updating group
        Set-TargetResource -Name $script:groupName -Description 'new description' -WhatIf
        $group = Get-CGroup -Name $script:groupName
        $group.Description | Should -Be 'group description'

        # exepected to support whatif for removing members
        Set-TargetResource -Name $script:groupName -Description 'group description' -WhatIf
        $group = Get-CGroup -Name $script:groupName
        $group.Members.Count | Should -Be 2

        # expected to remove members and set description
        Set-TargetResource -Name $script:groupName -Ensure 'Present'
        $group = Get-CGroup -Name $script:groupName
        $group | Should -Not -BeNullOrEmpty
        $group.Name | Should -Be $script:groupName
        $group.Description | Should -BeNullOrEmpty
        $group.Members.Count | Should -Be 0

        # expected to support WhatIf
        Set-TargetResource -Name $script:groupName -Ensure Absent -WhatIf
        (Test-CGroup -Name $script:groupName) | Should -BeTrue

        # Test for group deletion
        Set-TargetResource -Name $script:groupName -Ensure 'Absent'
        (Test-CGroup -Name $script:groupName) | Should -BeFalse
    }

    $skipDscTest =
        (Test-Path -Path 'env:WHS_CI') -and $env:WHS_CI -eq 'True' -and $PSVersionTable['PSVersion'].Major -eq 7

    It 'should run through dsc' -Skip:$skipDscTest {
        configuration ShouldCreateGroup
        {
            param(
                $Ensure
            )

            Set-StrictMode -Off

            Import-DscResource -Name '*' -Module 'Carbon.DSC'

            node 'localhost'
            {
                Carbon_Group CarbonTestGroup
                {
                    Name = 'CDscGroup1'
                    Description = 'Carbon_Group DSC resource test group'
                    Members = @( $script:username1 )
                    Ensure = $Ensure
                }
            }
        }

        $script:groupName = 'CDscGroup1'

        # Test for group creation through DSC execution
        & ShouldCreateGroup -Ensure 'Present' -OutputPath $CarbonDscOutputRoot
        Start-DscConfiguration -Wait -ComputerName 'localhost' -Path $CarbonDscOutputRoot -Force
        $Global:Error.Count | Should -Be 0

        $result = Test-TargetResource -Name $script:groupName -Description 'Carbon_Group DSC resource test group' -Members $script:username1
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeTrue

        # Test for group deletion through DSC execution
        & ShouldCreateGroup -Ensure 'Absent' -OutputPath $CarbonDscOutputRoot
        Start-DscConfiguration -Wait -ComputerName 'localhost' -Path $CarbonDscOutputRoot -Force
        $Global:Error.Count | Should -Be 0

        $result = Test-TargetResource -Name $script:groupName
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeFalse

        $result = Get-DscConfiguration
        $Global:Error.Count | Should -Be 0
        $result | Should -BeOfType ([Microsoft.Management.Infrastructure.CimInstance])
        $result.PsTypeNames | Where-Object { $_ -like '*Carbon_Group' } | Should -Not -BeNullOrEmpty
    }
}
