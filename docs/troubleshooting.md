# Troubleshooting: MFA no Azure Databricks

## Índice

1. [Problemas Comuns](#problemas-comuns)
2. [Diagnóstico de Problemas](#diagnóstico-de-problemas)
3. [Soluções Detalhadas](#soluções-detalhadas)
4. [Ferramentas de Diagnóstico](#ferramentas-de-diagnóstico)
5. [Quando Escalar](#quando-escalar)

## Problemas Comuns

### 1. Usuário Não Recebe Desafio MFA

**Sintomas:**
- Usuário consegue fazer login no Databricks sem MFA
- Logs mostram `AuthenticationRequirement: singleFactorAuthentication`

**Causas Possíveis:**

#### Causa 1.1: Política não está ativada

**Diagnóstico:**
```powershell
# Verificar status da política
Get-MgIdentityConditionalAccessPolicy -Filter "displayName eq 'MFA-Obrigatório-Azure-Databricks'" | 
    Select-Object DisplayName, State
```

**Solução:**
```powershell
# Ativar política
$policyId = "policy-id-here"
Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policyId -State "enabled"
```

#### Causa 1.2: Usuário está em grupo de exclusão

**Diagnóstico:**
```kusto
SigninLogs
| where UserPrincipalName == "usuario@contoso.com"
| where AppDisplayName contains "Databricks"
| project TimeGenerated, ConditionalAccessPolicies
| mv-expand ConditionalAccessPolicies
| where ConditionalAccessPolicies.displayName == "MFA-Obrigatório-Azure-Databricks"
| project TimeGenerated, Result = ConditionalAccessPolicies.result
```

**Solução:**
1. Verificar grupos de exclusão na política
2. Remover usuário do grupo de exclusão
3. Testar novamente

#### Causa 1.3: Sessão MFA ainda válida

**Diagnóstico:**
```kusto
SigninLogs
| where UserPrincipalName == "usuario@contoso.com"
| where TimeGenerated > ago(24h)
| project TimeGenerated, AppDisplayName, AuthenticationRequirement, 
          SessionLifetimePolicies = tostring(AppliedConditionalAccessPolicies)
| order by TimeGenerated desc
```

**Solução:**
- Aguardar expiração da sessão (8 horas por padrão)
- Ou: Usuário fazer logout e login novamente
- Ou: Limpar cookies do navegador

#### Causa 1.4: AppId incorreto na política

**Diagnóstico:**
```powershell
# Verificar AppId na política
$policy = Get-MgIdentityConditionalAccessPolicy -Filter "displayName eq 'MFA-Obrigatório-Azure-Databricks'"
$policy.Conditions.Applications.IncludeApplications
```

**Solução:**
```powershell
# Corrigir AppId
$params = @{
    Conditions = @{
        Applications = @{
            IncludeApplications = @("2ff814a6-3304-4ab8-85cb-cd0e6f879c1d")
        }
    }
}
Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -BodyParameter $params
```

### 2. Usuário Bloqueado por Não Ter MFA

**Sintomas:**
- Login falha com erro: "More information is required"
- `ResultType = 50074` nos logs

**Causa:**
- Usuário não completou registro de MFA

**Solução Imediata:**

```powershell
# 1. Adicionar usuário ao grupo de exclusão temporariamente
$groupId = "emergency-exclusion-group-id"
$userId = "user-object-id"
New-MgGroupMember -GroupId $groupId -DirectoryObjectId $userId

# 2. Instruir usuário a registrar MFA em: https://aka.ms/mfasetup

# 3. Após registro, remover da exclusão
Remove-MgGroupMember -GroupId $groupId -DirectoryObjectId $userId
```

**Solução Preventiva:**
- Campanha de registro de MFA antes do rollout
- Comunicação clara sobre requisitos
- Portal de self-service para registro

### 3. API Calls Falhando

**Sintomas:**
- Chamadas API retornam 401 Unauthorized
- CLI do Databricks falha na autenticação

**Causa 3.1: Personal Access Token (PAT) sem MFA prévio**

**Diagnóstico:**
```bash
# Testar PAT
curl -H "Authorization: Bearer <PAT>" \
     https://<workspace-url>/api/2.0/clusters/list
```

**Solução:**
```
1. Fazer login interativo no UI Databricks (com MFA)
2. Então gerar novo PAT
3. Usar PAT em API calls subsequentes

Nota: PAT herda contexto de segurança do login inicial
```

**Causa 3.2: Service Principal sem configuração adequada**

**Diagnóstico:**
```powershell
# Verificar se SPN está na política
Get-MgServicePrincipal -Filter "displayName eq 'databricks-automation-sp'" |
    Select-Object DisplayName, Id, AppId
```

**Solução:**
```powershell
# Criar política separada para SPNs (sem MFA)
# Ou adicionar à exclusão da política de MFA de usuários

# Exemplo: Criar grupo de SPNs
New-MgGroup -DisplayName "Databricks-ServicePrincipals" -MailEnabled:$false -SecurityEnabled -MailNickname "databricks-spns"

# Adicionar SPN ao grupo
$groupId = (Get-MgGroup -Filter "displayName eq 'Databricks-ServicePrincipals'").Id
$spnId = (Get-MgServicePrincipal -Filter "displayName eq 'databricks-automation-sp'").Id
New-MgGroupMember -GroupId $groupId -DirectoryObjectId $spnId

# Excluir grupo da política MFA
```

### 4. Performance Degradada

**Sintomas:**
- Login muito lento (>30 segundos)
- Usuários reclamam de múltiplos desafios MFA

**Causa 4.1: Frequência de login muito agressiva**

**Diagnóstico:**
```kusto
SigninLogs
| where UserPrincipalName == "usuario@contoso.com"
| where AppDisplayName contains "Databricks"
| where TimeGenerated > ago(1d)
| where AuthenticationRequirement == "multiFactorAuthentication"
| summarize MFAChallenges = count() by bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

**Solução:**
```powershell
# Ajustar frequência de login na política
$policy = Get-MgIdentityConditionalAccessPolicy -Filter "displayName eq 'MFA-Obrigatório-Azure-Databricks'"

$params = @{
    SessionControls = @{
        SignInFrequency = @{
            Value = 8
            Type = "hours"
            IsEnabled = $true
        }
        PersistentBrowser = @{
            Mode = "always"
            IsEnabled = $true
        }
    }
}

Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -BodyParameter $params
```

**Causa 4.2: Problemas de rede/latência**

**Diagnóstico:**
```kusto
SigninLogs
| where AppDisplayName contains "Databricks"
| where TimeGenerated > ago(1h)
| extend DurationMs = todouble(DurationMs)
| summarize AvgDuration = avg(DurationMs), 
            MaxDuration = max(DurationMs),
            P95Duration = percentile(DurationMs, 95)
```

**Solução:**
- Verificar conectividade com `login.microsoftonline.com`
- Verificar proxy corporativo
- Considerar ExpressRoute ou VPN otimizada

### 5. Logs Não Aparecem

**Sintomas:**
- Queries Kusto não retornam resultados
- Dashboard de monitoramento vazio

**Causa 5.1: Diagnóstico não configurado**

**Diagnóstico:**
```powershell
# Verificar configuração de diagnóstico do Entra ID
Get-AzDiagnosticSetting -ResourceId "/providers/Microsoft.AADIAM/diagnosticSettings"
```

**Solução:**
```powershell
# Configurar envio de logs para Log Analytics
$logAnalyticsId = "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{workspace}"

Set-AzDiagnosticSetting `
    -ResourceId "/providers/Microsoft.AADIAM/diagnosticSettings" `
    -Name "EntraID-to-LogAnalytics" `
    -WorkspaceId $logAnalyticsId `
    -Enabled $true `
    -Category @("SignInLogs", "AuditLogs", "RiskyUsers")
```

**Causa 5.2: Latência de ingestão**

**Solução:**
- Logs podem levar 5-15 minutos para aparecer
- Para troubleshooting em tempo real, use portal Entra ID > Sign-ins

### 6. Usuários de Aplicações Legadas Bloqueados

**Sintomas:**
- Aplicações antigas que não suportam MFA param de funcionar
- Erro: "Authentication method not supported"

**Causa:**
- Aplicação usa autenticação legada (Basic Auth)

**Diagnóstico:**
```kusto
SigninLogs
| where AppDisplayName contains "Databricks"
| where ClientAppUsed != "Browser" and ClientAppUsed != "Mobile Apps and Desktop clients"
| project TimeGenerated, UserPrincipalName, ClientAppUsed, ResultType
```

**Solução:**
```powershell
# Opção 1: Bloquear autenticação legada (recomendado)
# Criar política específica para bloquear legacy auth

# Opção 2: Excluir temporariamente (não recomendado)
# Adicionar condição na política:
$params = @{
    Conditions = @{
        ClientAppTypes = @("browser", "mobileAppsAndDesktopClients")
    }
}

# Opção 3: Migrar app para autenticação moderna
# Atualizar aplicação para usar OAuth 2.0
```

## Diagnóstico de Problemas

### Checklist de Diagnóstico

Use este checklist ao investigar problemas:

```
[ ] 1. Coletar informações básicas
    [ ] UserPrincipalName do usuário afetado
    [ ] Timestamp do problema
    [ ] Mensagem de erro exata (screenshot se possível)
    [ ] Browser/dispositivo usado

[ ] 2. Verificar logs de signin
    [ ] Executar query Kusto para o usuário
    [ ] Identificar ResultType (0 = sucesso, outros = falha)
    [ ] Verificar ConditionalAccessStatus
    [ ] Verificar AuthenticationRequirement

[ ] 3. Verificar configuração da política
    [ ] Política está ativada?
    [ ] Usuário está nos assignments?
    [ ] Usuário não está nas exclusões?
    [ ] AppId está correto?

[ ] 4. Verificar registro MFA do usuário
    [ ] Usuário tem método MFA registrado?
    [ ] Método é compatível com dispositivo?
    [ ] Método está ativo/não bloqueado?

[ ] 5. Testar cenário
    [ ] Reproduzir problema em modo incógnito
    [ ] Testar com usuário diferente
    [ ] Testar em dispositivo diferente
```

### Query de Diagnóstico Completa

```kusto
// Query abrangente para troubleshooting
let usuario = "usuario@contoso.com";
let inicio = ago(24h);
SigninLogs
| where UserPrincipalName == usuario
| where TimeGenerated > inicio
| where AppDisplayName contains "Databricks"
| extend CAResult = tostring(parse_json(ConditionalAccessPolicies)[0].result)
| extend CAPolicy = tostring(parse_json(ConditionalAccessPolicies)[0].displayName)
| project 
    TimeGenerated,
    AppDisplayName,
    ResultType,
    ResultDescription,
    AuthenticationRequirement,
    MfaDetail = tostring(MfaDetail),
    CAPolicy,
    CAResult,
    IPAddress,
    Location,
    DeviceDetail = tostring(DeviceDetail),
    ClientAppUsed,
    Status = case(
        ResultType == 0, "✅ Sucesso",
        ResultType == 50074, "❌ MFA não registrado",
        ResultType == 50076, "⚠️ MFA requerido",
        ResultType == 50158, "❌ Política de segurança bloqueou",
        "❓ Outro erro"
    )
| order by TimeGenerated desc
```

## Soluções Detalhadas

### Criando Conta de Emergência (Break-Glass)

**Quando usar:**
- Emergências onde admin principal está bloqueado
- Disaster recovery
- Falha do sistema MFA

**Como criar:**

```powershell
# 1. Criar usuário de emergência
$passwordProfile = @{
    Password = "SuperSecurePassword123!@#"
    ForceChangePasswordNextSignIn = $false
}

New-MgUser `
    -DisplayName "Break Glass Admin" `
    -UserPrincipalName "breakglass@contoso.com" `
    -AccountEnabled `
    -PasswordProfile $passwordProfile `
    -MailNickname "breakglass"

# 2. Atribuir role de Global Admin
$roleId = (Get-MgDirectoryRole -Filter "displayName eq 'Global Administrator'").Id
$userId = (Get-MgUser -Filter "userPrincipalName eq 'breakglass@contoso.com'").Id

New-MgDirectoryRoleMember -DirectoryRoleId $roleId -DirectoryObjectId $userId

# 3. Criar grupo de exclusão
$group = New-MgGroup `
    -DisplayName "CA-Emergency-Exclusion" `
    -MailEnabled:$false `
    -SecurityEnabled `
    -MailNickname "ca-emergency"

# 4. Adicionar usuário ao grupo
New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $userId

# 5. Excluir grupo de TODAS as políticas CA
# Fazer manualmente no portal para cada política
```

**Importante:**
- Armazenar credenciais em cofre físico seguro
- Auditar uso regularmente
- Alertar em caso de uso

### Resolvendo Conflitos de Políticas

**Problema:**
Múltiplas políticas CA conflitantes causam comportamento inesperado

**Diagnóstico:**
```kusto
SigninLogs
| where UserPrincipalName == "usuario@contoso.com"
| where TimeGenerated > ago(1h)
| mv-expand ConditionalAccessPolicies
| project 
    TimeGenerated,
    PolicyName = tostring(ConditionalAccessPolicies.displayName),
    PolicyResult = tostring(ConditionalAccessPolicies.result),
    GrantControls = tostring(ConditionalAccessPolicies.enforcedGrantControls)
| order by TimeGenerated desc
```

**Solução:**
1. Documentar todas as políticas ativas
2. Identificar sobreposições
3. Consolidar políticas onde possível
4. Usar modo "Somente relatório" para testar mudanças

### Migrando de MFA do Databricks para CA

**Se você já usa MFA nativo do Databricks:**

```
Passo 1: Documentar configuração atual
  - Quais usuários têm MFA habilitado?
  - Métodos configurados?
  
Passo 2: Preparar CA
  - Criar política em modo "Somente relatório"
  - Testar com usuários piloto
  
Passo 3: Migração
  - Ativar política CA
  - Desabilitar MFA nativo Databricks (se aplicável)
  - Monitorar por 48h
  
Passo 4: Validação
  - Confirmar 100% dos logins com MFA
  - Coletar feedback dos usuários
```

## Ferramentas de Diagnóstico

### Script PowerShell: Diagnóstico Automático

```powershell
# Save as: Diagnose-DatabricksMFA.ps1

param(
    [Parameter(Mandatory=$true)]
    [string]$UserPrincipalName,
    
    [int]$HoursBack = 24
)

Connect-MgGraph -Scopes "AuditLog.Read.All", "Policy.Read.All", "User.Read.All"

Write-Host "🔍 Diagnóstico MFA Databricks" -ForegroundColor Cyan
Write-Host "Usuário: $UserPrincipalName" -ForegroundColor Yellow
Write-Host "Período: Últimas $HoursBack horas`n" -ForegroundColor Yellow

# 1. Verificar existência do usuário
Write-Host "1️⃣ Verificando usuário..." -ForegroundColor Green
$user = Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'"
if ($user) {
    Write-Host "✅ Usuário encontrado: $($user.DisplayName)" -ForegroundColor Green
    Write-Host "   ObjectId: $($user.Id)" -ForegroundColor Gray
} else {
    Write-Host "❌ Usuário não encontrado!" -ForegroundColor Red
    exit
}

# 2. Verificar métodos MFA registrados
Write-Host "`n2️⃣ Verificando métodos MFA..." -ForegroundColor Green
$authMethods = Get-MgUserAuthenticationMethod -UserId $user.Id
Write-Host "✅ Métodos registrados: $($authMethods.Count)" -ForegroundColor Green
foreach ($method in $authMethods) {
    Write-Host "   - $($method.AdditionalProperties.'@odata.type')" -ForegroundColor Gray
}

# 3. Verificar políticas CA aplicáveis
Write-Host "`n3️⃣ Verificando políticas CA..." -ForegroundColor Green
$policies = Get-MgIdentityConditionalAccessPolicy
$databricksPolicies = $policies | Where-Object {
    $_.Conditions.Applications.IncludeApplications -contains "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"
}
if ($databricksPolicies) {
    Write-Host "✅ Políticas encontradas: $($databricksPolicies.Count)" -ForegroundColor Green
    foreach ($policy in $databricksPolicies) {
        Write-Host "   - $($policy.DisplayName) [Estado: $($policy.State)]" -ForegroundColor Gray
    }
} else {
    Write-Host "⚠️ Nenhuma política CA para Databricks encontrada!" -ForegroundColor Yellow
}

# 4. Últimos logins (requer acesso a Log Analytics)
Write-Host "`n4️⃣ Verificando últimos logins..." -ForegroundColor Green
Write-Host "⚠️ Execute a seguinte query no Log Analytics:" -ForegroundColor Yellow
Write-Host @"
SigninLogs
| where UserPrincipalName == '$UserPrincipalName'
| where AppDisplayName contains 'Databricks'
| where TimeGenerated > ago($($HoursBack)h)
| project TimeGenerated, ResultType, AuthenticationRequirement, ConditionalAccessStatus
| order by TimeGenerated desc
"@ -ForegroundColor Cyan

Write-Host "`n✅ Diagnóstico concluído!" -ForegroundColor Green
```

### Dashboard Kusto: Visão Geral

```kusto
// Dashboard completo de monitoramento MFA Databricks
let periodo = ago(7d);
let app = "Databricks";

// KPI 1: Total de logins
let totalLogins = SigninLogs
    | where TimeGenerated > periodo
    | where AppDisplayName contains app
    | where ResultType == 0
    | count;

// KPI 2: Logins com MFA
let loginsComMFA = SigninLogs
    | where TimeGenerated > periodo
    | where AppDisplayName contains app
    | where ResultType == 0
    | where AuthenticationRequirement == "multiFactorAuthentication"
    | count;

// KPI 3: Taxa de falha MFA
let falhasMFA = SigninLogs
    | where TimeGenerated > periodo
    | where AppDisplayName contains app
    | where ResultType in (50074, 50076)
    | count;

// Exibir KPIs
print 
    TotalLogins = totalLogins,
    LoginsComMFA = loginsComMFA,
    TaxaMFA = (loginsComMFA * 100.0 / totalLogins),
    FalhasMFA = falhasMFA,
    TaxaFalha = (falhasMFA * 100.0 / (totalLogins + falhasMFA));

// Gráfico: Logins por dia
SigninLogs
| where TimeGenerated > periodo
| where AppDisplayName contains app
| where ResultType == 0
| summarize 
    Total = count(),
    ComMFA = countif(AuthenticationRequirement == "multiFactorAuthentication"),
    SemMFA = countif(AuthenticationRequirement != "multiFactorAuthentication")
    by bin(TimeGenerated, 1d)
| render timechart;

// Top usuários
SigninLogs
| where TimeGenerated > periodo
| where AppDisplayName contains app
| where ResultType == 0
| summarize Logins = count() by UserPrincipalName
| top 10 by Logins desc;
```

## Quando Escalar

### Nível 1: Auto-resolução

**Problemas que usuários podem resolver:**
- Registro de MFA
- Escolha de método MFA alternativo
- Limpeza de cache/cookies

**Recursos:**
- https://aka.ms/mfasetup
- FAQ interna
- Chatbot/knowledge base

### Nível 2: Suporte TI

**Problemas que suporte pode resolver:**
- Adicionar usuário a grupo de exclusão temporária
- Reset de métodos MFA
- Verificação de configuração de grupo

**SLA:** 2 horas

### Nível 3: Time de Identidade

**Problemas que requerem especialista:**
- Mudança em política CA
- Investigação de falhas sistemáticas
- Revisão de arquitetura

**SLA:** 1 dia útil

### Nível 4: Microsoft Support

**Quando abrir caso:**
- Problema no serviço Entra ID/MFA
- Bug confirmado
- Falha em múltiplos tenants

**Como abrir:**
```
Portal Azure > Help + Support > New support request
- Service: Azure Active Directory
- Problem type: Authentication
- Priority: A (production down) ou B (business impact)
```

## Referências

- [Entra ID Troubleshooting](https://docs.microsoft.com/azure/active-directory/fundamentals/active-directory-troubleshooting-support-howto)
- [CA Troubleshooting](https://docs.microsoft.com/azure/active-directory/conditional-access/troubleshoot-conditional-access)
- [Sign-in Error Codes](https://docs.microsoft.com/azure/active-directory/develop/reference-aadsts-error-codes)

---

**Última atualização:** 2025-11-06
