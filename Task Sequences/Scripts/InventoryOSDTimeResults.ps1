<#
.SYNOPSIS
OSD Inventory Info Script - Records the Build times, stats, and status
.DESCRIPTION
Determines the elapsed time for each of the phases along with the build status and then writes that information to the registry
.CREATED BY
Mike Terrill

    21.07.10: Initial Release
    24.02.06: Removed the SMSTS_Build from the registry, changed OSD_Result to OSDFinalStatus, changed IPUBuild to OSDBuild
              Updated the logic to only write to the registry if both TS values exist
    24.05.21: Removed writing OSDFinalStatus Failure as this is now handled by the Module- OSD Post Action
    24.06.29: Added extra info (BIOSPackage, etc., lines 75-83) for OSD inventory and troubleshooting
    24.07.02: Added OSD Inventory for BITSACP stats and StifleR Info
    24.07.11: Added OSDStartTime and OSDFinishTime
    24.07.16: Added OSDUser, OSDJoinDomainOUName, OSDTimeZone, OSDMediaType, OSDLaunchMode, OSDWinSystemLocale
    25.02.03: Added OSDBUILDMEDIA, OSDUITime & modified OSDRunTime to subtract OSDUITime if OSDUITime exist

#>

function Set-RegistryValueIncrement {
    [cmdletbinding()]
    param (
        [string] $path,
        [string] $Name
    )

    try { [int]$Value = Get-ItemPropertyValue @PSBoundParameters -ErrorAction SilentlyContinue } catch {}
    Set-ItemProperty @PSBoundParameters -Value ($Value + 1).ToString() 
}

#Setup TS Environment
try
{
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
}
catch
{
	Write-Verbose "Not running in a task sequence."
}

Function Write-ElapsedTime {
    [cmdletbinding()]
    param (
        [string] $PhaseName,
        [string] $StartTime,
        [string] $FinishTime
    )

    If (($TSEnv.Value("$FinishTime")) -and ($TSEnv.Value("$StartTime"))) {
        $Difference = ([datetime]$TSEnv.Value("$FinishTime")) - ([datetime]$TSEnv.Value("$StartTime")) 
        $Difference = [math]::Round($Difference.TotalMinutes)
        if ( -not ( test-path $registryPath ) ) {new-item -ItemType directory -path $registryPath -Force -erroraction SilentlyContinue | out-null}
        New-ItemProperty -Path $registryPath -Name $PhaseName -Value $Difference -PropertyType DWord -Force
        }
}

