<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }

$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"
$configPath = Join-Path $ProductHomeDir "NuGet.config"

# Creates an NUnit runner script which takes one or more DLLs as a parameter.
# Runs either locally or using TeamCity.
function New-NUnitRunner
{
    Param
    (
        $nunitexe,
        $NUnitIncludeCategory = "", # Empty by default. Use "," separator to provide several categories
        $NUnitExcludeCategory = "" # Empty by default. Use "," separator to provide several categories
    )
       
    # Load the helper module (incl. TeamCity props support)
    & "$ProductHomeDir/Platform/Tools/PowerShell/JetCmdlet/Load-JetCmdlet.ps1" | Write-Host
    
    New-NUnitRunner-TeamCity -nunitexe $nunitexe -NUnitIncludeCategory $NUnitIncludeCategory -NUnitExcludeCategory $NUnitExcludeCategory
}
Export-ModuleMember -Function New-NUnitRunner

function MakeWhereString([Parameter(Mandatory=$false)][string]$NUnitIncludeCategory, [Parameter(Mandatory=$false)][string]$NUnitExcludeCategory)
{
    if((-not $NUnitIncludeCategory) -and (-not $NUnitExcludeCategory))
    {
        return "";
    }

    $clauses = @()

    if($NUnitIncludeCategory)
    {
        $clauses += $NUnitIncludeCategory.Split(",") | %{ "(cat == '$_')" }
    }
    if($NUnitExcludeCategory)
    {
        $clauses += $NUnitExcludeCategory.Split(",") | %{ "(cat != '$_')" }
    }

    return "--where `"$($clauses -join " && ")`""
}

function New-NUnitRunner-TeamCity([Parameter(Mandatory=$true)]$nunitexe, [Parameter(Mandatory=$false)]$NUnitIncludeCategory, [Parameter(Mandatory=$false)]$NUnitExcludeCategory) {
    Write-Host "Using NUnit runner at $nunitexe, NUnitIncludeCategory: $NUnitIncludeCategory, NUnitExcludeCategory: $NUnitExcludeCategory"
    $where = MakeWhereString -NUnitIncludeCategory $NUnitIncludeCategory -NUnitExcludeCategory $NUnitExcludeCategory
    Write-Host "where: $where"

    $script =
    { 
        Param($Dll) 
        
        $nunitargs = 
        @(
            "--framework=v4.0",
            "--noresult",
            "--teamcity",
            $Dll
        )
        if ($where -ne "") {$nunitargs+=$where}

        Write-Host "Runner params: $nunitargs"
        & $nunitexe $nunitargs 2>&1 # redirect stderr to stdout, otherwise a build with muted tests is reported as failed because of the stdout text
    }
    return $script.GetNewClosure()
}