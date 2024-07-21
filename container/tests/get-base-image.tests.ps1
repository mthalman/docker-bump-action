Import-Module -Force $PSScriptRoot/../common.psm1

BeforeAll {
    $global:LASTEXITCODE = 0
    Mock Test-Path { $true }
    Mock Out-File {} -ModuleName common

    $targetScript = "$PSScriptRoot/../get-base-image.ps1"
    $architecture = "amd64"
}

Describe 'Get base image' {
    Context "When no Dockerfile is provided" {
        It 'Given no Dockerfile, it returns the base image from the target image config LABEL' {
            Mock Invoke-Expression {
                $imageConfig = @{
                    config = @{
                        Labels = @{
                            "my.label" = "val"
                            "org.opencontainers.image.base.name" = "bar"
                        }
                    }
                }
                $imageConfig | ConvertTo-Json
            } -ParameterFilter { $Command -eq "dredge image inspect foo --os linux --arch amd64" } -ModuleName common

            & $targetScript -TargetImage 'foo' -Architecture $architecture | Should -Be "bar"
        }

        It 'Given no Dockerfile, it returns the base image from the target image manifest annotation' {
            Mock Invoke-Expression {
                $imageConfig = @{
                    config = @{
                        Labels = @{}
                    }
                }
                $imageConfig | ConvertTo-Json
            } -ParameterFilter { $Command -eq "dredge image inspect foo --os linux --arch amd64" } -ModuleName common
            
            Mock Invoke-Expression {
                "foo-digest"
            } -ParameterFilter { $Command -eq "dredge manifest resolve foo --os linux --arch amd64" } -ModuleName common

            Mock Invoke-Expression {
                $manifest = @{
                }
                $manifest | ConvertTo-Json
            } -ParameterFilter { $Command -eq "dredge manifest get foo" } -ModuleName common

            Mock Invoke-Expression {
                $manifest = @{
                    annotations = @{
                        "org.opencontainers.image.base.name" = "bar"
                    }
                }
                $manifest | ConvertTo-Json
            } -ParameterFilter { $Command -eq "dredge manifest get foo-digest" } -ModuleName common

            & $targetScript -TargetImage 'foo' -Architecture $architecture | Should -Be "bar"
        }

        It 'Given no Dockerfile, it returns the base image from the target image index annotation' {
            Mock Invoke-Expression {
                $imageConfig = @{
                    config = @{
                        Labels = @{}
                    }
                }
                $imageConfig | ConvertTo-Json
            } -ParameterFilter { $Command -eq "dredge image inspect foo --os linux --arch amd64" } -ModuleName common
            
            Mock Invoke-Expression {
                $manifest = @{
                    annotations = @{
                        "org.opencontainers.image.base.name" = "bar"
                    }
                    mediaType = "application/vnd.oci.image.index.v1+json"
                }
                $manifest | ConvertTo-Json
            } -ParameterFilter { $Command -eq "dredge manifest get foo" } -ModuleName common

            & $targetScript -TargetImage 'foo' -Architecture $architecture | Should -Be "bar"
        }

        It 'Given no Dockerfile, it throws when no annotation is found' {
            Mock Invoke-Expression {
                $imageConfig = @{
                    config = @{
                        Labels = @{}
                    }
                }
                $imageConfig | ConvertTo-Json
            } -ParameterFilter { $Command -eq "dredge image inspect foo --os linux --arch amd64" } -ModuleName common

            Mock Invoke-Expression {
                "foo"
            } -ParameterFilter { $Command -eq "dredge manifest resolve foo --os linux --arch amd64" } -ModuleName common

            Mock Invoke-Expression {
                $manifest = @{
                    annotations = @{
                    }
                }
                $manifest | ConvertTo-Json
            } -ParameterFilter { $Command -eq "dredge manifest get foo" } -ModuleName common

            { & $targetScript -TargetImage 'foo' -Architecture $architecture } | Should -Throw "Could not derive base image name."
        }
    }

    Context "When Dockerfile is provided" {
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
                } -ParameterFilter { $Command -eq "dfspy query from -f Dockerfile --layout graph" } `
                  -ModuleName common
        
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
                } -ParameterFilter { $Command -eq "dfspy query from -f Dockerfile --layout graph" } `
                  -ModuleName common
        
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
                } -ParameterFilter { $Command -eq "dfspy query from -f Dockerfile --layout graph" } `
                  -ModuleName common
        
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
                } -ParameterFilter { $Command -eq "dfspy query from -f Dockerfile" } `
                  -ModuleName common
        
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
                } -ParameterFilter { $Command -eq "dfspy query from -f Dockerfile" } `
                  -ModuleName common
        
                & $targetScript -DockerfilePath 'Dockerfile' -BaseStageName stage1 | Should -Be "foo3"
            }
        }
    
        It 'Given a Dockerfile path that does not exist, it throws an error' {
            Mock Test-Path { $false }
    
            { & $targetScript -DockerfilePath 'Dockerfile' } | Should -Throw "Dockerfile path 'Dockerfile' does not exist."
        }
    
        It 'Given a failed dfspy command, it throws an error' {
            Mock Invoke-Expression { $global:LASTEXITCODE = 1 } -ParameterFilter { $Command -like "dfspy *" } -ModuleName common
    
            { & $targetScript -DockerfilePath 'Dockerfile' } | Should -Throw "Command failed with exit code 1: dfspy query from -f Dockerfile --layout graph"
        }
    
        It 'Given an unknown base stage name, it throws an error' {
            $LASTEXITCODE = 0
            Mock Invoke-Expression {
                $fromOutput = @(
                    @{
                        imageName = "foo"
                        stageName = "stage1"
                    }
                )
                $fromOutput | ConvertTo-Json
            } -ParameterFilter { $Command -eq "dfspy query from -f Dockerfile" } `
              -ModuleName common
    
            { & $targetScript -DockerfilePath 'Dockerfile' -BaseStageName stage2 } | Should -Throw "Could not find stage with name 'stage2'."
        }
    }
}
