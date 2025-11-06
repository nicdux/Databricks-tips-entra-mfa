<#
.SYNOPSIS
    Script para exportar/backup de políticas de Acesso Condicional relacionadas ao Databricks.

.DESCRIPTION
    Este script exporta as políticas de Acesso Condicional que incluem o Azure Databricks,
    permitindo documentação, backup e versionamento das políticas configuradas.

.PARAMETER ExportPath
    Caminho para exportar as políticas em JSON. Padrão: .\conditional-access-policies-backup.json

.PARAMETER AppId
    AppId para filtrar políticas. Padrão: AppId do Azure Databricks.

.PARAMETER IncludeAllPolicies
    Exporta TODAS as políticas CA, não apenas as do Databricks.

.EXAMPLE
    .\Export-ConditionalAccessPolicies.ps1
    Exporta políticas do Databricks para arquivo padrão.

.EXAMPLE
    .\Export-ConditionalAccessPolicies.ps1 -ExportPath ".\backup-ca-policies.json"
    Exporta para arquivo específico.

.EXAMPLE
    .\Export-ConditionalAccessPolicies.ps1 -IncludeAllPolicies
    Exporta todas as políticas CA do tenant.

.NOTES
    Requer:
    - Módulo Microsoft.Graph instalado
    - Permissões: Policy.Read.All ou Policy.ReadWrite.ConditionalAccess
    
    Útil para:
    - Backup de configuração
    - Documentação
    - Auditoria
    - Migração entre tenants/workspaces

.LINK
    https://github.com/nicdux/Databricks-tips-entra-mfa
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ExportPath = ".\conditional-access-policies-backup.json",

    [Parameter(Mandatory = $false)]
    [string]$AppId = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d",  # Azure Databricks

    [Parameter(Mandatory = $false)]
    [switch]$IncludeAllPolicies
)

