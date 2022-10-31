function Remove-O365DirectAssignedLicense {
    param(
        [string]$userUPNFilePath,
        [string]$user,
        [switch]$processAllUsers
    )

    #Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Users.Actions
    #Requires -Version 5.1


    Import-Module Microsoft.Graph.Users
    Import-module Microsoft.Graph.Identity.DirectoryManagement
    Import-Module Microsoft.Graph.Users.Actions



    Connect-Graph -Scopes User.ReadWrite.All, Organization.Read.All

    $allSkus = Get-MgSubscribedSku -all | select -exp skupartnumber
    $allUsers = $Null 


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



        $userDisabledPlans = $userLicense.ServicePlans | ?{ $_.ProvisioningStatus -eq "Disabled" } | Select -ExpandProperty ServicePlanId
        if ($userLicense.Id.count -gt 0) {


            write-host -ForegroundColor Green "$o365User has $userDisabledPlans disabled"


            ## Get the new service plans that are going to be disabled
            $skuInfo = Get-MgSubscribedSku -All | Where SkuPartNumber -eq $skuToremove

            $newDisabledPlans = $Null 

            $newDisabledPlans = $skuInfo.ServicePlans | ?{ $_.ServicePlanName -in ($servicePlanToRemove) } | Select -ExpandProperty ServicePlanId

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
                Set-MgUserLicense -UserId $o365User -AddLicenses $addLicenses -RemoveLicenses @()

            }
            else {
            
                write-host -ForegroundColor Cyan "$o365 user does not have entitilement $servicePlanToRemove enabled"
            }

        }
        else {
            write-host -ForegroundColor Red "$o365User has no licenses"

        }

    }

}