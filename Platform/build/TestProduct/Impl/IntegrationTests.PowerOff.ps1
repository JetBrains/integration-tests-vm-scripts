Param
(
    [Parameter(Position=0, Mandatory=$true)]$cloneNamePattern,
    [Parameter(Position=0, Mandatory=$true)][String[]]$ViServerData #"server_adress", "login", "pass"
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }
$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"

Try {
    & "$ProductHomeDir\Platform\build\TestProduct\Impl\InTest\StopDeleteVM.ps1" -cloneNamePattern $cloneNamePattern -ViServerData $ViServerData
}
Catch {
Write-Host $error[0]
}