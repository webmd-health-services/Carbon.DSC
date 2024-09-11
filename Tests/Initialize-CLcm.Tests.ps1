
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

    $modulesPath = Join-Path -Path $PSScriptRoot -ChildPath '..\Carbon.DSC\Modules' -Resolve
    Import-Module -Name (Join-Path -Path $modulesPath -ChildPath 'Carbon.Cryptography' -Resolve) `
                  -Function @('Get-CCertificate', 'Uninstall-CCertificate') `
                  -Verbose:$false

    $script:originalLcm = $null
    $script:tempDir = $null
    $script:privateKeyPath = Join-Path -Path $PSScriptRoot -ChildPath 'TestPrivateKey.pfx' -Resolve
    $script:publicKeyPath = Join-Path -Path $PSScriptRoot -ChildPath 'TestPublicKey.cer' -Resolve
    $script:publicKey = $null
    $script:certPath = $null

    function Uninstall-TestLcmCertificate
    {
        $script:publicKey = Get-CCertificate -Path $script:publicKeyPath
        $script:publicKey | Should -Not -BeNullOrEmpty
        $script:certPath = Join-Path -Path 'cert:\LocalMachine\My' -ChildPath $script:publicKey.Thumbprint
        if( (Test-Path -Path $script:certPath -PathType Leaf) )
        {
            Uninstall-CCertificate -Thumbprint $script:publicKey.Thumbprint -StoreLocation LocalMachine -StoreName My
        }
    }
}

