# TODO: TC start build when host has enough free memory. No immediate need for implementing this, since we can reduce agents quantity to meet worst scenario
# Requires PowerCLI installed
# https://my.vmware.com/web/vmware/details?productId=285&downloadGroup=VSP510-PCLI-510
#get-vmhost | get-member -MemberType property | format-wide

param 
(
    [Parameter(Position=0, Mandatory=$true)]$name,
    [Parameter(Position=0, Mandatory=$true)]$cloneName,
    [Parameter(Position=0, Mandatory=$true)]$snapshotName,
    [Parameter(Position=0, Mandatory=$true)]$ViServerAddress,
    [Parameter(Position=0, Mandatory=$true)]$ViServerLogin,
    [Parameter(Position=0, Mandatory=$true)]$ViServerPasword
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function Get-ScriptDirectory { Split-Path $script:MyInvocation.MyCommand.Path }

function CheckFreeMem()
{
    $vmHost = get-vmhost
    $vmHost | format-table name, CpuUsageMhz, CpuTotalMhz, MemoryUsageGB, MemoryTotalGB -autosize

    $memUsage = $vmHost.MemoryUsageGB
    $totalMem = $vmHost.MemoryTotalGB
    $freeMem = ($totalMem - $memUsage)
    
    $sourceVM =  $vmHost | get-vm -Name $name
    $sourceVMView = $sourceVM | Get-View
    $freeMemAmountToStart = $sourceVMView.Config.Hardware.MemoryMB / 1000

    $freeMem = "{0:N1}" -f $freeMem
    Write-Host 'Starting: '$freeMem'Gb is free' machine requires: $freeMemAmountToStart Gb
}

function Clone()
{
    $vmHost = get-vmhost

    $datastore = Get-Datastore -VMHost $vmHost #-Name Datastore300
    Write-Host TargetDataStore: $datastore
    $sourceVM =  $vmHost | get-vm -Name $name
    
    # revert to snapshot is essentual for future linked clone.
    # but avoid reverting if someone is modifying the image and machine is powered
    $vm = get-vmguest -VM $name
    if($vm.State -eq 'Running'){
        throw "Someone is manually modifying VM image. Since we do not want to affect this manuall work - the build would be failed."
    }
    
    $snapshots = Get-Snapshot -VM $name -Name $snapshotName
    if ($snapshots.GetType().IsArray -and $snapshots.Count -gt 1 ) {
        throw "There are more than one snapshots with the same name $snapshotName on machine $name "
    }

    Set-VM -VM $name -Snapshot ($snapshots) -confirm:$FALSE | Out-Null

    $sourceVMView = $sourceVM | Get-View
    $cloneFolder = $sourceVMView.Parent

    $cloneSpec = new-object Vmware.Vim.VirtualMachineCloneSpec
    $cloneSpec.powerOn = $FALSE
    $cloneSpec.Snapshot = $sourceVMView.Snapshot.CurrentSnapshot
 
    $cloneSpec.Location = new-object Vmware.Vim.VirtualMachineRelocateSpec
    $cloneSpec.Location.DiskMoveType = [Vmware.Vim.VirtualMachineRelocateDiskMoveOptions]::createNewChildDiskBacking
 
    $t = $sourceVMView.CloneVM( $cloneFolder, $cloneName, $cloneSpec ) #  requires VCenter

    Write-Host 't='$t
    Write-Host 'cloneName'$cloneName
}

function WaitGuest([string]$vmName, [int]$timeout)
{
    $vm = Get-VM -Name $vmName
    Write-Host 'WaitGuest:'
    Write-Host $vm
    Write-Host $vm.PowerState
    $i=0
    $ips = $vm.Guest.ipaddress
    do {
        Write-Host $i
        sleep 10
        $vm = Get-VM -Name $vmName
        $winName = $VM.Guest.Hostname
        $ips = $vm.Guest.ipaddress
        Write-Host $ips $winName
        if ($ips -notlike '' -and $winName -notlike '')
        {
            foreach ($ip in $ips)
                {
                    if ( ($ip -As [IPAddress]) -As [Bool] )
                        {return [string]$ip}
                }
        }
        ; $i=$i+10}
    while ($i -le $timeout)
    throw "Machine have not started in $timeout seconds."
}

function Run()
{
    & (Join-Path (Get-ScriptDirectory) "ViServer.Connect.ps1") -ViServerAddress $ViServerAddress -ViServerLogin $ViServerLogin -ViServerPasword $ViServerPasword | Out-Null
    
    Clone
 
    # No need for snapshot operations when working with cloned machine
    # $vmHost = get-vmhost
    #$vm =  $vmHost | get-vm -Name 'XPVS9*'
    #$snapshot = Get-Snapshot -VM $vm -Name 'tools'
    #Set-VM -VM $vm -Snapshot $snapshot -Confirm:$false # Free license or ESXi version prohibits execution of the requested operation.
    $vm=Start-VM -Confirm:$false -VM $cloneName  # Free license or ESXi version prohibits execution of the requested operation.

    #-TimeoutSeconds 180 -HostUser "Administrator" -HostPassword "123"
    Write-Host 'started vm = ' $cloneName
    #Wait-Tools -VM $vm
          
    $ip = WaitGuest $vm 320
    Write-Host "IP :" $ip
	    
    Return @{"Ip"=$ip;"CloneName"=$cloneName}
    DisconnectAll
}

function DisconnectAll()
{
    Disconnect-VIServer -Server * -Force -Confirm:$false
}

Run

