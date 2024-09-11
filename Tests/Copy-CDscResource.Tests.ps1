
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

    $script:sourceRoot = $null;
    $script:destinationRoot = $null

    function Assert-Copy
    {
        param(
            $SourceRoot,

            $DestinationRoot,

            [switch] $Recurse
        )

        Get-ChildItem -Path $SourceRoot | ForEach-Object {

            $destinationPath = Join-Path -Path $DestinationRoot -ChildPath $_.Name

            if( $_.PSIsContainer )
            {
                if( $Recurse )
                {
                    Test-Path -PathType Container -Path $destinationPath | Should -BeTrue
                    Assert-Copy -SourceRoot $_.FullName -DestinationRoot $destinationPath -Recurse
                }
                else
                {
                    $destinationPath | Should -Not -Exist
                }
                return
            }
            else
            {
                Test-Path -Path $destinationPath -PathType Leaf | Should -BeTrue -Because ($_.FullName)
            }

            $sourceHash = Get-FileHash -Path $_.FullName | Select-Object -ExpandProperty 'Hash'
            $destinationHashPath = '{0}.checksum' -f $destinationPath
            Test-Path -Path $destinationHashPath -PathType Leaf | Should -BeTrue
            # hash files can't have newlines, so we can't use Get-Content.
            $destinationHash = [IO.File]::ReadAllText($destinationHashPath)
            $destinationHash | Should -Be $sourceHash
        }
    }
}

Describe 'Copy-CDscResource' {

    BeforeEach {
        $Global:Error.Clear()
        $script:destinationRoot = Join-Path -Path $TestDrive -ChildPath ('D.{0}' -f [IO.Path]::GetRandomFileName())
        New-Item -Path $script:destinationRoot -ItemType 'Directory'
        $script:sourceRoot = Join-Path -Path $TestDrive -ChildPath ('S.{0}' -f [IO.Path]::GetRandomFileName())
        New-Item -Path (Join-Path -Path $script:sourceRoot -ChildPath 'Dir1\Dir3\zip.zip') -Force
        New-Item -Path (Join-Path -Path $script:sourceRoot -ChildPath 'Dir1\zip.zip')
        New-Item -Path (Join-Path -Path $script:sourceRoot -ChildPath 'Dir2') -ItemType 'Directory'
        New-Item -Path (Join-Path -Path $script:sourceRoot -ChildPath 'zip.zip')
        New-Item -Path (Join-Path -Path $script:sourceRoot -ChildPath 'mov.mof')
        New-Item -Path (Join-Path -Path $script:sourceRoot -ChildPath 'msi.msi')
    }

    It 'should copy files' {
        $result = Copy-CDscResource -Path $script:sourceRoot -Destination $script:destinationRoot
        $result | Should -BeNullOrEmpty
        Assert-Copy $script:sourceRoot $script:destinationRoot
    }

    It 'should pass thru copied files' {
        $result = Copy-CDscResource -Path $script:sourceRoot -Destination $script:destinationRoot -PassThru -Recurse
        $result | Should -Not -BeNullOrEmpty
        Assert-Copy $script:sourceRoot $script:destinationRoot -Recurse
        $result.Count | Should -Be 10
        foreach( $item in $result )
        {
            $item.FullName | Should -BeLike ('{0}*' -f $script:destinationRoot)
        }
    }

    It 'should only copy changed files' {
        $result = Copy-CDscResource -Path $script:sourceRoot -Destination $script:destinationRoot -PassThru
        $result | Should -Not -BeNullOrEmpty
        $result = Copy-CDscResource -Path $script:sourceRoot -Destination $script:destinationRoot -PassThru
        $result | Should -BeNullOrEmpty
        [IO.File]::WriteAllText((Join-path -Path $script:sourceRoot -ChildPath 'mov.mof'), ([Guid]::NewGuid().ToString()))
        $result = Copy-CDscResource -Path $script:sourceRoot -Destination $script:destinationRoot -PassThru
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 2
        $result[0].Name | Should -Be 'mov.mof'
        $result[1].Name | Should -Be 'mov.mof.checksum'
    }

    It 'should always regenerate checksums' {
        $result = Copy-CDscResource -Path $script:sourceRoot -Destination $script:destinationRoot -PassThru
        $result | Should -Not -BeNullOrEmpty
        [IO.File]::WriteAllText((Join-Path -Path $script:sourceRoot -ChildPath 'zip.zip.checksum'), 'E4F0D22EE1A26200BA320E18023A56B36FF29AA1D64913C60B46CE7D71E940C6')
        try
        {
            $result = Copy-CDscResource -Path $script:sourceRoot -Destination $script:destinationRoot -PassThru
            $result | Should -BeNullOrEmpty
            [IO.File]::WriteAllText((Join-Path -Path $script:sourceRoot -ChildPath 'zip.zip'), ([Guid]::NewGuid().ToString()))

            $result = Copy-CDscResource -Path $script:sourceRoot -Destination $script:destinationRoot -PassThru
            $result | Should -Not -BeNullOrEmpty
            $result[0].Name | Should -Be 'zip.zip'
            $result[1].Name | Should -Be 'zip.zip.checksum'
        }
        finally
        {
            Get-ChildItem -Path $script:sourceRoot -Filter '*.checksum' | Remove-Item
            Clear-Content -Path (Join-Path -Path $script:sourceRoot -ChildPath 'zip.zip')
        }
    }

    It 'should copy recursively' {
        $result = Copy-CDscResource -Path $script:sourceRoot -Destination $script:destinationRoot -Recurse
        $result | Should -BeNullOrEmpty
        Assert-Copy -SourceRoot $script:sourceRoot -Destination $script:destinationRoot -Recurse
    }

    It 'should force copy' {
        $result = Copy-CDscResource -Path $script:sourceRoot -Destination $script:destinationRoot -PassThru -Recurse
        $result | Should -Not -BeNullOrEmpty
        Assert-Copy $script:sourceRoot $script:destinationRoot -Recurse
        $result = Copy-CDscResource -Path $script:sourceRoot -Destination $script:destinationRoot -PassThru -Recurse
        $result | Should -BeNullOrEmpty
        $result = Copy-CDscResource -Path $script:sourceRoot -Destination $script:destinationRoot -PassThru -Force -Recurse
        $result | Should -Not -BeNullOrEmpty
        Assert-Copy $script:sourceRoot $script:destinationRoot -Recurse
    }
}
