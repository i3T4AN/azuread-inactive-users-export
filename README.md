# Get-InactiveUsers.ps1

## Description
Queries Microsoft Graph with app-only credentials to find Entra ID (Azure AD) users inactive longer than a set number of days. Exports results to CSV.

## Arguments
- **-TenantId** *(string, required)*: Directory (tenant) ID or domain.  
- **-ClientId** *(string, required)*: App registration (client) ID.  
- **-Secret** *(string, required)*: App registration client secret.  
- **-Days** *(int, optional, default=90)*: Number of days of inactivity.  
- **-OutFile** *(string, optional)*: Path for CSV export. Auto-generated if not provided.  

## Usage
```powershell
.\Get-InactiveUsers.ps1 -TenantId "<tenant-id>" -ClientId "<app-id>" -Secret "<secret>" -Days 120 -OutFile "C:\Temp\InactiveUsers.csv"
# azuread-inactive-users-export
Export inactive Entra ID (Azure AD) users from Microsoft Graph using PowerShell.   Identifies accounts with no sign-ins in the last N days (default 90) and outputs results to CSV.   Useful for audits, cleanup, and security reviews.
