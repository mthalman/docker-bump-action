BeforeAll {
    $global:LASTEXITCODE = 0
    Mock Invoke-Expression { $global:LASTEXITCODE = 0 } -ParameterFilter { $Command -like "dotnet *" }

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
        } -ParameterFilter { $Command -eq "dredge image compare layers --output json $baseImage $targetImage --os linux --arch $architecture" }
        & $targetScript -TargetImage $targetImage -BaseImage $baseImage -Architecture $architecture | Should -Be "false"
    }

    It 'Given a target image that is not up-to-date with the base image, it returns true' {
        Mock Invoke-Expression {
            $result = @{
                Summary = @{
                    TargetIncludesAllBaseLayers = $false
                }
            }
            $result | ConvertTo-Json
        } -ParameterFilter { $Command -eq "dredge image compare layers --output json $baseImage $targetImage --os linux --arch $architecture" }

        & $targetScript -TargetImage $targetImage -BaseImage $baseImage -Architecture $architecture | Should -Be "true"
    }

    It 'Given a failed dredge command, it throws an error' {
        Mock Invoke-Expression { $global:LASTEXITCODE = 1 } -ParameterFilter { $Command -like "dredge *" }

        { & $targetScript -TargetImage $targetImage -BaseImage $baseImage -Architecture $architecture } | Should -Throw "dredge image compare failed"
    }
}
