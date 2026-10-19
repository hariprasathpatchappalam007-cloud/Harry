param(
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string]$ExpectedSHA256 = '07b8d2f330e83abecb0f11b254eafaba8266dab858ddc092ea28122651dfc13a'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not ('DfmReadOnlyCertificateSignature' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;
public static class DfmReadOnlyCertificateSignature
{
    [DllImport("crypt32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CryptVerifyCertificateSignatureEx(
        IntPtr provider, uint encoding, uint subjectType, IntPtr subject,
        uint issuerType, IntPtr issuer, uint flags, IntPtr extra);
    public static bool Verify(X509Certificate2 certificate)
    {
        return CryptVerifyCertificateSignatureEx(
            IntPtr.Zero, 65537, 2, certificate.Handle,
            2, certificate.Handle, 0, IntPtr.Zero);
    }
}
'@
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
"Windows account: $($identity.Name)"
"Running with administrator token: $($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
"Expected certificate SHA-256: $ExpectedSHA256"
'Read-only inspection: no imports, elevation, network requests or trust changes.'
''

$matches = 0
$sha = [Security.Cryptography.SHA256]::Create()
try {
    foreach ($scope in @('CurrentUser', 'LocalMachine')) {
        foreach ($name in @('Root', 'CA', 'My', 'TrustedPeople', 'AuthRoot')) {
            $store = New-Object Security.Cryptography.X509Certificates.X509Store -ArgumentList $name, $scope
            try {
                $flags = [Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly -bor
                    [Security.Cryptography.X509Certificates.OpenFlags]::OpenExistingOnly
                $store.Open($flags)
                foreach ($certificate in $store.Certificates) {
                    $hash = [BitConverter]::ToString($sha.ComputeHash($certificate.RawData)).Replace('-', '')
                    if ($hash -ine $ExpectedSHA256) { continue }
                    $matches++
                    $selfIssued = [Convert]::ToBase64String($certificate.SubjectName.RawData) -ceq
                        [Convert]::ToBase64String($certificate.IssuerName.RawData)
                    $signatureValid = [DfmReadOnlyCertificateSignature]::Verify($certificate)
                    $registryScope = if ($scope -eq 'CurrentUser') { 'HKEY_CURRENT_USER' } else { 'HKEY_LOCAL_MACHINE' }
                    $directPath = "Registry::$registryScope\Software\Microsoft\SystemCertificates\$name\Certificates\$($certificate.Thumbprint)"
                    $policyPath = "Registry::$registryScope\Software\Policies\Microsoft\SystemCertificates\$name\Certificates\$($certificate.Thumbprint)"
                    $now = [DateTime]::UtcNow
                    [pscustomobject][ordered]@{
                        StoreView = "Cert:\$scope\$name"
                        Subject = $certificate.Subject
                        Issuer = $certificate.Issuer
                        FriendlyName = $certificate.FriendlyName
                        ExactSHA256Match = $true
                        SHA256 = $hash.ToLowerInvariant()
                        SelfIssued = $selfIssued
                        SignatureValidUsingOwnPublicKey = $signatureValid
                        SelfSigned = ($selfIssued -and $signatureValid)
                        ValidFromUTC = $certificate.NotBefore.ToUniversalTime().ToString('o')
                        ExpiresUTC = $certificate.NotAfter.ToUniversalTime().ToString('o')
                        WorkstationClockUTC = $now.ToString('o')
                        WithinValidityPeriod = ($now -ge $certificate.NotBefore.ToUniversalTime() -and
                            $now -le $certificate.NotAfter.ToUniversalTime())
                        DirectRegistryRecordPresent = (Test-Path -LiteralPath $directPath -ErrorAction Stop)
                        DirectRegistryLocation = $directPath
                        GroupPolicyRegistryRecordPresent = (Test-Path -LiteralPath $policyPath -ErrorAction Stop)
                    } | Format-List | Out-String -Width 240
                }
            } catch {
                Write-Warning "Inspection of Cert:\$scope\$name failed: $($_.Exception.Message). That store's result is incomplete."
            } finally {
                $store.Close()
            }
        }
    }
} finally {
    $sha.Dispose()
    $identity.Dispose()
}

if ($matches -eq 0) {
    'No exact fingerprint match was found in the successfully inspected store views.'
    'This does not prove the certificate was never imported: it may have been removed, be in another account/store, or exist only as a browser exception.'
} else {
    "Matching store-view entries: $matches"
}
''
'INTERPRETATION'
'SelfSigned=True verifies the signature with the certificate own public key and confirms matching subject/issuer names.'
'CurrentUser is a store VIEW; Windows can also expose inherited machine certificates there.'
'A direct HKEY_CURRENT_USER record identifies storage in this user profile, not who imported it.'
'A Group Policy record is evidence of policy storage; its absence does not exclude other management tools or IT involvement.'
'Certificate stores do not reliably record the installer identity or installation time.'
'No live HTTPS connection, requested-hostname validation, import-permission test or browser-exception check was performed.'
'No private keys or certificate bytes were exported.'
