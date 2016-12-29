# TODO: TC start build when host has enough free memory. No immediate need for implementing this, since we can reduce agents quantity to meet worst scenario
# Requires PowerCLI installed
# https://my.vmware.com/web/vmware/details?productId=285&downloadGroup=VSP510-PCLI-510
#get-vmhost | get-member -MemberType property | format-wide

param 
(
    [Parameter(Position=0, Mandatory=$true)]$name,
    [Parameter(Position=0, Mandatory=$true)]$cloneName,
    [Parameter(Position=0, Mandatory=$true)]$cloneNamePattern,
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

    $sourceVM =  $vmHost | get-vm -Name $name
    $datastore = $sourceVM | get-datastore
    Write-Host TargetDataStore: $datastore, FreeSpaceGB: ([Math]::Round(($datastore.ExtensionData.Summary.FreeSpace)/1GB,0))Gb
    
    $sourceVMView = $sourceVM | Get-View
    $cloneFolder = $sourceVMView.Parent

    $cloneSpec = new-object Vmware.Vim.VirtualMachineCloneSpec
    $cloneSpec.powerOn = $FALSE
    $snapshot = (Get-Snapshot -VM $name -Name $snapshotName).ExtensionData.Snapshot
    $cloneSpec.Snapshot = $snapshot
 
    $cloneSpec.Location = new-object Vmware.Vim.VirtualMachineRelocateSpec
    
    $cloneSpec.Location.Pool = ($sourceVM | get-resourcepool | get-view).MoRef
    $cloneSpec.Location.Host = ($sourceVM | get-vmhost | get-view).MoRef 
    $cloneSpec.Location.Datastore = ($datastore | get-view).MoRef
    
    $cloneSpec.Location.DiskMoveType = [Vmware.Vim.VirtualMachineRelocateDiskMoveOptions]::createNewChildDiskBacking
 
    $t = $sourceVMView.CloneVM( $cloneFolder, $cloneName, $cloneSpec ) #  requires VCenter

    $targetVM =  $vmHost | get-vm -Name $cloneName
    $targetVM | Get-FloppyDrive | Remove-FloppyDrive -Confirm:$false
    Write-Host $sourceVM "CpuLimitMhz:" $sourceVM.VMResourceConfiguration.CpuLimitMhz
    if ($sourceVM.VMResourceConfiguration.CpuLimitMhz -gt 0) {
      Write-Host $targetVM "Update CpuLimitMhz"
      $targetVM | Get-VMResourceConfiguration | Set-VMResourceConfiguration -CPULimitMhz $sourceVM.VMResourceConfiguration.CpuLimitMhz | Write-Host
    }

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
			$ip = $ips | where {([IPAddress]$_).AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork} | where { -not ([string]$_).StartsWith("169") }
			if ($ip -notlike '')
				{return $ip}
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
          
    $ip = WaitGuest $vm 1000
    Write-Host "IP :" $ip
	    
    Return @{"Ip"=$ip;"CloneName"=$cloneName}
    DisconnectAll
}

function DisconnectAll()
{
    Disconnect-VIServer -Server * -Force -Confirm:$false
}

Run

