$BackendSpObjectId = "aa79b42a-3fe3-4f22-8442-61c19a6383d2"

$Token = az account get-access-token `
    --resource-type ms-graph `
    --query accessToken `
    --output tsv

$Headers = @{
    Authorization = "Bearer $Token"
}

Write-Host "`n=== Backend Application Role Assignments ===" -ForegroundColor Cyan

Invoke-RestMethod `
    -Method Get `
    -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$BackendSpObjectId/appRoleAssignments" `
    -Headers $Headers |
    ConvertTo-Json -Depth 20

Write-Host "`n=== Backend OAuth2 Permission Grants ===" -ForegroundColor Cyan

Invoke-RestMethod `
    -Method Get `
    -Uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?`$filter=clientId eq '$BackendSpObjectId'" `
    -Headers $Headers |
    ConvertTo-Json -Depth 20