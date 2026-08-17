param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = "CommerceFabric-ResourceGroup",

    [Parameter(Mandatory = $false)]
    [string]$ApimName = "commercefabricapimanagement",

    [Parameter(Mandatory = $false)]
    [string]$GatewayServiceName = "apigateway"
)

$ErrorActionPreference = "Stop"

Write-Host "Discovering API Gateway LoadBalancer IP..."

$GatewayIp = kubectl get service $GatewayServiceName `
    -o jsonpath="{.status.loadBalancer.ingress[0].ip}"

if ([string]::IsNullOrWhiteSpace($GatewayIp)) {
    throw "API Gateway service '$GatewayServiceName' does not currently have an external IP."
}

$GatewayBaseUrl = "http://${GatewayIp}:8080"

Write-Host "Gateway backend URL: $GatewayBaseUrl"

$OrdersSwaggerPath = Join-Path $PSScriptRoot "apim/orders.swagger.json"
$ProductsSwaggerPath = Join-Path $PSScriptRoot "apim/products.swagger.json"
$UsersSwaggerPath = Join-Path $PSScriptRoot "apim/users.swagger.json"

Write-Host "Importing Orders API..."

az apim api import `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id "ordersmicroservice-api" `
    --display-name "OrdersMicroservice.API" `
    --path "gateway/orders" `
    --protocols https `
    --specification-format OpenApiJson `
    --specification-path $OrdersSwaggerPath `
    --service-url "$GatewayBaseUrl/gateway/orders"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to import Orders API into APIM."
}

Write-Host "Importing Products API..."

az apim api import `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id "commercefabric-productservice-api" `
    --display-name "ProductService.API" `
    --path "gateway/products" `
    --protocols https `
    --specification-format apimJson `
    --specification-path $ProductsSwaggerPath `
    --service-url "$GatewayBaseUrl/gateway/products"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to import Products API into APIM."
}

Write-Host "Importing Users API..."

az apim api import `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id "userservice-api" `
    --display-name "UserService.API" `
    --path "gateway/users" `
    --protocols https `
    --specification-format apimJson `
    --specification-path $UsersSwaggerPath `
    --service-url "$GatewayBaseUrl/gateway/users"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to import Users API into APIM."
}

Write-Host "APIM API imports completed successfully."

Write-Host "Applying APIM API policies..."

az deployment group create `
    --resource-group $ResourceGroup `
    --name "commercefabric-apim-policies" `
    --template-file ".\infra\modules\apim-policies.bicep" `
    --parameters `
    apimName=$ApimName `
    corsOrigin="https://localhost:4200" `
    openIdConfigurationUrl="https://CommerceFabricWeb.ciamlogin.com/c0706265-6fae-4a73-b972-26ef20ccdd46/v2.0/.well-known/openid-configuration" `
    apiAudience="6151da32-d5b8-484c-8d55-499e944367e7" `
    tokenIssuer="https://c0706265-6fae-4a73-b972-26ef20ccdd46.ciamlogin.com/c0706265-6fae-4a73-b972-26ef20ccdd46/v2.0"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to apply APIM API policies."
}

Write-Host "APIM policies applied successfully."