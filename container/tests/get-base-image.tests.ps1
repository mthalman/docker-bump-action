BeforeAll {
    $global:LASTEXITCODE = 0
    Mock Invoke-Expression { $global:LASTEXITCODE = 0 } -ParameterFilter { $Command -like "dotnet *" }
    Mock Test-Path { $true }
    Mock Out-File {}

    $targetScript = "$PSScriptRoot/../get-base-image.ps1"
}

Describe 'Get base image' {
    Context "When no base stage name is provided" {
        It 'Given a Dockerfile with a single stage, it returns the base image' {
            Mock Invoke-Expression {
                $fromOutput = @(
                    @{
                        fromInstruction = @{
                            imageName = "foo"
                        }
                    }
                )
                $fromOutput | ConvertTo-Json
            } -ParameterFilter { $Command -eq "dfspy query from -f Dockerfile --layout graph" }
    
            & $targetScript -DockerfilePath 'Dockerfile' | Should -Be "foo"
        }
    
        It 'Given a Dockerfile with multiple stages, it returns the base image' {
            Mock Invoke-Expression {
                $fromOutput = @(
                    @{
                        fromInstruction = @{
                            imageName = "stage2"
                            stageName = "stage1"
                        }
                        parent = @{
                            fromInstruction = @{
                                imageName = "stage3"
                                stageName = "stage2"
                            }
                            parent = @{
                                fromInstruction = @{
                                    imageName = "foo3"
                                    stageName = "stage3"
                                }
                            }
                        }
                    }
                )
                $fromOutput | ConvertTo-Json -Depth 10
            } -ParameterFilter { $Command -eq "dfspy query from -f Dockerfile --layout graph" }
    
            & $targetScript -DockerfilePath 'Dockerfile' | Should -Be "foo3"
        }
    
        It 'Given a Dockerfile with multiple leaf stages, it returns the base image' {
            Mock Invoke-Expression {
                $fromOutput = @(
                    @{
                        fromInstruction = @{
                            imageName = "stage2"
                            stageName = "stage1"
                        }
                        parent = @{
                            fromInstruction = @{
                                imageName = "foo2"
                                stageName = "stage2"
                            }
                        }
                    },
                    @{
                        fromInstruction = @{
                            imageName = "stage4"
                            stageName = "stage3"
                        }
                        parent = @{
                            fromInstruction = @{
                                imageName = "foo4"
                                stageName = "stage4"
                            }
                        }
                    }
                )
                $fromOutput | ConvertTo-Json -Depth 10
            } -ParameterFilter { $Command -eq "dfspy query from -f Dockerfile --layout graph" }
    
            & $targetScript -DockerfilePath 'Dockerfile' | Should -Be "foo4"
        }
    }

    Context "When base stage name is provided" {
        It 'Given a Dockerfile with a single stage, it returns the base image' {
            Mock Invoke-Expression {
                $fromOutput = @(
                    @{
                        imageName = "foo"
                        stageName = "stage1"
                    }
                )
                $fromOutput | ConvertTo-Json
            } -ParameterFilter { $Command -eq "dfspy query from -f Dockerfile" }
    
            & $targetScript -DockerfilePath 'Dockerfile' -BaseStageName stage1 | Should -Be "foo"
        }
    
        It 'Given a Dockerfile with multiple stages, it returns the base image' {
            Mock Invoke-Expression {
                $fromOutput = @(
                    @{
                        imageName = "foo3"
                        stageName = "stage1"
                    },
                    @{
                        imageName = "stage1"
                        stageName = "stage2"
                    },
                    @{
                        imageName = "stage2"
                    }
                )
                $fromOutput | ConvertTo-Json -Depth 10
            } -ParameterFilter { $Command -eq "dfspy query from -f Dockerfile" }
    
            & $targetScript -DockerfilePath 'Dockerfile' -BaseStageName stage1 | Should -Be "foo3"
        }
    }

    It 'Given a Dockerfile path that does not exist, it throws an error' {
        Mock Test-Path { $false }

        { & $targetScript -DockerfilePath 'Dockerfile' } | Should -Throw "Dockerfile path 'Dockerfile' does not exist."
    }

    It 'Given a failed dfspy command, it throws an error' {
        Mock Invoke-Expression { $global:LASTEXITCODE = 1 } -ParameterFilter { $Command -like "dfspy *" }

        { & $targetScript -DockerfilePath 'Dockerfile' } | Should -Throw "dfspy failed"
    }
}
