param(
    [Parameter(Mandatory = $true)][string]$ApiBaseUrl,
    [string]$DeviceId = 'ZD2229TJMM',
    [switch]$AllowLocalApi,
    [switch]$BuildOnly,
    [switch]$DisableKotlinIncremental
)
$ErrorActionPreference = 'Stop'
$appDirectory = Split-Path $PSScriptRoot -Parent
$repository = Split-Path (Split-Path $appDirectory -Parent) -Parent
$uri = [Uri]$ApiBaseUrl
$isLocal = $AllowLocalApi -and $uri.Scheme -eq 'http' -and
    $uri.Host -in @('localhost', '127.0.0.1', '10.0.2.2')
if (($uri.Scheme -ne 'https' -and -not $isLocal) -or
    $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
    throw 'Use an HTTPS base URL, or explicitly enable a loopback development URL with -AllowLocalApi.'
}
$settings = @{}
Get-Content -LiteralPath (Join-Path $repository '.env') | ForEach-Object {
    if ($_ -match '^\s*(SUPABASE_URL|SUPABASE_ANON_KEY)\s*=\s*(.*?)\s*$') {
        $settings[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
    }
}
if (-not $settings['SUPABASE_URL'] -or -not $settings['SUPABASE_ANON_KEY']) {
    throw 'Configure the existing Supabase project URL and public anon/publishable key in the root .env.'
}
$publicKey = $settings['SUPABASE_ANON_KEY']
$isPublicKey = $publicKey.StartsWith('sb_publishable_')
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
$settings['AURACARE_ALLOW_LOCAL_API'] = $isLocal.ToString().ToLowerInvariant()
$settings['AURACARE_AUTH_REDIRECT_URL'] = 'auracare://auth-callback'
$buildDirectory = Join-Path $appDirectory 'build'
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
$configPath = Join-Path $buildDirectory 'local-model-defines.json'
# Only public client configuration is serialized; never copy the entire .env.
$settings | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8
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
