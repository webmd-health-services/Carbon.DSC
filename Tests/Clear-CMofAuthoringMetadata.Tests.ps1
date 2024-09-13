
#Require -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

    $script:mof1Path = $null
    $script:mof2Path = $null
    $script:notAMofPath = $null
    $script:mof3Path = $null
    $script:tempDir = $null
    $script:mof = $null
    $script:clearedMof = @'
/*
@TargetNode='********'
*/

/* ...snip... */


instance of OMI_ConfigurationDocument
{
    Version="1.0.0";
};
'@
}


Describe 'Clear-CMofAuthoringMetadata' {
    BeforeEach {
        $Global:Error.Clear()
        $script:tempDir = Join-Path -Path $TestDrive -ChildPath ([IO.Path]::GetRandomFileName())
        New-Item -Path $script:tempDir -ItemType 'Directory'
        $script:mof1Path = Join-Path -Path $script:tempDir -ChildPath 'computer1.mof'
        $script:mof2Path = Join-Path -Path $script:tempDir -ChildPath 'computer2.mof'
        $script:mof3Path = Join-Path -Path $script:tempDir -ChildPath 'computer3.txt'
        $script:notAMofPath = Join-Path -Path $script:tempDir -ChildPath 'computer2.txt'

        $script:mof = @'
/*
@TargetNode='********'
@GeneratedBy=********
@GenerationDate=08/19/2014 13:29:15
@GenerationHost=********
*/

/* ...snip... */


instance of OMI_ConfigurationDocument
{
    Version="1.0.0";
    Author="********;
    GenerationDate="08/19/2014 13:29:15";
    GenerationHost="********";
};
'@

        $script:mof | Set-Content -Path $script:mof1Path
        $script:mof | Set-Content -Path $script:mof2Path
        $script:mof | Set-Content -Path $script:mof3Path
        $script:mof | Set-Content -Path $script:notAMofPath
    }

    It 'clears authoring metadata from file' {
        Clear-CMofAuthoringMetadata -Path $script:mof1Path
        (Get-Content -Raw $script:mof1Path).Trim() | Should -Be $script:clearedMof
        (Get-Content -Raw $script:mof2Path).Trim() | Should -Be $script:mof
        (Get-Content -Raw $script:mof3Path).Trim() | Should -Be $script:mof
        (Get-Content -Raw $script:notAMofPath).Trim() | Should -Be $script:mof
    }

    It 'clears authoring metadata from file without mof extension' {
        Clear-CMofAuthoringMetadata -Path $script:mof3Path
        (Get-Content -Raw $script:mof3Path).Trim() | Should -Be $script:clearedMof
        (Get-Content -Raw $script:mof2Path).Trim() | Should -Be $script:mof
        (Get-Content -Raw $script:mof1Path).Trim() | Should -Be $script:mof
        (Get-Content -Raw $script:notAMofPath).Trim() | Should -Be $script:mof
    }

    It 'clears authoring metadata from directory' {
        Clear-CMofAuthoringMetadata -Path $script:tempDir
        (Get-Content -Raw $script:mof1Path).Trim() | Should -Be $script:clearedMof
        (Get-Content -Raw $script:mof2Path).Trim() | Should -Be $script:clearedMof
        (Get-Content -Raw $script:mof3Path).Trim() | Should -Be $script:mof
        (Get-Content -Raw $script:notAMofPath).Trim() | Should -Be $script:mof
    }

    It 'checks if path exists' {
        Clear-CMofAuthoringMetadata -Path ('C:\{0}' -f ([IO.Path]::GetRandomFileName())) -ErrorAction SilentlyContinue
        $Global:Error.Count | Should -BeGreaterThan 0
        $Global:Error[0] | Should -Match 'does not exist'
        $Error.Count | Should -Be 1
    }

    It 'supports WhatIf' {
        Clear-CMofAuthoringMetadata -Path $script:mof1Path -WhatIf
        (Get-Content -Raw $script:mof1Path).Trim() | Should -Be $script:mof
    }
}
