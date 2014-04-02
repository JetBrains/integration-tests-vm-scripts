param 
(
    [Parameter(Position=0, Mandatory=$true)]$ViServerAddress,
    [Parameter(Position=0, Mandatory=$true)]$ViServerLogin,
    [Parameter(Position=0, Mandatory=$true)]$ViServerPasword
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

function Init()
{
if ((Get-PSSnapin -Name vmware.VimAutomation.core -ErrorAction SilentlyContinue) -eq $null)
{
    Write-Host "loading VimAutomation modules loading......." -ForegroundColor     green
    Add-PSSnapin vmware.VimAutomation.core
}
Else {

    Write-Host " Vmware Automation Tools has been loaded already" -ForegroundColor Yellow
}
}

function Connect()
{
    $server = Connect-VIServer -Server $ViServerAddress -User $ViServerLogin -Password $ViServerPasword -Force:$true
}

Init | Out-Null
Connect | Out-Null