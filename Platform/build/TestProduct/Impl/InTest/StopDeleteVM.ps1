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
    $_vmName = $vm.Name
    Write-Host 'Try to Remove-VM:' $_vmName

    while ($vm -ne $null)
    {
        Write-Host "Try to delete VM from disk"
        Try{ Remove-VM -VM $vm -DeletePermanently:$true -Confirm:$false} Catch{}
        sleep 5
        $vm = Get-Vm -Name $_vmName -ErrorAction SilentlyContinue
    }
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
        $machines | Stop-VM -Confirm:$false -RunAsync:$false
    }
    catch{
    Write-Error $_
    }
        
    # for safety reason check that we are really removing a clone not a reference VM
    #{ throw 'It is allowed to delete only machines, which contain word \"_clone_\" in its name.'}
    $cloneVms = @(Get-VM -Name "*_clone_*")
    foreach ($vm in $cloneVms)
    {       
        $index = $vm.Name.IndexOf("_")
        $time = $vm.Name.Substring($index+1)
        [int]$year = 0
        [int]$month = 0
        [int]$day = 0
        $year_string = ""
        $month_string = ""
        $day_string = ""
        Try
            {
                $year_string = $time.Substring(0,4);
                $month_string = $time.Substring(4,2);
                $day_string = $time.Substring(6,2);
            } Catch {}
        $res1 = [int32]::TryParse($year_string , [ref]$year )
        $res2 = [int32]::TryParse($month_string , [ref]$month )
        $res3 = [int32]::TryParse($day_string , [ref]$day )
            
        if (-not ($res1 -and $res2 -and $res3) -or ((Get-Date) - (Get-Date -Year $year -Month $month -Day $day)) -gt (New-TimeSpan -Days 1))
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

