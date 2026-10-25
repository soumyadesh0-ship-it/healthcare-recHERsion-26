param(
    [Parameter(Mandatory = $true)][string]$ApiBaseUrl,
    [string]$DeviceId = 'ZD2229TJMM',
    [string]$PublicConfigFile,
    [switch]$AllowLocalApi,
    [switch]$BuildOnly,
    [switch]$PrepareOnly,
    [switch]$DisableKotlinIncremental
)
$ErrorActionPreference = 'Stop'
$appDirectory = Split-Path $PSScriptRoot -Parent
$repository = Split-Path (Split-Path $appDirectory -Parent) -Parent
$buildDirectory = Join-Path $appDirectory 'build'
$configPath = Join-Path $buildDirectory 'local-model-defines.json'
$uri = [Uri]$ApiBaseUrl
$isLocal = $AllowLocalApi -and $uri.Scheme -eq 'http' -and
    $uri.Host -in @('localhost', '127.0.0.1', '10.0.2.2')
if (($uri.Scheme -ne 'https' -and -not $isLocal) -or
    $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
    throw 'Use an HTTPS base URL, or explicitly enable a loopback development URL with -AllowLocalApi.'
}
$settings = @{}
$environmentFile = Join-Path $repository '.env'
if ($PublicConfigFile -or -not (Test-Path -LiteralPath $environmentFile)) {
    # Merges can remove tracked .env files. Reuse only validated public settings,
    # never the full file or provider credentials from any local configuration.
    $publicSource = if ($PublicConfigFile) { $PublicConfigFile } else { $configPath }
    if (-not (Test-Path -LiteralPath $publicSource)) {
        throw 'Public Supabase configuration is missing. Configure root .env or pass -PublicConfigFile pointing to a local public JSON defines file.'
    }
    try { $publicConfig = Get-Content -LiteralPath $publicSource -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { throw 'The local public JSON configuration could not be read.' }
    foreach ($name in @('SUPABASE_URL', 'SUPABASE_ANON_KEY')) {
        $settings[$name] = ([string]$publicConfig.$name).Trim()
    }
} else {
    Get-Content -LiteralPath $environmentFile -Encoding UTF8 | ForEach-Object {
        if ($_ -match '^\s*(SUPABASE_URL|SUPABASE_ANON_KEY)\s*=\s*(.*?)\s*$') {
            $settings[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
        }
    }
}
if (-not $settings['SUPABASE_URL'] -or -not $settings['SUPABASE_ANON_KEY']) {
    throw 'Configure the existing Supabase project URL and public anon/publishable key in the root .env.'
}
$supabaseUri = $null
if (-not [Uri]::TryCreate($settings['SUPABASE_URL'], [UriKind]::Absolute, [ref]$supabaseUri) -or
    $supabaseUri.Scheme -ne 'https' -or -not $supabaseUri.Host -or
    $supabaseUri.UserInfo -or $supabaseUri.Query -or $supabaseUri.Fragment -or
    ($supabaseUri.AbsolutePath -and $supabaseUri.AbsolutePath -ne '/')) {
    throw 'SUPABASE_URL must be a valid HTTPS project origin without credentials, query or fragment.'
}
$publicKey = $settings['SUPABASE_ANON_KEY']
$isPublicKey = $publicKey.StartsWith('sb_publishable_') -and $publicKey.Length -gt 20
if (-not $isPublicKey -and -not $publicKey.StartsWith('sb_secret_')) {
    $parts = $publicKey.Split('.')
    if ($parts.Length -eq 3) {
        try {
            $payload = $parts[1].Replace('-', '+').Replace('_', '/')
            $payload = $payload.PadRight($payload.Length + ((4 - $payload.Length % 4) % 4), '=')
            $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
            $isPublicKey = $claims.role -eq 'anon'
        } catch { $isPublicKey = $false }
    }
}
if (-not $isPublicKey) { throw 'Only an anon/publishable key may be compiled into Flutter.' }
$settings['AURACARE_API_BASE_URL'] = $ApiBaseUrl
$settings['API_BASE_URL'] = $ApiBaseUrl
# This script never enables the unverified schema or uploads local/demo records.
$settings['HEALTH_PERSISTENCE_ENABLED'] = 'false'
$settings['AURACARE_ALLOW_LOCAL_API'] = $isLocal.ToString().ToLowerInvariant()
$settings['AURACARE_AUTH_REDIRECT_URL'] = 'auracare://auth-callback'
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
# Only public client configuration is serialized; never copy the entire .env.
$settings | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8
if ($PrepareOnly) {
    Write-Output 'Prepared build/local-model-defines.json with public client settings; cloud health persistence remains disabled.'
    return
}
Push-Location $appDirectory
try {
    $gradleArgs = @()
    if ($DisableKotlinIncremental) {
        $gradleArgs = @('--android-project-arg=kotlin.incremental=false',
            '--android-project-arg=kotlin.compiler.execution.strategy=in-process')
    }
    if ($BuildOnly) {
        & flutter build apk --debug "--dart-define-from-file=$configPath" @gradleArgs
    } else {
        & flutter run --debug -d $DeviceId "--dart-define-from-file=$configPath" @gradleArgs
    }
    if ($LASTEXITCODE -ne 0) { throw 'Flutter build/run failed.' }
} finally {
    Pop-Location
}
