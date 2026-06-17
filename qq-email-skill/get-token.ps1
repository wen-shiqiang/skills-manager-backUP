param(
    [string]$Token = "",
    [string]$Email = ""
)
# get-token.ps1 — Fetch QQ Mail auth token from credential gateway and write .env
$ErrorActionPreference = "Stop"

# ── Path resolution ──────────────────────────────────────────────────────────

$SkillDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile  = Join-Path $SkillDir ".env"

# ── Remote API base URL ────────────────────────────────────────────────────────

$RemoteBaseUrl = "https://jprx.m.qq.com"

# ── Proxy port and request URL ────────────────────────────────────────────────

$ProxyPort = if ($env:AUTH_GATEWAY_PORT) { $env:AUTH_GATEWAY_PORT } else { "19000" }
$ProxyBase = "http://localhost:${ProxyPort}"
$RemoteUrl = "${RemoteBaseUrl}/data/4164/forward"
$Platform  = "qq_mail"

# ── Domain inference ─────────────────────────────────────────────────────────

function Infer-Servers($domain) {
    switch ($domain) {
        "qq.com"      { $script:imapHost = "imap.qq.com";       $script:smtpHost = "smtp.qq.com" }
        "foxmail.com" { $script:imapHost = "imap.qq.com";        $script:smtpHost = "smtp.qq.com" }
        "vip.qq.com"  { $script:imapHost = "imap.vip.qq.com";    $script:smtpHost = "smtp.vip.qq.com" }
        { $_ -in @("163.com","vip.163.com","126.com","vip.126.com","188.com","vip.188.com","yeah.net") } {
            [Console]::Error.WriteLine("Error: domain @${domain} is not a QQ mailbox, please use 163-email-skill/get-token.ps1")
            exit 1
        }
        default {
            [Console]::Error.WriteLine("Error: unsupported email domain: ${domain}")
            exit 1
        }
    }
}

# ── Write .env file ──────────────────────────────────────────────────────────

function Write-Env($emailAddr, $tokenVal) {
    $homeDir = $env:USERPROFILE
    $envContent = @"
# IMAP Configuration
IMAP_HOST=$imapHost
IMAP_PORT=993
IMAP_USER=$emailAddr
IMAP_PASS=$tokenVal
IMAP_TLS=true
IMAP_REJECT_UNAUTHORIZED=true
IMAP_MAILBOX=INBOX

# SMTP Configuration
SMTP_HOST=$smtpHost
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=$emailAddr
SMTP_PASS=$tokenVal
SMTP_FROM=$emailAddr
SMTP_REJECT_UNAUTHORIZED=true

# File access whitelist
ALLOWED_READ_DIRS=$homeDir\Downloads,$homeDir\Documents
ALLOWED_WRITE_DIRS=$homeDir\Downloads
"@
    Set-Content -Path $EnvFile -Value $envContent -Encoding UTF8 -NoNewline
    $acl = Get-Acl $EnvFile
    $acl.SetAccessRuleProtection($true, $false)
    $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) } | Out-Null
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
        "FullControl", "Allow")
    $acl.AddAccessRule($rule)
    Set-Acl -Path $EnvFile -AclObject $acl
}

# ── Mobile path (-Token + -Email direct write) ───────────────────────────────

if ($Token -or $Email) {
    if (-not $Token -or -not $Email) {
        [Console]::Error.WriteLine("Error: -Token and -Email must be provided together")
        [Console]::Error.WriteLine("Usage: .\get-token.ps1 -Token <auth_code> -Email <email_address>")
        exit 1
    }
    if ($Token -match '\s') {
        [Console]::Error.WriteLine("Error: token must not contain spaces or newlines")
        exit 1
    }
    if ($Email -notmatch '@') {
        [Console]::Error.WriteLine("Error: invalid email address format")
        exit 1
    }
    $Email = $Email.Trim()
    $domain = ($Email -split '@')[-1]
    Infer-Servers $domain
    Write-Env $Email $Token
    [Console]::Error.WriteLine('{"success":true,"env_path":"' + $EnvFile + '","mode":"mobile"}')
    exit 0
}

# ── Gateway request ──────────────────────────────────────────────────────────

$body = @{ platform = $Platform } | ConvertTo-Json -Compress

try {
    $response = Invoke-RestMethod -Uri "${ProxyBase}/proxy/api" `
        -Method Post `
        -Headers @{ "Remote-URL" = $RemoteUrl; "Content-Type" = "application/json" } `
        -Body $body `
        -TimeoutSec 10
} catch {
    [Console]::Error.WriteLine("Error: gateway request failed")
    exit 1
}

# ── Response validation ──────────────────────────────────────────────────────

if ($response.ret -ne 0) {
    [Console]::Error.WriteLine("Error: gateway returned error (ret=$($response.ret))")
    exit 1
}

$accessToken = $response.data.resp.data.access_token
if (-not $accessToken -or $accessToken -eq "null") {
    [Console]::Error.WriteLine("Error: no auth token received, please complete email authorization in the integration panel first")
    exit 1
}

$emailAddress = $response.data.resp.data.extra_data.email_address
if (-not $emailAddress -or $emailAddress -eq "null") {
    [Console]::Error.WriteLine("Error: no email address received")
    exit 1
}

# ── Infer servers and write .env ─────────────────────────────────────────────

$domain = ($emailAddress -split '@')[-1]
Infer-Servers $domain
Write-Env $emailAddress $accessToken
[Console]::Error.WriteLine(".env written to ${EnvFile}")
