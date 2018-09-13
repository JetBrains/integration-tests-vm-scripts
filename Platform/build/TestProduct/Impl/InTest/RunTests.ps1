Param
(
    [Parameter(Position=0)]$NUnitIncludeCategory = "", # Empty by default. Use "," separator to provide several categories
    [Parameter(Position=0)]$NUnitExcludeCategory = "", # Empty by default. Use "," separator to provide several categories
    [Parameter(Position=0, Mandatory=$true)]$fileToTest
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }

$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"

$NUnitIncludeCategory = $NUnitIncludeCategory -join ","
$NUnitExcludeCategory = $NUnitExcludeCategory -join ","

function RunIntegrationTests
{
    Write-Host -BackgroundColor Gray -ForegroundColor DarkBlue " + $fileToTest"

        $TempDir = [System.IO.Path]::GetTempPath()+ "\InTestNUnit"
    If (Test-Path $TempDir){
        Remove-Item $TempDir\* -recurse
    }
    Else{
        New-Item -ItemType directory -Path $TempDir
    }

    $nugetPath=[System.IO.Path]::GetTempPath()+"nuget.exe"
    Write-Host $nugetPath
    If (-not (Test-Path $nugetPath)){
        $webclient = New-Object System.Net.WebClient
        $webclient.DownloadFile("http://nuget.org/nuget.exe", $nugetPath);
    }

    $configPath = Join-Path $ProductHomeDir "NuGet.config"
    & $nugetPath install NUnit.ConsoleRunner -OutputDirectory $TempDir -ConfigFile $configPath -Version 3.8.0 |Out-Null
    & $nugetPath install NUnit.Extension.NUnitV2Driver -OutputDirectory $TempDir -ConfigFile $configPath -Version 3.7.0 |Out-Null
    & $nugetPath install NUnit.Extension.NUnitV2ResultWriter -OutputDirectory $TempDir -ConfigFile $configPath -Version 3.6.0 |Out-Null
    & $nugetPath install NUnit.Extension.TeamCityEventListener -OutputDirectory $TempDir -ConfigFile $configPath -Version 1.0.4 |Out-Null

    $tools = Join-Path $TempDir "NUnit.ConsoleRunner.3.8.0\tools"
    $tools1 = Join-Path $TempDir "NUnit.Extension.NUnitV2Driver.3.7.0\tools\*"
    $tools2 = Join-Path $TempDir "NUnit.Extension.NUnitV2ResultWriter.3.6.0\tools\*"
    $tools3 = Join-Path $TempDir "NUnit.Extension.TeamCityEventListener.1.0.4\tools\*"
    Copy-Item -Path $tools1 -Destination $tools -Recurse | Write-Host
    Copy-Item -Path $tools2 -Destination $tools -Recurse | Write-Host
    Copy-Item -Path $tools3 -Destination $tools -Recurse | Write-Host
    
    $nunitexe = Join-Path $TempDir "NUnit.ConsoleRunner.3.8.0\tools\nunit3-console.exe"

    # which NUnit to use
    Import-Module "$ProductHomeDir\Platform\build\TestProduct\Impl\NUnit.psm1"    
    [scriptblock]$RunNunit = New-NUnitRunner -nunitexe $nunitexe -NUnitIncludeCategory $NUnitIncludeCategory -NUnitExcludeCategory $NUnitExcludeCategory
    Write-Host "Running nunit: "$RunNunit

    ####################
    ## Test!
    try
    {
       & $RunNunit -Dll $fileToTest
    }
    catch
    {
       Write-Warning "NUnit process has failed with error $($_.ToString()), proceeding with other tests"
    }
    
    ############
}

Write-Host (RunIntegrationTests)