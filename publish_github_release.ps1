param(
    [Parameter(Mandatory = $true)][string]$Tag,
    [string]$ReleaseName,
    [string]$TargetCommitish = "main",
    [string]$Repository = "qyhg110q/codexflow",
    [string]$AssetDirectory,
    [switch]$Draft,
    [switch]$PreRelease
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Get-GitHubToken {
    if ($env:GITHUB_TOKEN) {
        return $env:GITHUB_TOKEN
    }

    if ($env:GH_TOKEN) {
        return $env:GH_TOKEN
    }

    $input = "protocol=https`nhost=github.com`n`n"
    $credential = $input | git credential fill 2>$null
    if (-not $credential) {
        return $null
    }

    $passwordLine = $credential | Where-Object { $_ -like "password=*" } | Select-Object -First 1
    if ($passwordLine) {
        return $passwordLine.Substring("password=".Length)
    }

    return $null
}

function Invoke-GitHubApi {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Uri,
        [string]$Token,
        $Body,
        [string]$ContentType = "application/json"
    )

    $headers = @{
        Authorization = "Bearer $Token"
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    $params = @{
        Method = $Method
        Uri = $Uri
        Headers = $headers
    }

    if ($Body -ne $null) {
        $params.Body = $Body
        $params.ContentType = $ContentType
    }

    return Invoke-RestMethod @params
}

if (-not $AssetDirectory) {
    $AssetDirectory = Join-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "artifacts\release") $Tag
}

if (-not (Test-Path $AssetDirectory -PathType Container)) {
    throw "Asset directory not found: $AssetDirectory"
}

$token = Get-GitHubToken
if (-not $token) {
    throw "GitHub token not available. Set GITHUB_TOKEN or GH_TOKEN, or configure Git Credential Manager with GitHub credentials."
}

$notesPath = Join-Path $AssetDirectory "release-notes.md"
$notes = ""
if (Test-Path $notesPath) {
    $notes = [string](Get-Content -LiteralPath $notesPath -Raw)
}
$releaseName = if ($ReleaseName) { $ReleaseName } else { "CodexFlow $Tag" }

$createBody = @{
    tag_name = $Tag
    target_commitish = $TargetCommitish
    name = $releaseName
    body = $notes
    draft = [bool]$Draft
    prerelease = [bool]$PreRelease
} | ConvertTo-Json -Depth 5

$release = $null
try {
    $release = Invoke-GitHubApi -Method GET -Uri ("https://api.github.com/repos/{0}/releases/tags/{1}" -f $Repository, [Uri]::EscapeDataString($Tag)) -Token $token
} catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 404) {
        throw
    }
}

if ($release) {
    $updateBody = @{
        target_commitish = $TargetCommitish
        name = $releaseName
        body = $notes
        draft = [bool]$Draft
        prerelease = [bool]$PreRelease
    } | ConvertTo-Json -Depth 5
    $release = Invoke-GitHubApi -Method PATCH -Uri ("https://api.github.com/repos/{0}/releases/{1}" -f $Repository, $release.id) -Token $token -Body $updateBody
} else {
    $release = Invoke-GitHubApi -Method POST -Uri ("https://api.github.com/repos/{0}/releases" -f $Repository) -Token $token -Body $createBody
}

$assets = Get-ChildItem -Path $AssetDirectory -File | Where-Object {
    $_.Name -ne "release-notes.md"
}

$existingAssets = Invoke-GitHubApi -Method GET -Uri ("https://api.github.com/repos/{0}/releases/{1}/assets?per_page=100" -f $Repository, $release.id) -Token $token

foreach ($asset in $assets) {
    $existingAsset = $existingAssets | Where-Object { $_.name -eq $asset.Name } | Select-Object -First 1
    if ($existingAsset) {
        Invoke-GitHubApi -Method DELETE -Uri ("https://api.github.com/repos/{0}/releases/assets/{1}" -f $Repository, $existingAsset.id) -Token $token | Out-Null
    }

    $uploadUri = "https://uploads.github.com/repos/$Repository/releases/$($release.id)/assets?name=$([Uri]::EscapeDataString($asset.Name))"
    $headers = @{
        Authorization = "Bearer $token"
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    Invoke-RestMethod `
        -Method POST `
        -Uri $uploadUri `
        -Headers $headers `
        -InFile $asset.FullName `
        -ContentType "application/octet-stream" | Out-Null
}

Write-Host ("GitHub Release published: {0}" -f $release.html_url)
