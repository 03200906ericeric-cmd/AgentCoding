# PowerShell Script to Upload GitHub Repositories to Supabase
$ErrorActionPreference = "Stop"

# 1. Read .env file
$envPath = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envPath)) {
    Write-Error "Error: .env file not found at $envPath. Please copy .env.example to .env and configure it."
    exit 1
}

Write-Host "Reading .env file..."
$env = @{}
Get-Content $envPath | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
    $parts = $_ -split '=', 2
    $key = $parts[0].Trim()
    $val = $parts[1].Trim()
    $env[$key] = $val
}

$supabaseUrl = $env["SUPABASE_URL"]
$supabaseKey = $env["SUPABASE_SERVICE_ROLE_KEY"]
if ([string]::IsNullOrEmpty($supabaseKey)) {
    $supabaseKey = $env["SUPABASE_ANON_KEY"]
}

if ([string]::IsNullOrEmpty($supabaseUrl) -or [string]::IsNullOrEmpty($supabaseKey) -or $supabaseUrl -like "*your-project-id*") {
    Write-Error "Error: Supabase credentials are not configured in .env file."
    exit 1
}

# Ensure trailing slash is removed from URL, then append PostgREST endpoint
$supabaseUrl = $supabaseUrl.TrimEnd('/')
$endpoint = "$supabaseUrl/rest/v1/repositories"

Write-Host "Fetching repositories from GitHub API..."
$githubUrl = "https://api.github.com/users/03200906ericeric-cmd/repos"
try {
    $repos = Invoke-RestMethod -Uri $githubUrl -Headers @{ "User-Agent" = "Mozilla/5.0" }
} catch {
    Write-Error "Error fetching repositories from GitHub: $_"
    exit 1
}

Write-Host "Found $($repos.Count) repositories. Uploading to Supabase..."

foreach ($repo in $repos) {
    # Generate custom tags based on repository name
    $tags = @()
    if ($repo.name -eq "Agentic-Coding") {
        $tags = @("javascript", "audio", "canvas", "game")
    } elseif ($repo.name -eq "AgentCoding") {
        $tags = @("html", "css", "portfolio", "showcase")
    } else {
        if (-not [string]::IsNullOrEmpty($repo.language)) {
            $tags = @($repo.language.ToLower())
        }
    }

    # Construct payload
    $payload = @{
        name = $repo.name
        description = $repo.description
        html_url = $repo.html_url
        language = $repo.language
        stargazers_count = $repo.stargazers_count
        forks_count = $repo.forks_count
        tags = $tags
    }

    $jsonPayload = ConvertTo-Json -InputObject $payload -Depth 5

    Write-Host "Upserting repository: $($repo.name)..."
    try {
        $headers = @{
            "apikey" = $supabaseKey
            "Authorization" = "Bearer $supabaseKey"
            "Content-Type" = "application/json"
            "Prefer" = "resolution=merge-duplicates"
        }
        
        $response = Invoke-WebRequest -Uri $endpoint -Method Post -Headers $headers -Body $jsonPayload -UseBasicParsing
        Write-Host "Successfully upserted $($repo.name) (Status: $($response.StatusCode))"
    } catch {
        Write-Host "Error uploading $($repo.name): $_"
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Host "Response error body: $responseBody"
        }
    }
}

Write-Host "All repositories processed!"
