# Loads the JetCmdlet module with our cmdlets
# TODO: bootstrap by compiling the module on-demand

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$DllRelpath = "bin/Debug/JetCmdlet.dll"

# Rootdir of the cmdlet project — one with the current script
function GetCmdletRootDir() { Split-Path $MyInvocation.ScriptName -Parent }

function IsModuleLoaded()
{
    Get-Module -Name JetCmdlet
}

function DoLoadModule($CmdletRootDir)
{
    Write-Host "Loading JetCmdlet module"
    Join-Path $CmdletRootDir $DllRelpath | Import-Module -Force
}

# Emulates a bit of the MSBuild inputs/outputs tracking magic to avoid spawning MSBuild.exe on every module load — instead, quickly checks if the output DLL is up-to-date with all the folder's sources.
function IsDllUpToDate($CmdletRootDir)
{
    # Collect the most recent date of all the source files
    $inputs = ($CmdletRootDir  + "/*") | Get-ChildItem -Recurse -Include ("*.cs", "*.csproj") | sort LastWriteTimeUtc | select -Last 1
    if(-not $inputs)
    { throw "The source files of the cmdlet could not be found." }
    $lastwrite = $inputs.LastWriteTimeUtc

    # Output exists?
    [System.IO.FileInfo]$dllfile = Join-Path $CmdletRootDir $DllRelpath
    if(-not (Test-Path $dllfile -PathType Leaf)) # does not exist, definitely build
    { 
        Write-Host "The JetCmdlet module DLL is not found, a build is required."
        return $false 
    } 

    # Compare time
    $isDirty = $lastwrite -gt $dllfile.LastWriteTimeUtc

    # Log
    if($isDirty)
    { 
        Write-Host "The JetCmdlet module DLL is out of date, a build is required." 
        return $false
    }

    $true
}

#Invokes a build to compile a new copy of the CMD
function CompileNewDll($CmdletRootDir)
{
    $dllfile = Join-Path $CmdletRootDir $DllRelpath

    # make sure the old item is not in the way
    DeleteAsideSimple $dllfile
    DeleteAsideSimple ([System.IO.Path]::ChangeExtension($dllfile, ".pdb"))
    DeleteAsideSimple ([System.IO.Path]::ChangeExtension($dllfile, ".xml"))

    ###############
    # Spawn MSBuild
    $dirNetfx = $([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory())
    $fileMsbuild = Join-Path $dirNetfx "msbuild.exe"
    $csproj = ($CmdletRootDir | Get-ChildItem -Filter "*.csproj").FullName

    $cmdargs = ("/t:build", "/v:m", "/nologo", $csproj)
    & $fileMsbuild $cmdargs
    if($LASTEXITCODE) { throw "MSBuild failed to build the tool (exit code $LASTEXITCODE)." }
}

function DeleteAsideSimple([Parameter(Mandatory=$true)]$file)
{
    Remove-Item $file -ErrorAction Ignore -Force #simple remove
    if(Test-Path $file) #still there? move away!
    {
        $aside = Join-Path (Split-Path $file -Parent) ([guid]::NewGuid().ToString("B").ToUpperInvariant() + ".tmp.user")
        Move-Item -Path $file -Destination $aside -Force -ErrorAction Stop
    }
}

$CmdletRootDir = GetCmdletRootDir

# Skip if module already loaded
if(IsModuleLoaded $CmdletRootDir) { return }

# Check if we have to bootstrap-build it
if(-not (IsDllUpToDate $CmdletRootDir)) { CompileNewDll $CmdletRootDir }

# Load
DoLoadModule ($CmdletRootDir)