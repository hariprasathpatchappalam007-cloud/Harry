param(
    [Parameter(Mandatory = $true)]
    [string]$CertificatePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security

$file = Get-Item -LiteralPath $CertificatePath
if ($file.PSIsContainer -or $file.Length -gt 65536) {
    throw 'Select a single public certificate file no larger than 64 KiB.'
}
$bytes = [IO.File]::ReadAllBytes($file.FullName)
$text = [Text.Encoding]::ASCII.GetString($bytes)
if ($text.Contains('PRIVATE KEY')) { throw 'Private-key files are not accepted. Use a public CER, CRT or PEM file.' }
if ($text.Contains('-----BEGIN CERTIFICATE-----')) {
    $match = [regex]::Match($text, '\A\s*-----BEGIN CERTIFICATE-----\s*([A-Za-z0-9+/=\s]+)-----END CERTIFICATE-----\s*\z')
    if (!$match.Success) { throw 'Select a single public certificate, not a bundle.' }
    $bytes = [Convert]::FromBase64String($match.Groups[1].Value)
}
if ([Security.Cryptography.X509Certificates.X509Certificate2]::GetCertContentType($bytes) -ne
    [Security.Cryptography.X509Certificates.X509ContentType]::Cert) {
    throw 'PFX/P12 files and bundles are not accepted. Use a public CER, CRT or PEM file.'
}

$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList (,$bytes)
$chain = New-Object Security.Cryptography.X509Certificates.X509Chain
$sha256 = [Security.Cryptography.SHA256]::Create()
try {
    if ($certificate.HasPrivateKey) { throw 'Private keys are not accepted.' }
    $san = @($certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.17' } | ForEach-Object { $_.Format($true).Trim() })
    $eku = @($certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' } | ForEach-Object { $_.Format($true).Trim() })
    $chain.ChainPolicy.RevocationMode = [Security.Cryptography.X509Certificates.X509RevocationMode]::Online
    $chain.ChainPolicy.UrlRetrievalTimeout = [TimeSpan]::FromSeconds(10)
    $trusted = $chain.Build($certificate)
    $now = [DateTime]::UtcNow
    $status = @($chain.ChainStatus | ForEach-Object { "$($_.Status): $($_.StatusInformation.Trim())" })

    [pscustomobject][ordered]@{
        Subject = $certificate.Subject
        Issuer = $certificate.Issuer
        ValidFromUTC = $certificate.NotBefore.ToUniversalTime().ToString('o')
        ExpiresUTC = $certificate.NotAfter.ToUniversalTime().ToString('o')
        WorkstationClockUTC = $now.ToString('o')
        WithinValidityPeriod = ($now -ge $certificate.NotBefore.ToUniversalTime() -and $now -le $certificate.NotAfter.ToUniversalTime())
        SubjectAlternativeNames = $(if ($san.Count) { $san -join '; ' } else { 'No SAN extension present.' })
        EnhancedKeyUsage = $(if ($eku.Count) { $eku -join '; ' } else { 'No EKU extension present.' })
        SHA256Fingerprint = [BitConverter]::ToString($sha256.ComputeHash($certificate.RawData)).Replace('-', ':')
        SHA1ThumbprintForIISLookup = $certificate.Thumbprint
        ContainsPrivateKey = $certificate.HasPrivateKey
        WindowsChainTrusted = $trusted
        ChainStatus = $(if ($status.Count) { $status -join '; ' } else { 'No chain errors reported.' })
        TrustTestScope = 'This Windows account and computer, at the clock time shown. Online revocation checking is enabled. This test does not check a live HTTPS endpoint or compare a requested hostname.'
    } | Format-List | Out-String -Width 240

    'CHAIN ELEMENTS (public identity metadata only):'
    foreach ($element in $chain.ChainElements) {
        "Subject: $($element.Certificate.Subject)"
        "Issuer: $($element.Certificate.Issuer)"
        "Expires UTC: $($element.Certificate.NotAfter.ToUniversalTime().ToString('o'))"
        ''
    }
    'No certificates were imported. No trust stores, permissions or TLS settings were changed.'
    'This report does not include certificate bytes, public-key bytes or private keys. Review identity metadata before sharing.'
}
finally {
    $sha256.Dispose()
    $chain.Dispose()
    $certificate.Reset()
}
