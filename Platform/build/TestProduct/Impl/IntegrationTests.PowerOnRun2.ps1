Param
(
    [Parameter(Position=0, Mandatory=$true)][System.Collections.ArrayList]$FilesToTest, #InTestVSVersionMajor, ExeToRunForTests, fileToTest
    [Parameter(Position=0, Mandatory=$true)]$cloneNamePattern,
    [Parameter(Position=0, Mandatory=$true)]$VmName,
    [Parameter(Position=0)]$CountOfMachinesToStart = 1,
    [Parameter(Position=0)]$NUnitIncludeCategory = "", # Empty by default. Use "," separator to provide several categories
    [Parameter(Position=0)]$NUnitExcludeCategory = "", # Empty by default. Use "," separator to provide several categories
        
    [Parameter(Position=0, Mandatory=$true)][String[]]$ViServerData,
    [Parameter(Position=0, Mandatory=$true)][String[]]$GuestCredentials,
    [Parameter(Position=0)]$ArtifactsDir
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }
$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"

function MakeScriptBlock($machine, $fileToTest, $nunitexe)
{
    Write-Host Running tests for: $fileToTest in $machine.cloneName with $nunitexe
    $env:InTestIpAddress = $machine.data.IpAddress
    $params = @{fileToTest = """$fileToTest""";nunitexe = """$nunitexe"""}
    if ($NUnitIncludeCategory -ne "")  { $params.Add("NUnitIncludeCategory", $NUnitIncludeCategory) }
    if ($NUnitExcludeCategory -ne "")  { $params.Add("NUnitExcludeCategory", $NUnitExcludeCategory) }
    [string] $scriptPath ="$ProductHomeDir\Platform\build\TestProduct\Impl\InTest\RunTests.ps1"
    $block = [scriptblock]::Create("&'$scriptpath' $(&{$args} @params)")
    Write-Host $block
    return $block
}

function RunInOneMachine($machine, $fileToTest, $nunitexe)
{ 
    "Set InTestVSVersionMajor: " + $fileToTest[1] |Write-Host
    $Env:InTestVSVersionMajor = $fileToTest[1]
    "Set ExeToRunForTest: " + $fileToTest[2] |Write-Host
    $Env:ExeToRunForTest = $fileToTest[2]

    $sb = MakeScriptBlock $machine $fileToTest[0] $nunitexe
    $job = Start-Job -scriptblock $sb
    return @{job=$job; machine =$machine}
}

function TestsInMachines($machines, $nunitexe)
{
  $Env:InTestRunInVirtualEnvironment = "True"
  $Env:InTestRunInMainHive = "True"  

  #Load helper module before starting parallel run 
  & "$ProductHomeDir/Platform/Tools/PowerShell/JetCmdlet/Load-JetCmdlet.ps1" | Write-Host

  # parallel run
  if (@($machines).Count -gt 1) {
    Write-Host "Running tests in multiple machines. $nunitexe"
    $i=0
    $jobsM=@{}
    foreach ($machine in $machines){
        $pair = RunInOneMachine $machine @($FilesToTest)[$i] $nunitexe
        $jobsM.Add($pair.job, $pair.machine)
        Start-Sleep -s 10 # if JetCmdLet is not compiled both threads will try to compile it
        $i+=1
    }
    $jobsM |Out-String |Write-Host

    while ($i -le @($FilesToTest).Count)
    {
        $arrayJobsInProgress = @(Get-Job | Where-Object { $_.JobStateInfo.State -eq 'Running' })
        Write-Host 'Tests running in:'@($arrayJobsInProgress).Count'jobs'
        $arrayFinishedJobs = @()
        foreach ($job in @($jobsM.Keys)) {
            if (-not @($arrayJobsInProgress).Contains($job)) {
                $arrayFinishedJobs+=$job
                Write-Host 'finished job at machine:' $jobsM.Get_Item($job)
            }
        }

        foreach($job in $arrayFinishedJobs){
            $srtJ = $job | Out-String | Write-Host
            $machine = $jobsM.Get_Item($job)
            $jobsM.Remove($job)

            if ($job.State -eq 'Failed') {
              Write-Host ($job.ChildJobs[0].JobStateInfo.Reason.Message) -ForegroundColor Red
            } else {
              Write-Host (Receive-Job $job) -ForegroundColor Green 
            }

            if ($i -lt @($FilesToTest).Count){
                $pair = RunInOneMachine $machine $FilesToTest[$i] $nunitexe
                $jobsM.Add($pair.job, $pair.machine)
                $i+=1
            }
            else # copy logs and poweroff if there are no more tests for the machine.
            {
                $i+=1
                & "$ProductHomeDir\Platform\build\TestProduct\Impl\IntegrationTests.CopyLogs.ps1" -cloneNamePattern $machine.cloneName -ViServerData $ViServerData -GuestCredentials $GuestCredentials -ArtifactsDir $ArtifactsDir
                & "$ProductHomeDir\Platform\build\TestProduct\Impl\InTest\StopDeleteVM.ps1" -cloneNamePattern $machine.cloneName -ViServerData $ViServerData
            }
        }
        Sleep(10)
    }

    Get-Job | Wait-Job | Receive-Job |Write-Host
  }
  else # without parallel run
  {
    Write-Host "Running tests in single machine."
    foreach ($fileToTest in $FilesToTest){
        "Set InTestVSVersionMajor: " + $fileToTest[1] |Write-Host
        $Env:InTestVSVersionMajor = $fileToTest[1]
        "Set ExeToRunForTest: " + $fileToTest[2] |Write-Host
        $Env:ExeToRunForTest = $fileToTest[2]
        
        $sb = MakeScriptBlock @($machines)[0] $fileToTest[0] $nunitexe
        Invoke-Command -ScriptBlock $sb
    }
  }
}

