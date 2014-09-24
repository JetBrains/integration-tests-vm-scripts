Param
(
    [Parameter(Position=0)]$NUnitCpu = $null, # Inherit from current runtime by default
    [Parameter(Position=0)]$NUnitRuntime = $null, # Inherit from current runtime by default
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
    
    # which NUnit to use
    Import-Module "$ProductHomeDir\Platform\build\TestProduct\Impl\NUnit.psm1"
    [scriptblock]$RunNunit = New-NUnitRunner -NUnitCpu $NUnitCpu -NUnitRuntime $NUnitRuntime -NUnitIncludeCategory $NUnitIncludeCategory -NUnitExcludeCategory $NUnitExcludeCategory
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