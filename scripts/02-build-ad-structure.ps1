# Run on DC01 after promotion, signed in as GAVINBARBEE\dcadmin.
# Builds the OU structure, tiered accounts, and groups.

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

# Internet name resolution: the DC's DNS server forwards to Azure DNS
Set-DnsServerForwarder -IPAddress 168.63.129.16

$domainDN = (Get-ADDomain).DistinguishedName
$upnSuffix = 'corp.gavinbarbee.lab'

function New-OUIfMissing($Name, $Path) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path -SearchScope OneLevel)) {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
    }
}

# OU structure
New-OUIfMissing 'Corp'            $domainDN
New-OUIfMissing 'Users'           "OU=Corp,$domainDN"
New-OUIfMissing 'Groups'          "OU=Corp,$domainDN"
New-OUIfMissing 'Tier0'           $domainDN
New-OUIfMissing 'Admins'          "OU=Tier0,$domainDN"
New-OUIfMissing 'ServiceAccounts' $domainDN

$usersOU   = "OU=Users,OU=Corp,$domainDN"
$groupsOU  = "OU=Groups,OU=Corp,$domainDN"
$tier0OU   = "OU=Admins,OU=Tier0,$domainDN"
$serviceOU = "OU=ServiceAccounts,$domainDN"

# One lab password for every account created here (16+ characters)
$pw = Read-Host 'Password for the lab accounts (16+ characters)' -AsSecureString

function New-UserIfMissing($Sam, $Given, $Surname, $Path, $Department, $Description) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$Sam'")) {
        New-ADUser -SamAccountName $Sam `
            -UserPrincipalName "$Sam@$upnSuffix" `
            -Name "$Given $Surname" -GivenName $Given -Surname $Surname `
            -DisplayName "$Given $Surname" `
            -Department $Department -Description $Description `
            -Path $Path -AccountPassword $pw -Enabled $true
    }
}

# Employees (these sync to Entra ID)
New-UserIfMissing 'jlee'   'Jordan' 'Lee'   $usersOU 'Engineering' 'Propulsion engineer'
New-UserIfMissing 'sortiz' 'Sam'    'Ortiz' $usersOU 'Finance'     'Financial analyst'
New-UserIfMissing 'tkim'   'Taylor' 'Kim'   $usersOU 'IT'          'Helpdesk technician'

# Tier 0 admin account, separate from any daily-use account (never syncs)
New-UserIfMissing 'adm-gavin' 'Gavin' 'Barbee (Admin)' $tier0OU 'IT' 'Tier 0 domain admin account'

# Service account (never syncs)
New-UserIfMissing 'svc-backup' 'Backup' 'Service' $serviceOU 'IT' 'Backup service account'

function New-GroupIfMissing($Name, $Path, $Description) {
    if (-not (Get-ADGroup -Filter "Name -eq '$Name'")) {
        New-ADGroup -Name $Name -GroupScope Global -GroupCategory Security `
            -Path $Path -Description $Description
    }
}

New-GroupIfMissing 'GG-Engineering'  $groupsOU 'Engineering department'
New-GroupIfMissing 'GG-Finance'      $groupsOU 'Finance department'
New-GroupIfMissing 'GG-Helpdesk'     $groupsOU 'Helpdesk: delegated password resets for Corp users'
New-GroupIfMissing 'GG-Tier0-Admins' $tier0OU  'Tier 0 admins: fine-grained password policy target'

Add-ADGroupMember 'GG-Engineering'  -Members 'jlee'
Add-ADGroupMember 'GG-Finance'      -Members 'sortiz'
Add-ADGroupMember 'GG-Helpdesk'     -Members 'tkim'
Add-ADGroupMember 'GG-Tier0-Admins' -Members 'adm-gavin'
Add-ADGroupMember 'Domain Admins'   -Members 'adm-gavin'

Get-ADUser -Filter * -SearchBase "OU=Corp,$domainDN" | Select-Object Name, SamAccountName, UserPrincipalName
Get-ADUser -Filter * -SearchBase "OU=Tier0,$domainDN" | Select-Object Name, SamAccountName
Get-ADUser -Filter * -SearchBase $serviceOU | Select-Object Name, SamAccountName
