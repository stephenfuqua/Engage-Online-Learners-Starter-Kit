# SPDX-License-Identifier: Apache-2.0
# Licensed to the Ed-Fi Alliance under one or more agreements.
# The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
# See the LICENSE and NOTICES files in the project root for more information.
#Requires -version 5
$NuGetInstaller = "https://dist.nuget.org/win-x86-commandline/v5.3.1/nuget.exe"
function Install-NugetCli {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [string]
        $ToolsPath
    )

    if (-not $(Test-Path $ToolsPath)) {
        mkdir $ToolsPath | Out-Null
    }

    $NugetExe = "$ToolsPath/nuget.exe"

    if (-not $(Test-Path $NugetExe)) {
        Write-Output "Downloading nuget.exe official distribution from " $NuGetInstaller
        Invoke-RestMethod -Uri $NuGetInstaller -OutFile $NugetExe
    }
    else {
        $info = Get-Command $NugetExe
        Write-Output "Found nuget exe in: $toolsPath"

        if ("5.3.1.0" -ne $info.Version.ToString()) {
            Write-Output "Updating nuget.exe official distribution from " $NuGetInstaller
            Invoke-RestMethod -Uri $NuGetInstaller -OutFile $NugetExe
        }
    }

    return $NugetExe
}
function Install-EdFiPackage {
    param (
        [Parameter(Mandatory=$True)]
        [string]
        $packageName,
        [Parameter(Mandatory=$True)]
        [string]
        $version,
        $toolsPath = "C:\temp\tools",
        $downloadPath = "C:\temp\downloads",
        [Parameter(Mandatory=$True)]
        [string]
        $edfiSource
    )
    $nugetPackageVersionParam=@{
        PackageName="$($packageName)"
        PackageVersion="$($version)"
        ToolsPath="$toolsPath"
        edfiSource=$edfiSource
    }

    $packageVersion = Get-NuGetPackageVersion @nugetPackageVersionParam
    $downloadedPackagePath = Join-Path $downloadPath "$($packageName).$($packageVersion)"
    Write-Output "Package: $($packageName).$($packageVersion)"
    &"$toolsPath\nuget" install $packageName -source $edfiSource -Version $packageVersion -outputDirectory $downloadPath -ConfigFile "$PSScriptRoot\nuget.config" | Out-Host

    if ($LASTEXITCODE) {
        throw "Failed to install package $($packageName) $($packageVersion)"
    }
    return $downloadedPackagePath
}


function Get-NuGetPackageVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [string]
        $PackageName,
        [Parameter(Mandatory=$True)]
        [string]
        $PackageVersion,
        $ToolsPath = "C:\temp\tools",
        [Parameter(Mandatory=$True)]
        [string]
        $edfiSource
    )
    Write-Output "Looking latest patch of $PackageName version $PackageVersion"
    $NuGetExe ="$toolsPath\nuget"
    # If version is provided with just Major.Minor, then lookup all
    # available versions and find the latest patch for that release
    if ($PackageVersion -match "^\d\.\d$") {
        $params = @(
            "list",
            "-Source", $edfiSource,
            "-AllVersions",
            $PackageName
        )

        Write-Output $NugetExe @params
        $response = &$NuGetExe @params

        $response -Split [Environment]::NewLine | ForEach-Object {
            $v = ($_ -Split " ")[1]

            if ($v -match "$PackageVersion\.\d") {
                $PackageVersion = $v
            }
        }
    }
    return $PackageVersion
}
function Install-NuGetPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [string]
        $ToolsPath,

        [Parameter(Mandatory=$True)]
        [string]
        $PackageName,

        [Parameter(Mandatory=$True)]
        [string]
        $PackageVersion,
        [Parameter(Mandatory=$True)]
        [string]
        $edfiSource
    )

    $params = @{
        NuGetExe = "$toolsPath\nuget"
        EdFiFeed = $edfiSource
        PackageName = $PackageName
        PackageVersion = $PackageVersion
    }
    $PackageVersion = Get-NuGetPackageVersion @params

    $params = @(
        "install",
        "-Source", $edfiSource,
        "-OutputDirectory", $ToolsPath,
        "-Version", $PackageVersion,
        $PackageName
    )

    Write-Output "Installing package $PackageName version $PackageVersion"
    &$NugetExe @params | Out-Host

    Test-ExitCode
    return "$ToolsPath/$PackageName.$PackageVersion"
}

Export-ModuleMember *