# Verificar módulo
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Identity.SignIns)) {
    Write-Error "Módulo Microsoft.Graph.Identity.SignIns não encontrado!"
    Write-Host "Execute: Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

Import-Module Microsoft.Graph.Identity.SignIns

Write-Host "📋 Exportando Políticas de Acesso Condicional..." -ForegroundColor Cyan
Write-Host ""

# Conectar ao Microsoft Graph
try {
    Write-Host "Conectando ao Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Policy.Read.All" -NoWelcome
    Write-Host "✅ Conectado com sucesso!`n" -ForegroundColor Green
}
catch {
    Write-Error "Falha ao conectar ao Microsoft Graph: $_"
    exit 1
}

# Buscar políticas
Write-Host "🔍 Buscando políticas..." -ForegroundColor Yellow

try {
    # Obter todas as políticas
    $allPolicies = Get-MgIdentityConditionalAccessPolicy -All
    
    Write-Host "✅ Total de políticas no tenant: $($allPolicies.Count)" -ForegroundColor Green
    Write-Host ""
    
    # Filtrar políticas do Databricks (se não for exportar todas)
    if (-not $IncludeAllPolicies) {
        $filteredPolicies = $allPolicies | Where-Object {
            $_.Conditions.Applications.IncludeApplications -contains $AppId
        }
        
        Write-Host "🎯 Políticas que incluem Azure Databricks: $($filteredPolicies.Count)" -ForegroundColor Cyan
        
        if ($filteredPolicies.Count -eq 0) {
            Write-Host "⚠️ Nenhuma política encontrada para o Azure Databricks." -ForegroundColor Yellow
            Write-Host "   Verifique se há políticas CA configuradas para o Databricks." -ForegroundColor Gray
            Disconnect-MgGraph | Out-Null
            exit 0
        }
        
        $policiesToExport = $filteredPolicies
    }
    else {
        Write-Host "📦 Exportando TODAS as políticas CA do tenant" -ForegroundColor Cyan
        $policiesToExport = $allPolicies
    }
    
    # Exibir resumo das políticas
    Write-Host ""
    Write-Host "📊 Resumo das políticas a exportar:" -ForegroundColor Cyan
    foreach ($policy in $policiesToExport) {
        $stateEmoji = switch ($policy.State) {
            "enabled" { "✅" }
            "disabled" { "⏸️" }
            "enabledForReportingButNotEnforced" { "📊" }
            default { "❓" }
        }
        
        Write-Host "   $stateEmoji $($policy.DisplayName) [$($policy.State)]" -ForegroundColor White
    }
    Write-Host ""
    
    # Preparar dados para export
    $exportData = @{
        ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        TenantId = (Get-MgContext).TenantId
        FilteredByAppId = if (-not $IncludeAllPolicies) { $AppId } else { "ALL" }
        PoliciesCount = $policiesToExport.Count
        Policies = @()
    }
    
    # Processar cada política
    foreach ($policy in $policiesToExport) {
        $policyData = @{
            Id = $policy.Id
            DisplayName = $policy.DisplayName
            State = $policy.State
            CreatedDateTime = $policy.CreatedDateTime
            ModifiedDateTime = $policy.ModifiedDateTime
            Conditions = @{
                Applications = @{
                    IncludeApplications = $policy.Conditions.Applications.IncludeApplications
                    ExcludeApplications = $policy.Conditions.Applications.ExcludeApplications
                    IncludeUserActions = $policy.Conditions.Applications.IncludeUserActions
                }
                Users = @{
                    IncludeUsers = $policy.Conditions.Users.IncludeUsers
                    ExcludeUsers = $policy.Conditions.Users.ExcludeUsers
                    IncludeGroups = $policy.Conditions.Users.IncludeGroups
                    ExcludeGroups = $policy.Conditions.Users.ExcludeGroups
                    IncludeRoles = $policy.Conditions.Users.IncludeRoles
                    ExcludeRoles = $policy.Conditions.Users.ExcludeRoles
                }
                Platforms = @{
                    IncludePlatforms = $policy.Conditions.Platforms.IncludePlatforms
                    ExcludePlatforms = $policy.Conditions.Platforms.ExcludePlatforms
                }
                Locations = @{
                    IncludeLocations = $policy.Conditions.Locations.IncludeLocations
                    ExcludeLocations = $policy.Conditions.Locations.ExcludeLocations
                }
                ClientAppTypes = $policy.Conditions.ClientAppTypes
                SignInRiskLevels = $policy.Conditions.SignInRiskLevels
                UserRiskLevels = $policy.Conditions.UserRiskLevels
            }
            GrantControls = @{
                Operator = $policy.GrantControls.Operator
                BuiltInControls = $policy.GrantControls.BuiltInControls
                CustomAuthenticationFactors = $policy.GrantControls.CustomAuthenticationFactors
                TermsOfUse = $policy.GrantControls.TermsOfUse
            }
            SessionControls = if ($policy.SessionControls) {
                @{
                    ApplicationEnforcedRestrictions = $policy.SessionControls.ApplicationEnforcedRestrictions
                    CloudAppSecurity = $policy.SessionControls.CloudAppSecurity
                    PersistentBrowser = $policy.SessionControls.PersistentBrowser
                    SignInFrequency = $policy.SessionControls.SignInFrequency
                }
            } else { $null }
        }
        
        $exportData.Policies += $policyData
    }
    
    # Exportar para JSON
    Write-Host "💾 Exportando para: $ExportPath" -ForegroundColor Yellow
    
    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
    
    Write-Host "✅ Exportação concluída com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📄 Arquivo: $ExportPath" -ForegroundColor White
    Write-Host "📊 Políticas exportadas: $($policiesToExport.Count)" -ForegroundColor White
    Write-Host ""
    
    # Estatísticas
    $enabledCount = ($policiesToExport | Where-Object { $_.State -eq "enabled" }).Count
    $disabledCount = ($policiesToExport | Where-Object { $_.State -eq "disabled" }).Count
    $reportOnlyCount = ($policiesToExport | Where-Object { $_.State -eq "enabledForReportingButNotEnforced" }).Count
    
    Write-Host "📊 Status das políticas exportadas:" -ForegroundColor Cyan
    Write-Host "   ✅ Ativas (enabled): $enabledCount" -ForegroundColor Green
    Write-Host "   ⏸️ Desabilitadas (disabled): $disabledCount" -ForegroundColor Gray
    Write-Host "   📊 Modo relatório (report-only): $reportOnlyCount" -ForegroundColor Yellow
    Write-Host ""
    
    # Dicas de uso
    Write-Host "💡 Dicas de uso do backup:" -ForegroundColor Cyan
    Write-Host "   • Mantenha este arquivo em controle de versão (Git)" -ForegroundColor White
    Write-Host "   • Faça backup antes de modificar políticas" -ForegroundColor White
    Write-Host "   • Use para documentar configurações" -ForegroundColor White
    Write-Host "   • Compare versões para auditar mudanças" -ForegroundColor White
    Write-Host ""
}
catch {
    Write-Error "Erro ao processar políticas: $_"
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Desconectar
Disconnect-MgGraph | Out-Null
Write-Host "✅ Concluído!" -ForegroundColor Green
