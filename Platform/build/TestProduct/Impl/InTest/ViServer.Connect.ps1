param 
(
    [Parameter(Position=0, Mandatory=$true)]$ViServerAddress,
    [Parameter(Position=0, Mandatory=$true)]$ViServerLogin,
    [Parameter(Position=0, Mandatory=$true)]$ViServerPasword
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

function Init()
{
Get-Module -ListAvailable vmware.VimAutomation.core | Import-Module
}

function Connect()
{
    $server = Connect-VIServer -Server $ViServerAddress -User $ViServerLogin -Password $ViServerPasword -Force:$true
}

Init | Out-Null
Connect | Out-Null