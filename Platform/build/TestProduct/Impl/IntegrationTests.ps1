Param
(
    [Parameter(Position=0)]$NUnitCpu = $null, # Inherit from current runtime by default
    [Parameter(Position=0)]$NUnitRuntime = $null, # Inherit from current runtime by default
    [Parameter(Position=0)]$ProductBinariesDir, 
    [Parameter(Position=0)]$ArtifactsDir,
    
    [Parameter(Position=0)]$ProductName = "Perseus",
    [Parameter(Position=0)]$CountOfMachinesToStart = 1,
    [Parameter(Position=0, Mandatory=$true)]$VmName,
    [Parameter(Position=0)]$NUnitIncludeCategory = "",
    [Parameter(Position=0)]$NUnitExcludeCategory = "",
    [Parameter(Position=0, Mandatory=$true)]$cloneNamePattern
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }
$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"

function Run
{
    $Env:InTestRunInVirtualEnvironment = "True"
    $Env:InTestRunInMainHive = "True"

    # Poweroff before starting new machines and tests ensures that machines started at previous build are removed
    & "$ProductHomeDir\Platform\build\TestProduct\Impl\IntegrationTests.PowerOff.ps1" -cloneNamePattern $cloneNamePattern -VmName $VmName

    Try {
        & "$ProductHomeDir\Platform\build\TestProduct\Impl\IntegrationTests.PowerOnRun.ps1" -ProductName $ProductName `
            -cloneNamePattern $cloneNamePattern -VmName $VmName -CountOfMachinesToStart $CountOfMachinesToStart -NUnitExcludeCategory $NUnitExcludeCategory -NUnitIncludeCategory $NUnitIncludeCategory `
            -ApplicationDescriptorAssembly "JetBrains.${ProductName}.${ProductName}Product"`
            -NUnitCpu $NUnitCpu -NUnitRuntime $NUnitRuntime -ProductBinariesDir $ProductBinariesDir -ArtifactsDir $ArtifactsDir
        
        & "$ProductHomeDir\Platform\build\TestProduct\Impl\IntegrationTests.CopyLogs.ps1" -cloneNamePattern $cloneNamePattern -VmName $VmName
    }
    Catch {throw}
    Finally {
        & "$ProductHomeDir\Platform\build\TestProduct\Impl\IntegrationTests.PowerOff.ps1" -cloneNamePattern $cloneNamePattern -VmName $VmName
    }
}

Run