#========================================================================
# Date              : 2/16/2014 4:49 PM
# Author            : Jeff Pollock
# 
# Description       : Assists in identifying driver INF files for import
#                     into Configuration Manager 2007 & 2012. It does this
#                     by searching a given computer for all PNP devices
#                     and then searching a given directory for the related
#                     INF files. 
#========================================================================
Param (
    [parameter(Mandatory=$true,ValueFromPipeline=$True)]
    [string]$SearchDir,  #Directory to search

    [parameter(ValueFromPipeline=$True)]
    [string]$Computer = ".",  #Computer to search

    [parameter(ValueFromPipeline=$True)]
    [switch]$UnknownOnly  #Determines whether to return all devices or just unknown

)

#----------------------------------------------
#region Functions
#----------------------------------------------
Function Get-PNPDevices {
    [cmdletbinding()]
    Param (
        [bool]$UnknownOnly  #-determines whether to return all devices or just unknown      
    )

    #--Query Win32_PNPEntity for devices
    If (!$UnknownOnly) {
        $Devices = Get-WmiObject -ComputerName $Computer Win32_PNPEntity | Select Name, DeviceID
    } Else {
        $Devices = Get-WmiObject -ComputerName $Computer Win32_PNPEntity | Where-Object{$_.ConfigManagerErrorCode -ne 0} | Select Name, DeviceID
    }

    #--Return device objects
    ForEach ($Device in $Devices) {
        $DeviceObj = New-Object -Type PSObject
        $DeviceObj | Add-Member -MemberType NoteProperty -Force -Name DeviceName -Value $Device.Name
        $DeviceObj | Add-Member -MemberType NoteProperty -Force -Name DeviceID -Value $Device.DeviceID
        $DeviceObj        
    }
}

Function Search-DeviceINF {
    [cmdletbinding()]
	Param(
	    [parameter(Mandatory=$true,ValueFromPipeline=$True)]
	    [string]$Directory,  #Directory to search

        [parameter(Mandatory=$true,ValueFromPipeline=$True)]
	    [object]$Device  #Device object
	)
    
    #--Create array to hold returned file names
    $FileArray = @()
    
    #--Assign the deviceid to the pattern for evaluation
    $Pattern = $Device.DeviceID
    
    #--Evaluate $Pattern for occurance of "&DEV" or "DLL"
    If ($Pattern.Contains("&DEV")) {        
        #--Extract the regex matching substring and assign to $Pattern
        $Pattern -match 'DEV_\w+[^&]' | out-null
        $PatternModified = $True
    } ElseIf ($Pattern.Contains("DLL")) {
        #--Extract the regex matching substring and assign to $Pattern
        $Pattern -match 'DLL\w+[^\\]' | out-null
        $PatternModified = $True
    }

    #--Search directory for INF files with the occurance of $Pattern
    If ($PatternModified) {
        #--Set new regex pattern
        $Pattern = $matches[0]
        #--Find files that contain the extracted pattern
        $Result = Get-ChildItem $Directory -include *.inf -recurse | select-string -pattern $Pattern | Select-Object -Unique Path
    }

    #--Output results
    If($Result) {
        #--Add returned files to the FileArray
        $Result | ForEach-Object {$FileArray += $_.Path}

        #Create object and output
        $DeviceObj = New-Object -Type PSObject
        $DeviceObj | Add-Member -MemberType NoteProperty -Force -Name DeviceName -Value $Device.DeviceName
        $DeviceObj | Add-Member -MemberType NoteProperty -Force -Name SearchPattern -Value $Pattern
        $DeviceObj | Add-Member -MemberType NoteProperty -Force -Name FileArray -Value $FileArray
        $DeviceObj | format-list
    } 
}
#endregion Application Functions

#----------------------------------------------
# region Script
#----------------------------------------------
#--Set Unknown switch
If ($UnknownOnly) {
    [bool]$Unknown = $True
} Else {
    [bool]$Unknown = $False
}

#--Perform query
Get-PNPDevices $Unknown | ForEach-Object {  
   Search-DeviceINF $SearchDir $_ 
}
#endregion Script