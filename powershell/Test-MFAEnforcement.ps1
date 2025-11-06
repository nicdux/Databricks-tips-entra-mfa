<#
.SYNOPSIS
    Script para testar o enforcement de MFA em acessos ao Azure Databricks.

.DESCRIPTION
    Este script verifica se as políticas de Acesso Condicional estão funcionando corretamente,
    analisando logs de signin recentes e identificando se MFA está sendo exigido adequadamente.

.PARAMETER UserPrincipalName
    UPN do usuário para testar. Se não especificado, analisa todos os usuários.

.PARAMETER HoursBack
    Número de horas para retroceder na análise de logs. Padrão: 24 horas.

.PARAMETER WorkspaceId
    Workspace ID do Log Analytics onde os SigninLogs estão armazenados.

.EXAMPLE
    .\Test-MFAEnforcement.ps1 -WorkspaceId "abc-123-xyz"
    Testa enforcement para todos os usuários nas últimas 24h.

.EXAMPLE
    .\Test-MFAEnforcement.ps1 -UserPrincipalName "usuario@contoso.com" -HoursBack 48 -WorkspaceId "abc-123-xyz"
    Testa enforcement para usuário específico nas últimas 48h.

.NOTES
    Requer:
    - Módulo Az.OperationalInsights instalado
    - Módulo Microsoft.Graph instalado
    - Permissões: Leitor em Log Analytics, Policy.Read.All
    
    Instalação dos módulos:
    Install-Module Az.OperationalInsights -Scope CurrentUser
    Install-Module Microsoft.Graph -Scope CurrentUser

.LINK
    https://github.com/nicdux/Databricks-tips-entra-mfa
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$UserPrincipalName,

    [Parameter(Mandatory = $false)]
    [int]$HoursBack = 24,

    [Parameter(Mandatory = $true)]
    [string]$WorkspaceId
)

# Verificar módulos
$requiredModules = @("Az.OperationalInsights", "Az.Accounts", "Microsoft.Graph.Identity.SignIns")
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Error "Módulo $module não encontrado!"
        Write-Host "Execute: Install-Module $module -Scope CurrentUser" -ForegroundColor Yellow
        exit 1
    }
}

Import-Module Az.OperationalInsights
Import-Module Az.Accounts
Import-Module Microsoft.Graph.Identity.SignIns

Write-Host "🔐 Testando Enforcement de MFA no Azure Databricks" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""

# Conectar ao Azure
try {
    Write-Host "Conectando ao Azure..." -ForegroundColor Yellow
    Connect-AzAccount -ErrorAction Stop | Out-Null
    Write-Host "✅ Conectado ao Azure" -ForegroundColor Green
}
catch {
    Write-Error "Falha ao conectar ao Azure: $_"
    exit 1
}

# Conectar ao Microsoft Graph
try {
    Write-Host "Conectando ao Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Policy.Read.All", "AuditLog.Read.All" -NoWelcome
    Write-Host "✅ Conectado ao Microsoft Graph" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error "Falha ao conectar ao Microsoft Graph: $_"
    exit 1
}

# Construir query KQL
$kqlQuery = @"
SigninLogs
| where AppDisplayName contains "Databricks"
| where TimeGenerated > ago($($HoursBack)h)
$(if ($UserPrincipalName) { "| where UserPrincipalName == '$UserPrincipalName'" })
| where ResultType == 0
| project 
    TimeGenerated,
    UserPrincipalName,
    AppDisplayName,
    AuthenticationRequirement,
    ConditionalAccessStatus,
    MfaDetail = tostring(MfaDetail),
    IPAddress,
    Location
| order by TimeGenerated desc
"@

Write-Host "🔍 Analisando logs de signin..." -ForegroundColor Yellow
Write-Host "   Período: Últimas $HoursBack horas" -ForegroundColor Gray
if ($UserPrincipalName) {
    Write-Host "   Usuário: $UserPrincipalName" -ForegroundColor Gray
}
Write-Host ""

