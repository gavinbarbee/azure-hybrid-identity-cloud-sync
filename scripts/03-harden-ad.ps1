# Run on DC01 as GAVINBARBEE\dcadmin after 02-build-ad-structure.ps1.
# Delegation, password policies, audit GPO, Protected Users, Recycle Bin,
# and the KDS root key that Cloud Sync's managed service account needs.

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
Import-Module GroupPolicy

$domain   = Get-ADDomain
$domainDN = $domain.DistinguishedName
$usersOU  = "OU=Users,OU=Corp,$domainDN"

# 1. Delegation of control: Helpdesk can reset passwords, force a change
#    at next sign-in, and unlock accounts, only for users in Corp\Users.
dsacls $usersOU /I:S /G "GAVINBARBEE\GG-Helpdesk:CA;Reset Password;user"
dsacls $usersOU /I:S /G "GAVINBARBEE\GG-Helpdesk:WP;pwdLastSet;user"
dsacls $usersOU /I:S /G "GAVINBARBEE\GG-Helpdesk:WP;lockoutTime;user"

# 2. Domain password and lockout policy. For domain accounts this only
#    takes effect at the domain level (Default Domain Policy).
Set-ADDefaultDomainPasswordPolicy -Identity $domain.DNSRoot `
    -MinPasswordLength 14 `
    -ComplexityEnabled $true `
    -PasswordHistoryCount 24 `
    -LockoutThreshold 10 `
    -LockoutDuration '00:15:00' `
    -LockoutObservationWindow '00:15:00'

# 3. Fine-grained password policy: stricter rules for Tier 0 admins
if (-not (Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'FGPP-Tier0-Admins'")) {
    New-ADFineGrainedPasswordPolicy -Name 'FGPP-Tier0-Admins' `
        -Precedence 10 `
        -MinPasswordLength 20 `
        -ComplexityEnabled $true `
        -PasswordHistoryCount 24 `
        -MinPasswordAge '1.00:00:00' `
        -MaxPasswordAge '90.00:00:00' `
        -LockoutThreshold 5 `
        -LockoutDuration '00:30:00' `
        -LockoutObservationWindow '00:30:00' `
        -ReversibleEncryptionEnabled $false
}
Add-ADFineGrainedPasswordPolicySubject -Identity 'FGPP-Tier0-Admins' -Subjects 'GG-Tier0-Admins'

# 4. Audit GPO linked to the Domain Controllers OU. The audit
#    subcategories are configured in the Group Policy editor (README step 6).
if (-not (Get-GPO -Name 'GPO-DC-Audit-Policy' -ErrorAction SilentlyContinue)) {
    New-GPO -Name 'GPO-DC-Audit-Policy' -Comment 'Advanced audit policy for domain controllers' |
        New-GPLink -Target "OU=Domain Controllers,$domainDN"
}

# 5. Protected Users: no NTLM, no weak Kerberos encryption, no cached
#    credentials. Only the Tier 0 admin account, never the Bastion sign-in account.
Add-ADGroupMember 'Protected Users' -Members 'adm-gavin'

# 6. AD Recycle Bin (one-way change for the forest)
$rb = Get-ADOptionalFeature -Filter "Name -eq 'Recycle Bin Feature'"
if (-not $rb.EnabledScopes) {
    Enable-ADOptionalFeature 'Recycle Bin Feature' `
        -Scope ForestOrConfigurationSet -Target $domain.DNSRoot -Confirm:$false
}

# 7. KDS root key, required before any group managed service account
#    (gMSA) can be created. The Cloud Sync agent installer creates one.
if (-not (Get-KdsRootKey)) {
    Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10))
}

# Results
Get-ADDefaultDomainPasswordPolicy | Select-Object MinPasswordLength, LockoutThreshold, LockoutDuration
Get-ADUserResultantPasswordPolicy -Identity 'adm-gavin' | Select-Object Name, MinPasswordLength, LockoutThreshold
Get-ADGroupMember 'Protected Users' | Select-Object Name
(Get-ADOptionalFeature -Filter "Name -eq 'Recycle Bin Feature'").EnabledScopes
