param 
(
    [Parameter(Position=0, Mandatory=$true)]$cloneNamePattern,
    [Parameter(Position=0, Mandatory=$true)][String[]]$ViServerData #"server_adress", "login", "pass"
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function Get-ScriptDirectory { Split-Path $script:MyInvocation.MyCommand.Path }
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }
$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"

function DeleteClone($vm)
{
    if ($vm.powerstate -eq ‘PoweredOn’) {
      $vm | Stop-VM -Confirm:$false -RunAsync:$false
    }

    $_vmName = $vm.Name
    Write-Host 'Try to Remove-VM:' $_vmName

    Write-Host "Delete VM from disk"
    Try { Remove-VM -VM $vm -DeleteFromDisk:$true -Confirm:$false -RunAsync:$false }
    Catch {Write-Host $error[0]}
}

function Run()
{
    $ViServerAddress = $ViServerData[0]
    $ViServerLogin = $ViServerData[1]
    $ViServerPasword = $ViServerData[2]
    & (Join-Path (Get-ScriptDirectory) "ViServer.Connect.ps1") -ViServerAddress $ViServerAddress -ViServerLogin $ViServerLogin -ViServerPasword $ViServerPasword | Out-Null

    #bulk poweroff
    try{
        $machines = Get-VM -Name $cloneNamePattern* | where {$_.Name -ne $cloneNamePattern} | Where-Object {$_.powerstate -eq ‘PoweredOn’}
        try{$machines | Get-VMQuestion | Set-VMQuestion -DefaultOption -Confirm:$false}catch{Write-Host $_}
        $machines | Stop-VM -Confirm:$false -RunAsync:$false
    }
    catch{
    Write-Error $_
    }
        
    # for safety reason check that we are really removing a clone not a reference VM
    #{ throw 'It is allowed to delete only machines, which contain word \"_clone_\" in its name.'}
    $cloneVms = @(Get-VM -Name "*_clone_*" )
    foreach ($vm in $cloneVms)
    {     
        $datetime = Get-Date
        $index = $vm.Name.IndexOf("_")
        $timeString = $vm.Name.Substring($index+1)
        $template = 'MMdd_HHmmss'
        Try
            {
                $timeinfo = $timeString.Substring(0,15);
                $datetime = [DateTime]::ParseExact($timeinfo, $template, $null) 
            } Catch { 
              Write-Host "Unable to parse datetime in the VM name. Deleting VM..."
              DeleteClone $vm }
            
        if ((Get-Date) - ($datetime) -gt (New-TimeSpan -Hours 23))
        {
           DeleteClone $vm
        }
    }
    DisconnectAll
}

function DisconnectAll()
{
    Disconnect-VIServer -Server * -Force -Confirm:$false
}

Run

