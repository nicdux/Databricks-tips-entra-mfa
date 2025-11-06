<#
.SYNOPSIS
    Script para descobrir e inventariar todos os Service Principals (SPNs) do Azure Databricks.

.DESCRIPTION
    Este script conecta ao Microsoft Graph e lista todos os Enterprise Applications relacionados
    ao Azure Databricks no tenant. Útil para identificar quais aplicações devem ser incluídas
    nas políticas de Acesso Condicional.

.PARAMETER ExportPath
    Caminho para exportar o resultado em CSV. Se não especificado, apenas exibe no console.

.PARAMETER IncludeCustomApps
    Inclui aplicações customizadas do Databricks (não apenas a app padrão).

.EXAMPLE
    .\Get-DatabricksServicePrincipals.ps1
    Lista todos os SPNs do Databricks no console.

.EXAMPLE
    .\Get-DatabricksServicePrincipals.ps1 -ExportPath ".\databricks-spns.csv"
    Lista e exporta para CSV.

.EXAMPLE
    .\Get-DatabricksServicePrincipals.ps1 -IncludeCustomApps -ExportPath ".\databricks-all.csv"
    Lista todos, incluindo apps customizadas.

.NOTES
    Requer:
    - Módulo Microsoft.Graph instalado
    - Permissões: Application.Read.All, Directory.Read.All
    
    Instalação do módulo:
    Install-Module Microsoft.Graph -Scope CurrentUser

.LINK
    https://github.com/nicdux/Databricks-tips-entra-mfa
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ExportPath,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeCustomApps
)

# Verificar se o módulo Microsoft.Graph está instalado
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Applications)) {
    Write-Error "Módulo Microsoft.Graph.Applications não encontrado!"
    Write-Host "Execute: Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

# Importar módulos necessários
Import-Module Microsoft.Graph.Applications
Import-Module Microsoft.Graph.Identity.DirectoryManagement

Write-Host "🔍 Descobrindo Service Principals do Azure Databricks..." -ForegroundColor Cyan
Write-Host ""

# Conectar ao Microsoft Graph
try {
    Write-Host "Conectando ao Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Application.Read.All", "Directory.Read.All" -NoWelcome
    Write-Host "✅ Conectado com sucesso!`n" -ForegroundColor Green
}
catch {
    Write-Error "Falha ao conectar ao Microsoft Graph: $_"
    exit 1
}

# AppId padrão do Azure Databricks
$databricksAppId = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"

Write-Host "📋 Buscando Azure Databricks (AppId padrão)..." -ForegroundColor Yellow

# Buscar SPN padrão do Azure Databricks
$databricksSPN = Get-MgServicePrincipal -Filter "appId eq '$databricksAppId'"

$results = @()

if ($databricksSPN) {
    Write-Host "✅ Encontrado: Azure Databricks" -ForegroundColor Green
    
    $result = [PSCustomObject]@{
        DisplayName       = $databricksSPN.DisplayName
        AppId             = $databricksSPN.AppId
        ObjectId          = $databricksSPN.Id
        ServicePrincipalType = $databricksSPN.ServicePrincipalType
        AccountEnabled    = $databricksSPN.AccountEnabled
        AppOwnerOrganizationId = $databricksSPN.AppOwnerOrganizationId
        SignInAudience    = $databricksSPN.SignInAudience
        Type              = "Standard"
    }
    
    $results += $result
    
    # Exibir detalhes
    Write-Host "   DisplayName: $($result.DisplayName)" -ForegroundColor Gray
    Write-Host "   AppId: $($result.AppId)" -ForegroundColor Gray
    Write-Host "   ObjectId: $($result.ObjectId)" -ForegroundColor Gray
    Write-Host ""
}
else {
    Write-Host "⚠️ Azure Databricks padrão não encontrado. Pode não estar registrado neste tenant." -ForegroundColor Yellow
    Write-Host ""
}

# Buscar aplicações customizadas se solicitado
if ($IncludeCustomApps) {
    Write-Host "📋 Buscando aplicações customizadas do Databricks..." -ForegroundColor Yellow
    
    # Buscar por nome contendo "databricks"
    $customApps = Get-MgServicePrincipal -Filter "startswith(displayName,'Databricks')" -All
    
    if ($customApps) {
        foreach ($app in $customApps) {
            # Pular se for a app padrão (já processada)
            if ($app.AppId -eq $databricksAppId) {
                continue
            }
            
            Write-Host "✅ Encontrado: $($app.DisplayName)" -ForegroundColor Green
            
            $result = [PSCustomObject]@{
                DisplayName       = $app.DisplayName
                AppId             = $app.AppId
                ObjectId          = $app.Id
                ServicePrincipalType = $app.ServicePrincipalType
                AccountEnabled    = $app.AccountEnabled
                AppOwnerOrganizationId = $app.AppOwnerOrganizationId
                SignInAudience    = $app.SignInAudience
                Type              = "Custom"
            }
            
            $results += $result
            
            # Exibir detalhes
            Write-Host "   DisplayName: $($result.DisplayName)" -ForegroundColor Gray
            Write-Host "   AppId: $($result.AppId)" -ForegroundColor Gray
            Write-Host "   ObjectId: $($result.ObjectId)" -ForegroundColor Gray
            Write-Host "   Type: Custom" -ForegroundColor Gray
            Write-Host ""
        }
    }
    else {
        Write-Host "ℹ️ Nenhuma aplicação customizada do Databricks encontrada." -ForegroundColor Cyan
        Write-Host ""
    }
}

# Resumo
Write-Host "📊 Resumo:" -ForegroundColor Cyan
Write-Host "   Total de SPNs encontrados: $($results.Count)" -ForegroundColor White
if ($IncludeCustomApps) {
    Write-Host "   Standard: $(($results | Where-Object {$_.Type -eq 'Standard'}).Count)" -ForegroundColor White
    Write-Host "   Custom: $(($results | Where-Object {$_.Type -eq 'Custom'}).Count)" -ForegroundColor White
}
Write-Host ""

# Exibir tabela formatada
if ($results.Count -gt 0) {
    Write-Host "📋 Lista de Service Principals:" -ForegroundColor Cyan
    $results | Format-Table DisplayName, AppId, Type, AccountEnabled -AutoSize
}

# Exportar para CSV se solicitado
if ($ExportPath) {
    try {
        $results | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
        Write-Host "✅ Exportado para: $ExportPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Falha ao exportar para CSV: $_"
    }
}

# Orientações para uso em Política CA
if ($results.Count -gt 0) {
    Write-Host ""
    Write-Host "💡 Próximos Passos:" -ForegroundColor Cyan
    Write-Host "   1. Ao criar a Política de Acesso Condicional:" -ForegroundColor White
    Write-Host "      - Vá para: Microsoft Entra ID > Proteção > Acesso Condicional" -ForegroundColor Gray
    Write-Host "      - Aplicativos de nuvem > Selecionar aplicativos" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   2. Adicione os seguintes AppIds na política:" -ForegroundColor White
    foreach ($app in $results) {
        Write-Host "      - $($app.AppId) ($($app.DisplayName))" -ForegroundColor Gray
    }
    Write-Host ""
}

# Desconectar
Disconnect-MgGraph | Out-Null
Write-Host "✅ Concluído!" -ForegroundColor Green
