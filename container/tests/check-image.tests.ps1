Import-Module -Force $PSScriptRoot/../common.psm1

BeforeAll {    
    $global:LASTEXITCODE = 0
    Mock Out-File { } -ModuleName common
    
    $targetImage = "foo"
    $baseImage = "bar"
    $architecture = "amd64"

    $targetScript = "$PSScriptRoot/../check-image.ps1"
}

Describe 'Get result' {
    It 'Given a target image that is up-to-date with the base image, it returns false' {
        Mock Invoke-Expression {
            $result = @{
                Summary = @{
                    TargetIncludesAllBaseLayers = $true
                }
            }
            $result | ConvertTo-Json
        } -ParameterFilter { $Command -eq "dredge image compare layers --output json $baseImage $targetImage --os linux --arch $architecture" } `
          -ModuleName common
        
        Mock Invoke-Expression {
            "base-digest"
        } -ParameterFilter { $Command -eq "dredge manifest resolve $baseImage --os linux --arch $architecture" } `
          -ModuleName common
        
        Mock Invoke-Expression {
            "target-digest"
        } -ParameterFilter { $Command -eq "dredge manifest resolve $targetImage --os linux --arch $architecture" } `
          -ModuleName common
        $result = & $targetScript -TargetImage $targetImage -BaseImage $baseImage -Architecture $architecture

        $expected = @{
            sendDispatch = "false"
            updates = @()
        } | ConvertTo-Json

        $result | Should -Be $expected
    }

    It 'Given a target image that is not up-to-date with the base image, it returns true' {
        Mock Invoke-Expression {
            $result = @{
                Summary = @{
                    TargetIncludesAllBaseLayers = $false
                }
            }
            $result | ConvertTo-Json
        } -ParameterFilter { $Command -eq "dredge image compare layers --output json $baseImage $targetImage --os linux --arch $architecture" } `
          -ModuleName common
        
          Mock Invoke-Expression {
            "base-digest"
        } -ParameterFilter { $Command -eq "dredge manifest resolve $baseImage --os linux --arch $architecture" } `
          -ModuleName common
        
        Mock Invoke-Expression {
            "target-digest"
        } -ParameterFilter { $Command -eq "dredge manifest resolve $targetImage --os linux --arch $architecture" } `
          -ModuleName common
        $result = & $targetScript -TargetImage $targetImage -BaseImage $baseImage -Architecture $architecture

        $expected = @{
            sendDispatch = "true"
            updates = @(
                @{
                    targetImageName = $targetImage
                    targetImageDigest = "target-digest"
                    dockerfile = ""
                    baseImageName = $baseImage
                    baseImageDigest = "base-digest"
                }
            )
        } | ConvertTo-Json

        $result | Should -Be $expected
    }

    It 'Given a failed dredge command, it throws an error' {
        Mock Invoke-Expression { $global:LASTEXITCODE = 1 } -ParameterFilter { $Command -like "dredge *" } -ModuleName common

        { & $targetScript -TargetImage $targetImage -BaseImage $baseImage -Architecture $architecture } | Should -Throw "Command failed with exit code 1: dredge image compare layers --output json bar foo --os linux --arch amd64"
    }
}
