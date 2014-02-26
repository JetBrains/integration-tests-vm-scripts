<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }

$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"

# Creates an NUnit runner script which takes one or more DLLs as a parameter.
# Runs either locally or using TeamCity.
function New-NUnitRunner
{
    Param
    (
        $NUnitCpu = $null, # Inherit from current runtime by default
        $NUnitRuntime = $null, # Inherit from current runtime by default
        $NUnitIncludeCategory = "", # Empty by default. Use "," separator to provide several categories
        $NUnitExcludeCategory = "" # Empty by default. Use "," separator to provide several categories
    )

    # Fallback values for NUnit params (inheriting from the current runtime)
    if(!$NUnitCpu) 
    { $NUnitCpu = if([System.Environment]::Is64BitProcess) { "x64" } else { "x86" } }
    if(!$NUnitRuntime) 
    { $NUnitRuntime = "v$([System.Environment]::Version.ToString(2))" }

    # Validate NUnit params
    if(($NUnitCpu -ne "x86") -and ($NUnitCpu -ne "x64")) { throw "Unexpected NUnit CPU." }
    if(($NUnitRuntime -ne "v2.0") -and ($NUnitRuntime -ne "v4.0")) { throw "Unexpected NUnit Runtime." }
   
    # Load the helper module (incl. TeamCity props support)
    & "$ProductHomeDir/Platform/Tools/PowerShell/JetCmdlet/Load-JetCmdlet.ps1"
    
    # Choose implementation
    $tcprops = New-TeamCityProperties
    if($tcprops.IsRunningInTeamCity)
    {
        New-NUnitRunner-TeamCity -NUnitCpu $NUnitCpu -NUnitRuntime $NUnitRuntime -NUnitIncludeCategory $NUnitIncludeCategory -NUnitExcludeCategory $NUnitExcludeCategory -tcprops $tcprops
    }
    else
    {
        New-NUnitRunner-Local -NUnitCpu $NUnitCpu -NUnitRuntime $NUnitRuntime -NUnitIncludeCategory $NUnitIncludeCategory -NUnitExcludeCategory $NUnitExcludeCategory
    }

}
Export-ModuleMember -Function New-NUnitRunner

#not in TeamCity -- use local copy
function New-NUnitRunner-Local([Parameter(Mandatory=$true)]$NUnitCpu, [Parameter(Mandatory=$true)]$NUnitRuntime, [Parameter(Mandatory=$false)]$NUnitIncludeCategory, [Parameter(Mandatory=$false)]$NUnitExcludeCategory)
{
    $filename = if($NUnitCpu -eq 'x86') {"nunit-console-x86.exe"} else {"nunit-console.exe"}
    $nunitexe = Join-Path $ProductHomeDir "Platform/Tools/NUnit/$filename"
    Write-Host "Using local NUnit runner at $nunitexe"

    $script =
    { 
        Param($Dll) 
        
        $nunitargs = 
        @(
            "/framework=$NUnitRuntime",
            "/apartment=MTA",
            "/noresult", # Don't want the XML file to appear
            $Dll
        )
        if ($NUnitIncludeCategory -ne "") {$nunitargs+="/include:$NUnitIncludeCategory"}
        if ($NUnitExcludeCategory -ne "") {$nunitargs+="/exclude:$NUnitExcludeCategory"}
            
        Write-Host "Runner params: $nunitargs"
        & $nunitexe $nunitargs
    }
    return $script.GetNewClosure()
}

function New-NUnitRunner-TeamCity([Parameter(Mandatory=$true)]$NUnitCpu, [Parameter(Mandatory=$true)]$NUnitRuntime, [Parameter(Mandatory=$true)]$tcprops, [Parameter(Mandatory=$false)]$NUnitIncludeCategory, [Parameter(Mandatory=$false)]$NUnitExcludeCategory)
{
    # under TeamCity -- use its runner
    # Find .exe from properties
    $nunitexe = $tcprops.GetSystemProperty("teamcity.dotnet.nunitlauncher")
    Write-Host "Using TeamCity NUnit runner at $nunitexe"

    # Choose the NUnit version to use
    $nunitfilter = "NUnit-*" #"NUnit-*-resharper" # NOTE: if you'd like to take the freshest nunit (non-R#-patched), change the ilike parameter arg to just "NUnit-*"
    $nunitver = $nunitexe | Split-Path -Parent | Join-Path -ChildPath "Test" | Get-ChildItem | where Name -ilike $nunitfilter | sort Name | select -Last 1 | foreach Name
    Write-Host "Using newest matching NUnit Version String $nunitver"

    $script =
    { 
        Param($Dll) 
        
        $nunitargs = 
        @(
            $NUnitRuntime,
            $NUnitCpu,
            $nunitver, # "NUnit-Auto" does not work because it tries to inspect the DLLs and fails with that
            $Dll
        )
        if ($NUnitIncludeCategory -ne "") {$nunitargs+="/category-include:$NUnitIncludeCategory"}
        if ($NUnitExcludeCategory -ne "") {$nunitargs+="/category-exclude:$NUnitExcludeCategory"}

        Write-Host "Runner params: $nunitargs"
        & $nunitexe $nunitargs 2>&1 # redirect stderr to stdout, otherwise a build with muted tests is reported as failed because of the stdout text
    }
    return $script.GetNewClosure()
}