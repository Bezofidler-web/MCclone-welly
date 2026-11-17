# A per-Windows-user identity survives game updates and graphics-profile changes.
# DPAPI keeps a copied profile file from being usable as another Windows user.
function Get-LanProfileKey([string]$Directory) {
    Add-Type -AssemblyName System.Security
    [void][IO.Directory]::CreateDirectory($Directory)
    $path = Join-Path $Directory 'lan-identity.bin'
    $scope = [Security.Cryptography.DataProtectionScope]::CurrentUser
    if (![IO.File]::Exists($path)) {
        $random = [Security.Cryptography.RandomNumberGenerator]::Create()
        $bytes = [byte[]]::new(32)
        try { $random.GetBytes($bytes) } finally { $random.Dispose() }
        $ciphertext = [Security.Cryptography.ProtectedData]::Protect($bytes, $null, $scope)
        $temp = Join-Path $Directory ([Guid]::NewGuid().ToString('N') + '.tmp')
        try {
            [IO.File]::WriteAllBytes($temp, $ciphertext)
            try { [IO.File]::Move($temp, $path) }
            catch [IO.IOException] { if (![IO.File]::Exists($path)) { throw } }
        } finally { [IO.File]::Delete($temp) }
    }
    $key = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($path), $null, $scope)
    if ($key.Length -ne 32) { throw 'The saved LAN identity could not be read for this Windows user.' }
    return [BitConverter]::ToString($key).Replace('-', '').ToLowerInvariant()
}

function Get-LanInterfaces([string]$InterfaceAddress) {
    if ($InterfaceAddress) {
        $address = [Net.IPAddress]::Parse($InterfaceAddress)
        if ([Net.IPAddress]::IsLoopback($address)) {
            return [pscustomobject]@{ Address = $address; Mask = [Net.IPAddress]::Parse('255.0.0.0') }
        }
    }
    foreach ($adapter in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        if ($adapter.OperationalStatus -ne 'Up' -or !$adapter.SupportsMulticast -or
            $adapter.NetworkInterfaceType -eq 'Loopback') { continue }
        foreach ($ip in $adapter.GetIPProperties().UnicastAddresses) {
            if ($ip.Address.AddressFamily -eq 'InterNetwork' -and $ip.IPv4Mask -and
                !$ip.IPv4Mask.Equals([Net.IPAddress]::Any) -and (!$InterfaceAddress -or $ip.Address.Equals($address))) {
                [pscustomobject]@{ Address = $ip.Address; Mask = $ip.IPv4Mask }
            }
        }
    }
}
