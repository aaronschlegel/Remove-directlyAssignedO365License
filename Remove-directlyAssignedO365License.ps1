<#
.SYNOPSIS
Remove-directlyAssignedO365License.ps1 - Remove directly assigned Office 365 license from users.
.DESCRIPTION
Remove licenses which were not assigned by group based licensing from o365 users.

Script takes users to process as input, then will pull the licenses which exist in the tenant 
then prompt for input of which SKU and which entitlement are to be removed.
.EXAMPLE
Remove-directlyAssignedO365License -userUPNFilePath "C:\usersToRemoveUPNs.txt"
Remove license from all users in txt file

Remove-directlyAssignedO365License -processAllUsers
Process all users in O365 tenant and remove the license if found.
.PARAMETER userUPNFilePath
Path to a txt file containing UserPrincipalNames of users which to remove license from.
.PARAMETER user
User pincipalname of a single user to remove license from.
.PARAMETER processAllUsers
Process all users in o365 tenant
.OUTPUTS
Array
#Returns array of all users successfully processed.
.NOTES
Version:          1.0
Author:           Aaron Schlegel
Creation Date:    10-31-2022
History:
    10-31-2022, 1.0, Remove-directlyAssignedO365License.ps1, Initial Creation
#>


function Remove-O365DirectAssignedLicense {
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'FileInput')]
        [ValidateScript({
                if ( -Not ($_ | Test-Path) ) {
                    throw "File or folder does not exist"
                }
                return $true
            })]
        [System.IO.FileInfo]$userUPNFilePath,
        [Parameter(ParameterSetName = 'SingleUser')]
        [ValidateNotNullOrEmpty()]
        [string]$user,
        [Parameter(ParameterSetName = 'AllUsers')]
        [switch]$processAllUsers
    )

    #Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Users.Actions
    #Requires -Version 5.1


    Import-Module Microsoft.Graph.Users
    Import-module Microsoft.Graph.Identity.DirectoryManagement
    Import-Module Microsoft.Graph.Users.Actions


    try {

        Connect-Graph -Scopes User.ReadWrite.All, Organization.Read.All

    }
    catch {

        write-host -ForegroundColor Red "Error connecting to Graph $_"
    }

    $allSkus = Get-MgSubscribedSku -all | select -exp skupartnumber
    $allUsers = $Null 

    $processedUsers = @()

    if ($user) {
        $allusers = $user 
    }
    elseif ($userUPNFilePath) {

        $allUsers = get-content $userUPNFilePath
    }
    elseif ($processAllUsers.IsPresent) {

        $allUsers = (get-MgUser -all -Property "userprincipalname").userprincipalname


    }
    else {

        write-host -ForegroundColor Red "Please specifiy users for input"
        sleep 5 
        exit
    }

    for ($i = 0; $i -lt $allSkus.count - 1 ; ++$i ) {

        write-host "$($i + 1). $($allSkus[$i])"

    }

    $skuToremoveidx = read-host "Select License to Remove Plan from"

    $skuToremove = $allSkus[$skuToremoveidx - 1]


    $planSkus = (Get-MgSubscribedSku -all |  ? { $_.skupartnumber -eq $skuToremove } | select -exp serviceplans).serviceplanName

    for ($i = 0; $i -lt $planSkus.count - 1; ++$i ) {

        write-host "$($i + 1). $($planSkus[$i])"

    }

    $servicePlanToRemoveidx = read-host "Select Service Plan to remove"

    $servicePlanToRemove = $planSkus[$servicePlanToRemoveidx - 1]

    write-host -ForegroundColor Magenta "Found $($allUsers.count) users to remove $servicePlanToRemove from $skuToremove"
    $cont = Read-Host "Continue(y/n)?"

    if ($cont -ne "y") {

        exit;
    }




    foreach ($o365User in $allUsers) {
        ## Get the services that have already been disabled for the user.
        $userLicense = $Null 

        $userLicense = Get-MgUserLicenseDetail -UserId "$o365User" | ? { $_.skupartnumber -eq $skuToremove }



        $userDisabledPlans = $userLicense.ServicePlans | ? { $_.ProvisioningStatus -eq "Disabled" } | Select -ExpandProperty ServicePlanId
        if ($userLicense.Id.count -gt 0) {


            write-host -ForegroundColor Green "$o365User has $userDisabledPlans disabled"


            ## Get the new service plans that are going to be disabled
            $skuInfo = Get-MgSubscribedSku -All | Where SkuPartNumber -eq $skuToremove

            $newDisabledPlans = $Null 

            $newDisabledPlans = $skuInfo.ServicePlans | ? { $_.ServicePlanName -in ($servicePlanToRemove) } | Select -ExpandProperty ServicePlanId

            if ($null -ne $newDisabledPlans) {

                ## Merge the new plans that are to be disabled with the user's current state of disabled plans
                $disabledPlans = ($userDisabledPlans + $newDisabledPlans) | Select -Unique
                write-host -ForegroundColor Yellow "Disabling $newDisabledPlans"
                $addLicenses = @(
                    @{
                        SkuId         = $skuInfo.SkuId
                        DisabledPlans = $disabledPlans
                    }
 
                )
                write-host -ForegroundColor Cyan "Setting disabled Plans $($addLicenses.disabledPlans)"
                ## Update user's license
                try {
                    Set-MgUserLicense -UserId $o365User -AddLicenses $addLicenses -RemoveLicenses @()

                    $processedUsers += $o365User
                }
                catch {

                    write-host -ForegroundColor Red "Error removing license for $o365User $_"
                }

            }
            else {
            
                write-host -ForegroundColor Cyan "$o365 user does not have entitilement $servicePlanToRemove enabled"
            }

        }
        else {
            write-host -ForegroundColor Red "$o365User has no licenses"

        }

    }
    return $processedUsers

}