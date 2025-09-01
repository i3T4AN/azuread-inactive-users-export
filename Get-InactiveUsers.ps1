# Get-InactiveUsers.ps1
# PowerShell 5.1

[CmdletBinding()] param(
  [Parameter(Mandatory=$true)] [string] $TenantId,
  [Parameter(Mandatory=$true)] [string] $ClientId,
  [Parameter(Mandatory=$true)] [string] $Secret,
  [int] $Days = 90,
  [string] $OutFile
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($Days -lt 0) { throw "-Days must be >= 0" }
if (-not $OutFile) {
  $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
  $OutFile = Join-Path -Path (Get-Location) -ChildPath "InactiveUsers-$($Days)d-$stamp.csv"
}
function Get-AccessToken {
  param([string]$TenantId,[string]$ClientId,[string]$Secret)
  $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
  $body = @{client_id=$ClientId;client_secret=$Secret;grant_type='client_credentials';scope='https://graph.microsoft.com/.default'}
  $resp = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body -ContentType 'application/x-www-form-urlencoded'
  if (-not $resp.access_token) { throw 'Failed to obtain access token.' }
  return $resp.access_token
}
function Invoke-GraphRequest {
  param([Parameter(Mandatory=$true)] [string] $Uri,[string] $Method = 'GET',[hashtable] $Headers = @{},$Body = $null)
  $maxAttempts = 8;$attempt = 0
  while ($true) {
    try {
      if ($Method -eq 'GET') {return Invoke-RestMethod -Method Get -Uri $Uri -Headers $Headers -TimeoutSec 100}
      else {return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -Body $Body -TimeoutSec 100}
    } catch {
      $resp=$_.Exception.Response;$status=$null
      if ($resp) {try{$status=[int]$resp.StatusCode.value__}catch{}}
      if ($status -in 429,503,504) {
        $attempt++;if ($attempt -ge $maxAttempts) {throw}
        $retryAfter=$null;if ($resp){try{$retryAfter=[int]($resp.Headers['Retry-After'])}catch{}}
        if (-not $retryAfter -or $retryAfter -le 0) {$retryAfter=[math]::Min(60,[int][math]::Pow(2,$attempt))}
        Start-Sleep -Seconds $retryAfter;continue
      }
      throw
    }
  }
}
$accessToken = Get-AccessToken -TenantId $TenantId -ClientId $ClientId -Secret $Secret
$base = 'https://graph.microsoft.com/v1.0'
$headers = @{Authorization = "Bearer $accessToken"; 'ConsistencyLevel' = 'eventual'}
$select = 'id,displayName,userPrincipalName,signInActivity'
$top = 999
$uri = "$base/users?`$select=$select&`$top=$top"
$allUsers = New-Object System.Collections.Generic.List[object]
while ($uri) {
  $page = Invoke-GraphRequest -Uri $uri -Headers $headers
  if ($page.value) { $allUsers.AddRange($page.value) }
  $uri = $page.'@odata.nextLink'
}
$cutoffUtc = (Get-Date).ToUniversalTime().AddDays(-$Days)
$inactive = foreach ($u in $allUsers) {
  $last=$null
  if ($u.signInActivity -and $u.signInActivity.lastSignInDateTime) {try{$last=([datetime]$u.signInActivity.lastSignInDateTime).ToUniversalTime()}catch{$last=$null}}
  if (-not $last -or $last -lt $cutoffUtc) {
    [pscustomobject]@{DisplayName=$u.displayName;UPN=$u.userPrincipalName;LastSignInDateTime=if ($u.signInActivity.lastSignInDateTime) {$u.signInActivity.lastSignInDateTime}else{$null}}
  }
}
$inactive | Sort-Object UPN | Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8
Write-Host "Exported $($inactive.Count) inactive users to: $OutFile" -ForegroundColor Green
