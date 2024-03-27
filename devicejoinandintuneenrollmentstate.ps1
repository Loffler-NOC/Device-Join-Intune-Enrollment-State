# Gets the full Directory Service Registration, device join status
$status= dsregcmd /status

# Create variables containing the lines under "Device state" 
$azureADJoined =""
$enterpriseJoined=""
$domainJoined=""
$deviceState=""
$TenantName=""
$TenantId=""
$MdmUrl=""
$stop=0
$stop2=0

foreach($line in $status){
    if ($line.Contains("AzureAdJoined")) {
        $azureADJoined = $line
        $stop++
    }
    if ($line.Contains("EnterpriseJoined")) {
        $enterpriseJoined = $line
        $stop++
    }
    if ($line.Contains("DomainJoined")) {
        $domainJoined = $line
        $stop++
    }
    # Stop the loop once all three values are found
    if ($stop -ge 3){break} 
}

# Error handling if the variables aren't populated
if ($stop -lt 3) {
    write-output "values not found"
    exit 404
}

# Logic for Device State based on results : https://learn.microsoft.com/en-us/entra/identity/devices/troubleshoot-device-dsregcmd#device-state
if ($azureADJoined.Contains("YES") -And $enterpriseJoined.Contains("NO") -And $domainJoined.Contains("NO")){
    $deviceState="Microsoft Entra Joined"
} elseif ($azureADJoined.Contains("NO") -And $enterpriseJoined.Contains("NO") -And $domainJoined.Contains("YES")) {
    $deviceState="Domain Joined"
} elseif ($azureADJoined.Contains("YES") -And $enterpriseJoined.Contains("NO") -And $domainJoined.Contains("YES")) {
    $deviceState="Microsoft Entra Hybrid Joined"
} elseif ($azureADJoined.Contains("NO") -And $enterpriseJoined.Contains("NO") -And $domainJoined.Contains("YES")) {
    $deviceState="On-Premises DRS Joined"
} elseif ($azureADJoined.Contains("NO") -And $enterpriseJoined.Contains("NO") -And $domainJoined.Contains("NO")) {
    $deviceState="No Domain join"
} else {
    $deviceState="Unexpected Result"
}

# Get Tenant info / Intune enrollment status, only if device is Microsoft Entra joined or Microsoft Entra hybrid joined https://learn.microsoft.com/en-us/entra/identity/devices/troubleshoot-device-dsregcmd#tenant-details
if ($azureADJoined.Contains("YES")) {
    foreach($line2 in $status){
        if ($line2.Contains("TenantName")) {
            $TenantName = $line2
            $stop2++
        }
        if ($line2.Contains("TenantId")) {
            $TenantId = $line2
            $stop2++
        }
        if ($line2.Contains("MdmUrl")) {
            $MdmUrl = $line2
            $stop2++
        }
        # Stop the loop once all three values are found
        if ($stop2 -ge 3){break}
    }

}

# Logic for Intune Registration status
if ($MdmUrl.Contains("https")){
    $intuneState="Intune Enrolled"
}else{
    $intuneState="No Intune Enrollment"
}

# Output just for StdOut 
Write-Output $azureADJoined
Write-Output $enterpriseJoined
Write-Output $domainJoined
Write-Output $deviceState

Write-Output $TenantName
Write-Output $TenantId
Write-Output $MdmUrl
Write-Output $intuneState

# Set Custom Field number to the custom UDF Field to be populated
$udfCustomField_State ="18"
$customField_State = "Custom"+$udfCustomField_State
$udfCustomField_Intune ="19"
$customField_Intune = "Custom"+$udfCustomField_Intune

# Set registry key for the Agent to set the UDF. This reg key will be deleted after uploaded to the platform https://rmm.datto.com/help/en/Content/3NEWUI/Devices/UserDefinedFields.htm?Highlight=user-defined%20fields
New-ItemProperty "HKLM:\SOFTWARE\CentraStage" -Name $customField_State -PropertyType string -value $deviceState -Force
New-ItemProperty "HKLM:\SOFTWARE\CentraStage" -Name $customField_Intune -PropertyType string -value $intuneState -Force
