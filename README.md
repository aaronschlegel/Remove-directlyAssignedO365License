# Remove-directlyAssignedO365License
# Introduction 
Removes directly assigned licenses from users in Office 365. Useful for the case of converting to group based licensing. 

The script will pull all of the SKU's, then will list the entitlements for the selected SKU.

Once selected the script will pause for reviewing before starting to process on the selected users. 

# Getting Started
    If module needs installed run PowerShell as admin:
    
    Install-Module Microsoft.Graph.Users
    Install-Module Microsoft.Graph.Identity.DirectoryManagement
    Install-Module Microsoft.Graph.Users.Actions
