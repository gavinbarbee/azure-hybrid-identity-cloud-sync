# Run on DC01 in an elevated PowerShell session (through Bastion).
# Prepares the data disk and promotes the server to the first domain
# controller of a new forest. The server reboots automatically at the end.

$ErrorActionPreference = 'Stop'

# 1. Initialize the empty data disk as F: for the AD database and SYSVOL
$raw = Get-Disk | Where-Object PartitionStyle -eq 'RAW'
if ($raw) {
    $raw | Initialize-Disk -PartitionStyle GPT -PassThru |
        New-Partition -DriveLetter F -UseMaximumSize |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel 'NTDS' -Confirm:$false
}

# 2. Install the AD DS role and management tools
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# 3. Promote to a new forest. The DSRM password is the offline recovery
#    password for the AD database. Store it in a password manager.
$dsrm = Read-Host 'DSRM (Directory Services Restore Mode) password' -AsSecureString

Install-ADDSForest `
    -DomainName 'corp.gavinbarbee.lab' `
    -DomainNetbiosName 'GAVINBARBEE' `
    -InstallDns `
    -DatabasePath 'F:\NTDS' `
    -LogPath 'F:\NTDS' `
    -SysvolPath 'F:\SYSVOL' `
    -SafeModeAdministratorPassword $dsrm `
    -Force