if ($tsenv)
    {
    #RegistryPath is set in the Initializing Variables step of the Task Sequence
    $registryPath = "HKLM:\$($tsenv.Value("RegistryPath"))"

    #Write the elapsed time in minutes it takes to run a phase in the task sequence and write it to the registry
    
    If ($tsenv.Value("SMSTS_OSDUIStartTime") -and $tsenv.Value("SMSTS_OSDUIStartTime")) {
        Write-ElapsedTime -PhaseName "OSDUITime" -StartTime "SMSTS_OSDUIStartTime" -FinishTime "SMSTS_OSDUIFinishTime"
        
        #Get OSDRunTime
        $Difference = ([datetime]$TSEnv.Value("SMSTS_OSDFinishTime")) - ([datetime]$TSEnv.Value("SMSTS_OSDStartTime")) 
        $OSDRunTime = [math]::Round($Difference.TotalMinutes)
        #Get OSDUIRunTime to subtract from OSDRunTime
        $Difference = ([datetime]$TSEnv.Value("SMSTS_OSDUIStartTime")) - ([datetime]$TSEnv.Value("SMSTS_OSDUIStartTime")) 
        $OSDUIRunTime = [math]::Round($Difference.TotalMinutes)
        #Calulate Actual RunTime
        $ActualRunTime = $OSDRunTime - $OSDUIRunTime
        #Write Actual RunTime to Registry
        if ( -not ( test-path $registryPath ) ) {new-item -ItemType directory -path $registryPath -Force -erroraction SilentlyContinue | out-null}
        New-ItemProperty -Path $registryPath -Name 'OSDRunTime' -Value $ActualRunTime -PropertyType DWord -Force

    }
    else{
        Write-ElapsedTime -PhaseName "OSDRunTime" -StartTime "SMSTS_OSDStartTime" -FinishTime "SMSTS_OSDFinishTime"
    }
    
    Write-ElapsedTime -PhaseName "ApplyOSTime" -StartTime "SMSTS_ApplyOSStartTime" -FinishTime "SMSTS_ApplyOSFinishTime"
    Write-ElapsedTime -PhaseName "ApplyOfflineDriversTime" -StartTime "SMSTS_ApplyOfflineDriversStartTime" -FinishTime "SMSTS_ApplyOfflineDriversFinishTime"
    Write-ElapsedTime -PhaseName "ApplyOnlineDriversTime" -StartTime "SMSTS_ApplyOnlineDriversStartTime" -FinishTime "SMSTS_ApplyOnlineDriversFinishTime"
    Write-ElapsedTime -PhaseName "FlashBIOSTime" -StartTime "SMSTS_FlashBIOSStartTime" -FinishTime "SMSTS_FlashBIOSFinishTime"
    Write-ElapsedTime -PhaseName "ProvisionTPMTime" -StartTime "SMSTS_ProvisionTPMStartTime" -FinishTime "SMSTS_ProvisionTPMFinishTime"
    Write-ElapsedTime -PhaseName "BitLockerTime" -StartTime "SMSTS_BitLockerStartTime" -FinishTime "SMSTS_BitLockerFinishTime"
    Write-ElapsedTime -PhaseName "InstallAppsTime" -StartTime "SMSTS_InstallAppsStartTime" -FinishTime "SMSTS_InstallAppsFinishTime"
    Write-ElapsedTime -PhaseName "InstallSoftwareUpdatesTime" -StartTime "SMSTS_InstallSoftwareUpdatesStartTime" -FinishTime "SMSTS_InstallSoftwareUpdatesFinishTime"

    #Add Build Record Info so you know which Build of OS was deployed
    $UBR = (Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuildNumber)+'.'+(Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' UBR)
    New-ItemProperty -Path $registryPath -Name "OSDBuild" -Value $UBR -Force
    If ($tsenv.Value("OSDBuildMedia")) {New-ItemProperty -Path $registryPath -Name "OSDBuildMedia" -Value $tsenv.Value("OSDBuildMedia") -Force}

    #Add other OSD Data
    If ($tsenv.Value("BIOSPACKAGE")) {New-ItemProperty -Path $registryPath -Name "BIOSPackage" -Value $tsenv.Value("BIOSPACKAGE") -Force}
    If ($tsenv.Value("_SMSTSBootImageID")) {New-ItemProperty -Path $registryPath -Name "BootImageID" -Value $tsenv.Value("_SMSTSBootImageID") -Force}
    If ($tsenv.Value("DRIVERPACK")) {New-ItemProperty -Path $registryPath -Name "DriverPack" -Value $tsenv.Value("DRIVERPACK") -Force}
    If ($tsenv.Value("SMSTS_OSDStartTime")) {New-ItemProperty -Path $registryPath -Name "OSDStartTime" -Value $tsenv.Value("SMSTS_OSDStartTime") -Force}
    If ($tsenv.Value("SMSTS_OSDFinishTime")) {New-ItemProperty -Path $registryPath -Name "OSDFinishTime" -Value $tsenv.Value("SMSTS_OSDFinishTime") -Force}

    #Set OSDUser to iPXEUser if bare metal or get the logged on user if initiated from Software Center
    If ($tsenv.Value("OSDUser")) {New-ItemProperty -Path $registryPath -Name "OSDUser" -Value $tsenv.Value("OSDUser") -Force}
    If ($tsenv.Value("OSDJoinDomainOUName")) {New-ItemProperty -Path $registryPath -Name "OSDJoinDomainOUName" -Value $tsenv.Value("OSDJoinDomainOUName") -Force}
    If ($tsenv.Value("OSDTimeZone")) {New-ItemProperty -Path $registryPath -Name "OSDTimeZone" -Value $tsenv.Value("OSDTimeZone") -Force}
    If ($tsenv.Value("_SMSTSMediaType")) {New-ItemProperty -Path $registryPath -Name "OSDMediaType" -Value $tsenv.Value("_SMSTSMediaType") -Force}
    If ($tsenv.Value("_SMSTSLaunchMode")) {New-ItemProperty -Path $registryPath -Name "OSDLaunchMode" -Value $tsenv.Value("_SMSTSLaunchMode") -Force}
    If ($tsenv.Value("OSDWinSystemLocale")) {New-ItemProperty -Path $registryPath -Name "OSDWinSystemLocale" -Value $tsenv.Value("OSDWinSystemLocale") -Force}

    #JoinType is set by OSDUI or a Task Sequence variable
    If ($tsenv.Value("JoinType")) {New-ItemProperty -Path $registryPath -Name "JoinType" -Value $tsenv.Value("JoinType") -Force}
    If ($tsenv.Value("_SMSTSAdvertID")) {New-ItemProperty -Path $registryPath -Name "TSDeploymentID" -Value $tsenv.Value("_SMSTSAdvertID") -Force}
    If ($tsenv.Value("_SMSTSPackageName")) {New-ItemProperty -Path $registryPath -Name "TSName" -Value $tsenv.Value("_SMSTSPackageName") -Force}
    If ($tsenv.Value("_SMSTSPackageID")) {New-ItemProperty -Path $registryPath -Name "TSPackageID" -Value $tsenv.Value("_SMSTSPackageID") -Force}

    #Failure
    If ($tsenv.Value("AllStepsSucceded") -eq "False")
        {
        New-ItemProperty -Path $registryPath -Name "OSDFailedStepName" -Value $tsenv.Value("FailedStepName") -force
        New-ItemProperty -Path $registryPath -Name "OSDFailedStepReturnCode" -Value $tsenv.Value("FailedStepReturnCode") -force
        #OSDFinalStatus Failure is now handled by the Module- OSD Post Action
        }
    #Success
    Else
        {
        New-ItemProperty -Path $registryPath -Name "OSDFinalStatus" -Value "Success" -force
        }    
    

    #OSD Inventory for BITSACP and StifleR
    $2PReg = "HKLM:\SOFTWARE\2Pint Software"
 
    If (Test-Path "$2PReg\BITSTS") {
        Foreach ( $Property in 'BytesTotal','BytesFromPeers','BytesFromSource','BytesTotalTurbo' ) {
            $Sum = get-itemproperty "$2PReg\BITSTS\*\*" | measure-object -sum $Property | % sum
            #MB from peers/source/turbo/total
            Set-ItemProperty $registryPath -Name $Property.Replace("Bytes","MB") -Value (($Sum/1mb) -as [int32])
        }
    }
 
    If (Test-Path "$2PReg\StifleR") {
        $ids = (Get-ItemProperty "$2PReg\StifleR\Client\Locations\*").NetworkGroupID  -join ','
        #Populate StifleRInfo network ID for determining the StifleR network the device was built on
        Set-ItemProperty $registryPath -Name "StifleRInfo" -Value $ids
    }

}