# Executar query no Log Analytics
try {
    $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceId -Query $kqlQuery
    $logs = $queryResults.Results
    
    if ($logs.Count -eq 0) {
        Write-Host "⚠️ Nenhum login encontrado no período especificado." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Possíveis razões:" -ForegroundColor Cyan
        Write-Host "   • Nenhum acesso ao Databricks no período" -ForegroundColor White
        Write-Host "   • Logs ainda não foram ingeridos (delay de 5-15 min)" -ForegroundColor White
        Write-Host "   • WorkspaceId incorreto" -ForegroundColor White
        Write-Host "   • Diagnóstico do Entra ID não configurado" -ForegroundColor White
        
        Disconnect-AzAccount | Out-Null
        Disconnect-MgGraph | Out-Null
        exit 0
    }
    
    Write-Host "✅ Encontrados $($logs.Count) logins no período" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error "Erro ao executar query: $_"
    Disconnect-AzAccount | Out-Null
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Análise dos resultados
Write-Host "📊 Análise de Enforcement MFA:" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""

# Estatísticas gerais
$totalLogins = $logs.Count
$loginsComMFA = ($logs | Where-Object { $_.AuthenticationRequirement -eq "multiFactorAuthentication" }).Count
$loginsSemMFA = $totalLogins - $loginsComMFA
$taxaMFA = if ($totalLogins -gt 0) { [math]::Round(($loginsComMFA / $totalLogins) * 100, 2) } else { 0 }

Write-Host "Total de logins: $totalLogins" -ForegroundColor White
Write-Host "Logins com MFA: $loginsComMFA" -ForegroundColor $(if ($loginsComMFA -eq $totalLogins) { "Green" } else { "Yellow" })
Write-Host "Logins SEM MFA: $loginsSemMFA" -ForegroundColor $(if ($loginsSemMFA -eq 0) { "Green" } else { "Red" })
Write-Host "Taxa de compliance MFA: $taxaMFA%" -ForegroundColor $(if ($taxaMFA -eq 100) { "Green" } elseif ($taxaMFA -ge 95) { "Yellow" } else { "Red" })
Write-Host ""

# Status de compliance
if ($taxaMFA -eq 100) {
    Write-Host "✅ STATUS: CONFORME (100%)" -ForegroundColor Green
    Write-Host "   Todas as autenticações exigiram MFA!" -ForegroundColor Green
}
elseif ($taxaMFA -ge 95) {
    Write-Host "⚠️ STATUS: QUASE CONFORME ($taxaMFA%)" -ForegroundColor Yellow
    Write-Host "   Algumas autenticações não exigiram MFA." -ForegroundColor Yellow
}
else {
    Write-Host "❌ STATUS: NÃO CONFORME ($taxaMFA%)" -ForegroundColor Red
    Write-Host "   Muitas autenticações sem MFA detectadas!" -ForegroundColor Red
}
Write-Host ""

# Se houver logins sem MFA, listar detalhes
if ($loginsSemMFA -gt 0) {
    Write-Host "🚨 ATENÇÃO: Logins sem MFA detectados!" -ForegroundColor Red
    Write-Host ""
    
    $loginsSemMFADetails = $logs | Where-Object { $_.AuthenticationRequirement -ne "multiFactorAuthentication" }
    
    Write-Host "📋 Detalhes dos logins sem MFA:" -ForegroundColor Yellow
    foreach ($login in $loginsSemMFADetails) {
        Write-Host "   ⚠️ $($login.TimeGenerated)" -ForegroundColor Red
        Write-Host "      Usuário: $($login.UserPrincipalName)" -ForegroundColor White
        Write-Host "      Local: $($login.Location)" -ForegroundColor Gray
        Write-Host "      IP: $($login.IPAddress)" -ForegroundColor Gray
        Write-Host "      CA Status: $($login.ConditionalAccessStatus)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Análise de usuários sem MFA
    $usuariosSemMFA = $loginsSemMFADetails | Group-Object UserPrincipalName | 
        Select-Object Name, Count | 
        Sort-Object Count -Descending
    
    Write-Host "👥 Usuários com logins sem MFA:" -ForegroundColor Yellow
    foreach ($usuario in $usuariosSemMFA) {
        Write-Host "   • $($usuario.Name): $($usuario.Count) login(s)" -ForegroundColor White
    }
    Write-Host ""
    
    # Recomendações
    Write-Host "💡 Ações Recomendadas:" -ForegroundColor Cyan
    Write-Host "   1. Verificar políticas de Acesso Condicional" -ForegroundColor White
    Write-Host "      - Confirme que a política está ATIVADA" -ForegroundColor Gray
    Write-Host "      - Verifique se usuários estão em grupos de exceção" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   2. Verificar AppId na política" -ForegroundColor White
    Write-Host "      - AppId deve ser: 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   3. Executar script de diagnóstico" -ForegroundColor White
    Write-Host "      - .\troubleshooting\Diagnose-DatabricksMFA.ps1" -ForegroundColor Gray
    Write-Host ""
}

# Métodos MFA utilizados
$mfaMethods = $logs | 
    Where-Object { $_.AuthenticationRequirement -eq "multiFactorAuthentication" -and $_.MfaDetail } |
    ForEach-Object { 
        try {
            $mfaObj = $_.MfaDetail | ConvertFrom-Json
            $mfaObj.authMethod
        } catch {
            "Unknown"
        }
    } |
    Where-Object { $_ } |
    Group-Object |
    Select-Object Name, Count |
    Sort-Object Count -Descending

if ($mfaMethods) {
    Write-Host "📱 Métodos MFA utilizados:" -ForegroundColor Cyan
    foreach ($method in $mfaMethods) {
        $percentage = [math]::Round(($method.Count / $loginsComMFA) * 100, 1)
        Write-Host "   • $($method.Name): $($method.Count) ($percentage%)" -ForegroundColor White
    }
    Write-Host ""
}

# Verificar políticas CA ativas
Write-Host "🔍 Verificando políticas de Acesso Condicional..." -ForegroundColor Yellow

try {
    $policies = Get-MgIdentityConditionalAccessPolicy -All
    $databricksPolicies = $policies | Where-Object {
        $_.Conditions.Applications.IncludeApplications -contains "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"
    }
    
    if ($databricksPolicies) {
        Write-Host "✅ Políticas CA para Databricks encontradas: $($databricksPolicies.Count)" -ForegroundColor Green
        Write-Host ""
        
        foreach ($policy in $databricksPolicies) {
            $stateEmoji = switch ($policy.State) {
                "enabled" { "✅" }
                "disabled" { "⏸️" }
                "enabledForReportingButNotEnforced" { "📊" }
                default { "❓" }
            }
            
            Write-Host "   $stateEmoji $($policy.DisplayName)" -ForegroundColor White
            Write-Host "      Estado: $($policy.State)" -ForegroundColor Gray
            
            if ($policy.GrantControls.BuiltInControls -contains "mfa") {
                Write-Host "      Controle: ✅ Exige MFA" -ForegroundColor Green
            }
            else {
                Write-Host "      Controle: ⚠️ NÃO exige MFA" -ForegroundColor Yellow
            }
            Write-Host ""
        }
    }
    else {
        Write-Host "⚠️ NENHUMA política CA para Databricks encontrada!" -ForegroundColor Red
        Write-Host ""
        Write-Host "💡 Ação necessária:" -ForegroundColor Cyan
        Write-Host "   Crie uma política de Acesso Condicional para exigir MFA no Databricks" -ForegroundColor White
        Write-Host "   Consulte: docs/guia-completo.md" -ForegroundColor Gray
        Write-Host ""
    }
}
catch {
    Write-Warning "Não foi possível verificar políticas CA: $_"
}

# Resumo final
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""
Write-Host "📋 Resumo do Teste:" -ForegroundColor Cyan
if ($taxaMFA -eq 100 -and $databricksPolicies.Count -gt 0) {
    Write-Host "✅ MFA está sendo ENFORÇADO corretamente" -ForegroundColor Green
    Write-Host "   • 100% dos logins exigiram MFA" -ForegroundColor Green
    Write-Host "   • Políticas CA estão configuradas" -ForegroundColor Green
}
elseif ($taxaMFA -ge 95) {
    Write-Host "⚠️ MFA está PARCIALMENTE enforçado" -ForegroundColor Yellow
    Write-Host "   • $taxaMFA% dos logins exigiram MFA" -ForegroundColor Yellow
    Write-Host "   • Revisar exceções e configurações" -ForegroundColor Yellow
}
else {
    Write-Host "❌ MFA NÃO está sendo enforçado adequadamente" -ForegroundColor Red
    Write-Host "   • Apenas $taxaMFA% dos logins exigiram MFA" -ForegroundColor Red
    Write-Host "   • Ação imediata necessária!" -ForegroundColor Red
}
Write-Host ""

# Desconectar
Disconnect-AzAccount | Out-Null
Disconnect-MgGraph | Out-Null

Write-Host "✅ Teste concluído!" -ForegroundColor Green

# Exit code baseado no resultado
if ($taxaMFA -eq 100) {
    exit 0  # Sucesso
}
elseif ($taxaMFA -ge 95) {
    exit 1  # Warning
}
else {
    exit 2  # Error
}