Describe 'Initialize-CLcm' -Skip:(Test-Path -Path 'env:APPVEYOR') {
    BeforeEach {
        $script:tempDir = Join-Path -Path $TestDrive -ChildPath ([IO.Path]::GetRandomFileName())
        $script:originalLcm = Get-DscLocalConfigurationManager
        Uninstall-TestLcmCertificate

        $Global:Error.Clear()
    }

    AfterEach {
        configuration SetPullMode
        {
            Set-StrictMode -Off

            $customData = @{ }
            foreach( $item in $script:originalLcm.DownloadManagerCustomData )
            {
                $customData[$item.key] = $item.value
            }

            node 'localhost'
            {
                LocalConfigurationManager
                {
                    AllowModuleOverwrite = $script:originalLcm.AllowModuleOverwrite;
                    ConfigurationMode = $script:originalLcm.ConfigurationMode;
                    ConfigurationID = $script:originalLcm.ConfigurationID;
                    ConfigurationModeFrequencyMins = $script:originalLcm.ConfigurationModeFrequencyMins;
                    CertificateID = $script:originalLcm.CertificateID;
                    DownloadManagerName = $script:originalLcm.DownloadManagerName;
                    DownloadManagerCustomData = $customData
                    RefreshMode = $script:originalLcm.RefreshMode;
                    RefreshFrequencyMins = $script:originalLcm.RefreshFrequencyMins;
                    RebootNodeIfNeeded = $script:originalLcm.RebootNodeIfNeeded;
                }
            }
        }

        $outputPath = Join-Path -Path $script:tempDir -ChildPath 'originalLcm'
        & SetPullMode -OutputPath $outputPath
        Set-DscLocalConfigurationManager -Path $outputPath
        Uninstall-TestLcmCertificate
    }

    It 'configures push mode' {
        $lcm = Get-DscLocalConfigurationManager
        $rebootIfNeeded = -Not $lcm.RebootNodeIfNeeded
        $lcm = Initialize-CLcm -Push -ComputerName 'localhost' -CertFile $script:privateKeyPath -RebootIfNeeded
        $Global:Error.Count | Should -Be 0
        $lcm | Should -Not -BeNullOrEmpty
        $script:publicKey.Thumbprint | Should -Be $lcm.CertificateID
        $lcm.RebootNodeIfNeeded | Should -BeTrue
        $lcm.RefreshMode | Should -Be 'Push'
        (Test-Path -Path $script:certPath -PathType Leaf) | Should -BeTrue
    }

    It 'preserves certificate id when cert file not given' {
        $lcm = Get-DscLocalConfigurationManager
        $rebootIfNeeded = -Not $lcm.RebootNodeIfNeeded
        $lcm = Initialize-CLcm -Push -ComputerName 'localhost' -CertificateID 'fubar' -CertFile $script:privateKeyPath -RebootIfNeeded
        $Global:Error.Count | Should -Be 0
        $lcm.CertificateID | Should -Be $script:publicKey.Thumbprint
        $lcm = Initialize-CLcm -Push -ComputerName 'localhost' -CertificateID $script:publicKey.Thumbprint -RebootIfNeeded
        $lcm.CertificateID | Should -Be $script:publicKey.Thumbprint
    }

    It 'validates cert file path' {
        $script:originalLcm = Initialize-CLcm -Push -ComputerName 'localhost' -CertFile $script:privateKeyPath
        $lcm = Initialize-CLcm -Push -ComputerName 'localhost' -CertFile 'C:\jdskfjsdflkfjksdlf.pfx' -ErrorAction SilentlyContinue
        $Global:Error.Count | Should -BeGreaterThan 0
        $Global:Error[0] | Should -Match 'not found'
        $lcm | Should -BeNullOrEmpty
        (Get-DscLocalConfigurationManager).CertificateID | Should -Be $script:originalLcm.CertificateID
    }

    It 'handles file that is not a certificate' {
        $script:originalLcm = Initialize-CLcm -Push -ComputerName 'localhost' -CertFile $script:privateKeyPath
        $lcm = Initialize-CLcm -Push -ComputerName 'localhost' -CertFile $PSCommandPath  -ErrorAction SilentlyContinue
        $Global:Error.Count | Should -BeGreaterThan 0
        $Global:Error[0] | Should -Match 'exception creating X509Certificate2'
        $lcm | Should -BeNullOrEmpty
        (Get-DscLocalConfigurationManager).CertificateID | Should -Be $script:originalLcm.CertificateID
    }

    It 'handles relative cert file path' {
        Push-Location -Path $PSScriptRoot
        try
        {
            $lcm = Initialize-CLcm -Push -ComputerName 'localhost' -CertFile (Resolve-Path -Path $script:privateKeyPath -Relative)
            $Global:Error.Count | Should -Be 0
            $lcm | Should -Not -BeNullOrEmpty
            $lcm.CertificateID | Should -Be $script:publicKey.Thumbprint
        }
        finally
        {
            Pop-Location
        }
    }

    It 'validates cert has private key' {
        $script:originalLcm = Get-DscLocalConfigurationManager
        $lcm = Initialize-CLcm -Push -ComputerName 'localhost' -CertFile $script:publicKeyPath -ErrorAction SilentlyContinue
        $Global:Error.Count | Should -BeGreaterThan 0
        $Global:Error[0] | Should -Match 'does not have a private key'
        $lcm | Should -BeNullOrEmpty
        (Get-DscLocalConfigurationManager).CertificateID | Should -Be $script:originalLcm.CertificateID
    }

    It 'clears unprovided push values' {
        # Make sure if no cert file specified, the original is left alone.
        $script:originalLcm = Initialize-CLcm -Push -ComputerName 'localhost' -CertFile $script:privateKeyPath -RebootIfNeeded
        $lcm = Initialize-CLcm -Push -ComputerName 'localhost'
        $Global:Error.Count | Should -Be 0
        $lcm | Should -Not -BeNullOrEmpty
        $lcm.CertificateID | Should -BeNullOrEmpty
        $lcm.RebootNodeIfNeeded | Should -Be $false
    }

    It 'validates computer name' {
        $lcm = Initialize-CLcm -Push -ComputerName 'fubar' -ErrorAction SilentlyContinue
        $Global:Error.Count | Should -BeGreaterThan 0
        $Global:Error[0] | Should -Match 'not found or is unreachable'
        $lcm | Should -BeNullOrEmpty
    }

    It 'uploads certificate with secure string and plaintext passwords' {
        $securePrivateKeyPath = Join-Path -Path $PSScriptRoot -ChildPath 'TestPrivateKey2.pfx'
        $securePrivateKeyPasswod = 'fubar'
        $securePrivateKeySecurePassword = ConvertTo-SecureString -String $securePrivateKeyPasswod -AsPlainText -Force
        $securePrivateKey = Get-CCertificate -Path $securePrivateKeyPath -Password $securePrivateKeySecurePassword
        $securePrivateKey | Should -Not -BeNullOrEmpty

        Uninstall-CCertificate -Thumbprint $securePrivateKey.Thumbprint -StoreLocation LocalMachine -StoreName My

        $lcm = Initialize-CLcm -Push -ComputerName 'localhost' -CertFile $securePrivateKeyPath -CertPassword $securePrivateKeyPasswod
        $Global:Error.Count | Should -Be 0
        $secureCertPath = Join-Path -Path 'cert:\LocalMachine\My' -ChildPath $securePrivateKey.Thumbprint
        (Test-Path -Path $secureCertPath -PathType Leaf) | Should -BeTrue
        $lcm.CertificateID | Should -Be $securePrivateKey.Thumbprint

        Uninstall-CCertificate -Thumbprint $securePrivateKey.Thumbprint -StoreLocation LocalMachine -StoreName My

        $lcm = Initialize-CLcm -Push -ComputerName 'localhost' -CertFile $securePrivateKeyPath -CertPassword $securePrivateKeySecurePassword
        $Global:Error.Count | Should -Be 0
        (Test-Path -Path $secureCertPath -PathType Leaf) | Should -BeTrue
        $lcm.CertificateID | Should -Be $securePrivateKey.Thumbprint
    }

    It 'supports WhatIf' {
        $lcm = Initialize-CLcm -Push -ComputerName 'localhost'

        $lcm = Initialize-CLcm -Push -ComputerName 'localhost' -CertFile $script:privateKeyPath -WhatIf
        $lcm | Should -Not -BeNullOrEmpty

        $lcm.CertificateID | Should -BeNullOrEmpty
        (Test-Path -Path $script:certPath -PathType Leaf) | Should -Be $false
    }

    It 'configures file download manager' {
        $Global:Error.Clear()

        $configID = [Guid]::NewGuid()
        $lcm = Initialize-CLcm -SourcePath $PSScriptRoot `
                              -ConfigurationID $configID `
                              -ComputerName 'localhost' `
                              -AllowModuleOverwrite `
                              -CertFile $script:privateKeyPath `
                              -ConfigurationMode ApplyOnly `
                              -RebootIfNeeded `
                              -RefreshIntervalMinutes 35 `
                              -ConfigurationFrequency 3 `
                              -LcmCredential $CarbonTestUser `
                              -ErrorAction SilentlyContinue

        if( [Environment]::OSVersion.Version.Major -ge 10 )
        {
            $Global:Error.Count | Should -BeGreaterThan 0
            return
        }

        $Global:Error.Count | Should -Be 0
        $lcm | Should -Not -BeNullOrEmpty
        $lcm.ConfigurationID | Should -Be $configID
        $lcm.AllowModuleOverwrite | Should -BeTrue
        $lcm.RebootNodeIfNeeded | Should -BeTrue
        $lcm.ConfigurationMode | Should -Be 'ApplyOnly'
        $lcm.RefreshFrequencyMins | Should -Be 35
        $lcm.ConfigurationModeFrequencyMins | Should -Be 105
        $lcm.DownloadManagerName | Should -Be 'DscFileDownloadManager'
        $lcm.DownloadManagerCustomData[0].value | Should -Be $PSScriptRoot
        $lcm.Credential.UserName | Should -Be $username
        $lcm.CertificateID | Should -Be $script:publicKey.Thumbprint
        $lcm.RefreshMode | Should -Be 'Pull'

        $configID = [Guid]::NewGuid().ToString()
        $lcm = Initialize-CLcm -SourcePath $env:TEMP -ConfigurationID $configID -ConfigurationMode ApplyAndMonitor -ComputerName 'localhost'

        $Global:Error.Count | Should -Be 0
        $lcm | Should -Not -BeNullOrEmpty
        $lcm.ConfigurationID | Should -Be $configID
        $lcm.AllowModuleOverwrite | Should -Be $false
        $lcm.RebootNodeIfNeeded | Should -Be $false
        $lcm.ConfigurationMode | Should -Be 'ApplyAndMonitor'
        $lcm.RefreshFrequencyMins | Should -Be 30
        $lcm.ConfigurationModeFrequencyMins | Should -Be 30
        $lcm.DownloadManagerName | Should -Be 'DscFileDownloadManager'
        $lcm.DownloadManagerCustomData[0].value | Should -Be $env:TEMP
        $lcm.CertificateID | Should -BeNullOrEmpty
        $lcm.Credential | Should -BeNullOrEmpty
        $lcm.RefreshMode | Should -Be 'Pull'
    }


    It 'configures web download manager' {
        $Global:Error.Clear()

        $configID = [Guid]::NewGuid()
        $lcm = Initialize-CLcm -ServerUrl 'http://localhost:8976' `
                              -AllowUnsecureConnection `
                              -ConfigurationID $configID `
                              -ComputerName 'localhost' `
                              -AllowModuleOverwrite `
                              -CertFile $script:privateKeyPath `
                              -ConfigurationMode ApplyOnly `
                              -RebootIfNeeded `
                              -RefreshIntervalMinutes 40 `
                              -ConfigurationFrequency 3 `
                              -LcmCredential $CarbonTestUser `
                              -ErrorAction SilentlyContinue

        if( [Environment]::OSVersion.Version.Major -ge 10 )
        {
            $Global:Error.Count | Should -BeGreaterThan 0
            return
        }

        $Global:Error.Count | Should -Be 0
        $lcm | Should -Not -BeNullOrEmpty
        $lcm.ConfigurationID | Should -Be $configID
        $lcm.AllowModuleOverwrite | Should -BeTrue
        $lcm.RebootNodeIfNeeded | Should -BeTrue
        $lcm.ConfigurationMode | Should -Be 'ApplyOnly'
        $lcm.RefreshFrequencyMins | Should -Be 40
        $lcm.ConfigurationModeFrequencyMins | Should -Be 120
        $lcm.DownloadManagerName | Should -Be 'WebDownloadManager'
        $lcm.DownloadManagerCustomData[0].value | Should -Be 'http://localhost:8976'
        $lcm.DownloadManagerCustomData[1].value | Should -Be 'True'
        $lcm.Credential.UserName | Should -Be $username
        $lcm.CertificateID | Should -Be $script:publicKey.Thumbprint
        $lcm.RefreshMode | Should -Be 'Pull'

        $configID = [Guid]::NewGuid().ToString()
        $lcm = Initialize-CLcm -ServerUrl 'https://localhost:6798' -ConfigurationID $configID -ConfigurationMode ApplyAndMonitor -ComputerName 'localhost'

        $Global:Error.Count | Should -Be 0
        $lcm | Should -Not -BeNullOrEmpty
        $lcm.ConfigurationID | Should -Be $configID
        $lcm.AllowModuleOverwrite | Should -Be $false
        $lcm.RebootNodeIfNeeded | Should -Be $false
        $lcm.ConfigurationMode | Should -Be 'ApplyAndMonitor'
        $lcm.RefreshFrequencyMins | Should -Be 30
        $lcm.ConfigurationModeFrequencyMins | Should -Be 30
        $lcm.DownloadManagerName | Should -Be 'WebDownloadManager'
        $lcm.DownloadManagerCustomData[0].value | Should -Be 'https://localhost:6798'
        $lcm.DownloadManagerCustomData[1].value | Should -Be 'False'
        $lcm.Credential | Should -BeNullOrEmpty
        $lcm.CertificateID | Should -BeNullOrEmpty
        $lcm.RefreshMode | Should -Be 'Pull'
    }

    It 'clears pull values when switching to push' -Skip:([Environment]::OSVersion.Version.Major -ge 10) {
        $configID = [Guid]::NewGuid()
        $lcm = Initialize-CLcm -SourcePath $PSScriptRoot `
                                -ConfigurationID $configID `
                                -ComputerName 'localhost' `
                                -AllowModuleOverwrite `
                                -CertFile $script:privateKeyPath `
                                -ConfigurationMode ApplyOnly `
                                -RebootIfNeeded `
                                -RefreshIntervalMinutes 45 `
                                -ConfigurationFrequency 3 `
                                -LcmCredential $CarbonTestUser
        $Global:Error.Count | Should -Be 0
        $lcm | Should -Not -BeNullOrEmpty

        $lcm = Initialize-CLcm -Push -ComputerName 'localhost'
        $Global:Error.Count | Should -Be 0
        $lcm | Should -Not -BeNullOrEmpty
        $lcm.ConfigurationID | Should -BeNullOrEmpty
        $lcm.AllowModuleOverwrite | Should -Be 'False'
        $lcm.RebootNodeIfNeeded | Should -Be 'False'
        $lcm.ConfigurationMode | Should -Be 'ApplyAndMonitor'
        $lcm.RefreshFrequencyMins | Should -Not -Be (45 * 3)
        $lcm.ConfigurationModeFrequencyMins | Should -Not -Be 45
        $lcm.DownloadManagerName | Should -BeNullOrEmpty
        $lcm.DownloadManagerCustomData | Should -BeNullOrEmpty
        $lcm.Credential | Should -BeNullOrEmpty
        $lcm.CertificateID | Should -BeNullOrEmpty
        $lcm.RefreshMode | Should -Be 'Push'
    }
}
