param 
(
    [Parameter(Position=0, Mandatory=$true)]$VmName
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }
$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"
function Get-ScriptDirectory { Split-Path $script:MyInvocation.MyCommand.Path }

# Stub implementation
return New-Object PSObject -Property @{ ViServerData= @{ ViServerAddress="ViServerAddress"; ViServerLogin="ViServerLogin"; ViServerPasword="ViServerPasword" }; LoginInGuestLogin="LoginInGuestLogin"; LoginInGuestPassword="LoginInGuestPassword" }