function FreeSpace() {
    & "$ProductHomeDir\Platform\build\TestProduct\Impl\InTest\ViServer.Connect.ps1" -ViServerAddress $ViServerData[0] -ViServerLogin $ViServerData[1] -ViServerPasword $ViServerData[2] | Out-Null

    $vmHost = get-vmhost

    $name = $VmName.split("+")[0]

    $sourceVM =  $vmHost | get-vm -Name $name
    $datastore = $sourceVM | get-datastore

    $freespaceGb = ([Math]::Round(($datastore.ExtensionData.Summary.FreeSpace)/1GB,0))
    while ($freespaceGb -le 150) {
      $freespaceGb = ([Math]::Round(($datastore.ExtensionData.Summary.FreeSpace)/1GB,0))
      Write-Host TargetDataStore: $datastore, FreeSpaceGB: $freespaceGb Gb
      $cloneVmToDelete = @($datastore | Get-VM -Name  "*_clone_*" | where {$_.PowerState -eq "PoweredOff"} | Select -First 1)
      if ($cloneVmToDelete.Count -eq 0) {break}
      Write-Host Delete vm $cloneVmToDelete.Name
      try{Remove-VM -VM $cloneVmToDelete -DeleteFromDisk:$true -Confirm:$false -RunAsync:$false}
      Catch {Write-Host $error[0]}
    }
}

function PrepareNUnit() {
    $TempDir = [System.IO.Path]::GetTempPath()+'InTestNUnit'
    If (Test-Path $TempDir){
        Remove-Item $TempDir\* -recurse |Out-Null
    }
    Else{
        New-Item -ItemType directory -Path $TempDir |Out-Null
    }

    $nugetPath=[System.IO.Path]::GetTempPath()+"nuget.exe"
    Write-Host $nugetPath
    If (-not (Test-Path $nugetPath)){
        $webclient = New-Object System.Net.WebClient
        $webclient.DownloadFile("http://nuget.org/nuget.exe", $nugetPath);
    }

    $configPath = Join-Path $ProductHomeDir "NuGet.config"
    & $nugetPath install NUnit.ConsoleRunner -OutputDirectory $TempDir -ConfigFile $configPath -Version 3.8.0 |Out-Null
    & $nugetPath install NUnit.Extension.NUnitV2Driver -OutputDirectory $TempDir -ConfigFile $configPath -Version 3.7.0 |Out-Null
    & $nugetPath install NUnit.Extension.NUnitV2ResultWriter -OutputDirectory $TempDir -ConfigFile $configPath -Version 3.6.0 |Out-Null
    & $nugetPath install NUnit.Extension.TeamCityEventListener -OutputDirectory $TempDir -ConfigFile $configPath -Version 1.0.4 |Out-Null

    $tools = Join-Path $TempDir "NUnit.ConsoleRunner.3.8.0\tools"
    $tools1 = Join-Path $TempDir "NUnit.Extension.NUnitV2Driver.3.7.0\tools\*"
    $tools2 = Join-Path $TempDir "NUnit.Extension.NUnitV2ResultWriter.3.6.0\tools\*"
    $tools3 = Join-Path $TempDir "NUnit.Extension.TeamCityEventListener.1.0.4\tools\*"
    Copy-Item -Path $tools1 -Destination $tools -Recurse | Write-Host
    Copy-Item -Path $tools2 -Destination $tools -Recurse | Write-Host
    Copy-Item -Path $tools3 -Destination $tools -Recurse | Write-Host
    
    $nunitexe = Join-Path $TempDir "NUnit.ConsoleRunner.3.8.0\tools\nunit3-console.exe"
    return $nunitexe
}

function Main()
{
    $env:InTestUserName = $GuestCredentials[0]
    $env:InTestPassword = $GuestCredentials[1]

    $countToStart = [math]::min( $CountOfMachinesToStart, @($FilesToTest).Count )
    $machines = @( & "$ProductHomeDir\Platform\build\TestProduct\Impl\InTest\PowerOn.ps1" -cloneNamePattern $cloneNamePattern -VmName $VmName -ViServerData $ViServerData -CountOfMachinesToStart $countToStart)
    foreach ($machine in $machines) {
        $machine.data | Out-String | Write-Host
    }

    FreeSpace | Write-Host

    $nunitexe = PrepareNUnit

    TestsInMachines $machines $nunitexe |Write-Host
    return $machines
}

Main