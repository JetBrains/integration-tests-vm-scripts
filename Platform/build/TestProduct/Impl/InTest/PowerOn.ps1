Param
(
    [Parameter(Position=0, Mandatory=$true)]$cloneNamePattern,
    [Parameter(Position=0, Mandatory=$true)]$VmName,
    [Parameter(Position=0, Mandatory=$true)][String[]]$ViServerData,
    [Parameter(Position=0)]$CountOfMachinesToStart=1,
    [Parameter(Position=0, Mandatory=$false)] $vmStartupTimeout=320
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }
$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"

function PowerOn
{
    $cloneNames = @()
    for ($i=0; $i -lt $CountOfMachinesToStart; $i++) {
        $cloneNames += $cloneNamePattern+'_'+[System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")+'_'+$VmName+'_'+'clone'+'_'+$i
    }

    $jobs = @()
    $jobsA = @()
    foreach ($cloneName in $cloneNames) {
   
        & "$ProductHomeDir\Platform\build\TestProduct\Impl\InTest\VirtualEnvironment.ps1" -VmName $VmName -cloneName $cloneName -ViServerAddress $ViServerData[0] -ViServerLogin $ViServerData[1] -ViServerPasword $ViServerData[2] -vmStartupTimeout $vmStartupTimeout
        
         Write-Host "started on " + $VmName
    }

    return  @()
}

$ret = PowerOn
return $ret