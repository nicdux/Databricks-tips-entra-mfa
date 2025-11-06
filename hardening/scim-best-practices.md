# Melhores Práticas SCIM - Azure Databricks

## Visão Geral

SCIM (System for Cross-domain Identity Management) é um protocolo padrão para automatizar o provisionamento e desprovisionamento de identidades de usuários. Este documento estabelece melhores práticas para implementar SCIM entre Microsoft Entra ID e Azure Databricks.

---

## 1. Benefícios do SCIM

### 1.1 Vantagens Operacionais

- ✅ **Provisionamento Automático**: Novos usuários são automaticamente adicionados ao Databricks
- ✅ **Desprovisionamento Automático**: Usuários que saem da empresa são removidos automaticamente
- ✅ **Sincronização de Grupos**: Grupos do Entra ID são sincronizados com Databricks
- ✅ **Redução de Erros**: Elimina processo manual propenso a erros
- ✅ **Auditoria**: Log completo de todas as mudanças de identidade
- ✅ **Compliance**: Garante que apenas funcionários ativos têm acesso

### 1.2 Cenários de Uso

```
Cenário 1: Onboarding
Novo funcionário contratado → Adicionado ao Entra ID → Automaticamente provisionado no Databricks

Cenário 2: Mudança de equipe
Usuário muda de departamento → Grupo atualizado no Entra ID → Permissões sincronizadas no Databricks

Cenário 3: Offboarding
Funcionário sai da empresa → Desabilitado no Entra ID → Removido do Databricks em minutos

Cenário 4: Licença Databricks
Licença atribuída no Entra ID → Usuário automaticamente provisionado → Sem intervenção manual
```

---

## 2. Pré-requisitos

### 2.1 Licenciamento

| Componente | Requisito |
|------------|-----------|
| **Microsoft Entra ID** | P1 ou P2 (para provisionamento automático) |
| **Azure Databricks** | Premium tier (SCIM requer Premium) |
| **Usuários** | Licenças Entra ID P1+ atribuídas |

### 2.2 Permissões Necessárias

**No Microsoft Entra ID:**
- Administrador de Aplicações ou Global Administrator

**No Azure Databricks:**
- Workspace Administrator

### 2.3 Configurações Prévias

- [ ] Workspace Databricks Premium criado
- [ ] Acesso administrativo ao Entra ID
- [ ] Grupos de usuários definidos
- [ ] Atribuição de licenças planejada

---

## 3. Implementação SCIM

### 3.1 Configuração no Azure Databricks

#### Passo 1: Habilitar SCIM no Workspace

```bash
# Via Databricks CLI
databricks workspace-conf set-status \
    -j '{"enableScim": true}'

# Verificar
databricks workspace-conf get-status enableScim
```

#### Passo 2: Gerar Token SCIM

No Databricks workspace:
1. Admin Settings > Service Principals
2. Ou: User Settings > Access Tokens
3. Generate New Token
4. Comment: "SCIM-EntraID-Provisioning"
5. Lifetime: Máximo (recomendado: 365 dias com rotação agendada)
6. **Copiar e armazenar o token com segurança!**

**Armazenamento seguro:**
```powershell
# Armazenar token SCIM no Azure Key Vault
az keyvault secret set `
    --vault-name myKeyVault `
    --name databricks-scim-token `
    --value "dapi123456789abcdef" `
    --description "SCIM provisioning token for Databricks"
```

#### Passo 3: Obter SCIM URL

```
SCIM URL format:
https://<workspace-instance>/api/2.0/preview/scim/v2

Exemplo:
https://adb-1234567890123456.azuredatabricks.net/api/2.0/preview/scim/v2
```

### 3.2 Configuração no Microsoft Entra ID

#### Passo 1: Adicionar Azure Databricks da Galeria

1. Acesse: Microsoft Entra ID > Enterprise Applications
2. Clique: New application
3. Busque: "Azure Databricks SCIM Provisioning Connector"
4. Selecione e clique: Create
5. Nome sugerido: "Azure Databricks - Production"

#### Passo 2: Configurar Provisionamento

1. Selecione a aplicação criada
2. Navegue: Provisioning > Get started
3. Provisioning Mode: **Automatic**
4. Admin Credentials:
   - **Tenant URL**: Cole a SCIM URL do Databricks
   - **Secret Token**: Cole o token SCIM gerado
5. Clique: Test Connection
6. Aguarde: "✅ The supplied credentials are authorized to enable provisioning"
7. Clique: Save

#### Passo 3: Configurar Mapeamentos de Atributos

**Mapeamento de Usuários (recomendado):**

| Atributo Entra ID | Atributo Databricks | Tipo | Obrigatório |
|-------------------|---------------------|------|-------------|
| userPrincipalName | userName | Direct | Sim |
| displayName | displayName | Direct | Sim |
| mail | emails[type eq "work"].value | Direct | Não |
| givenName | name.givenName | Direct | Não |
| surname | name.familyName | Direct | Não |
| Switch([IsSoftDeleted], , "False", "True", "True", "False") | active | Expression | Sim |

**Expressão para Active:**
```
Switch([IsSoftDeleted], , "False", "True", "True", "False")
```

**Mapeamento de Grupos (recomendado):**

| Atributo Entra ID | Atributo Databricks |
|-------------------|---------------------|
| displayName | displayName |
| members | members |
| objectId | externalId |

#### Passo 4: Definir Escopo de Provisionamento

**Opção A: Baseado em atribuição (recomendado para início)**
```
Settings > Scope: Sync only assigned users and groups
```

**Opção B: Sincronizar todos (para rollout completo)**
```
Settings > Scope: Sync all users and groups
```

#### Passo 5: Configurar Notificações

```
Settings > Notification Email: admin@contoso.com
```

Receba alertas para:
- Erros de provisionamento
- Falhas de sincronização
- Atingimento de threshold de erros

### 3.3 Atribuir Usuários e Grupos

#### Atribuição Manual

1. Aplicação > Users and groups > Add user/group
2. Selecionar usuários ou grupos
3. Assign

#### Atribuição via PowerShell

```powershell
# Atribuir grupo ao app Databricks
$spId = (Get-MgServicePrincipal -Filter "displayName eq 'Azure Databricks - Production'").Id
$groupId = (Get-MgGroup -Filter "displayName eq 'Databricks-Users'").Id

New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $spId `
    -PrincipalId $groupId `
    -PrincipalType "Group" `
    -AppRoleId "00000000-0000-0000-0000-000000000000"  # Default access
```

#### Atribuição Dinâmica (Entra ID P1+)

```powershell
# Criar grupo dinâmico para usuários com licença Databricks
$params = @{
    DisplayName = "Databricks-Users-Dynamic"
    MailEnabled = $false
    SecurityEnabled = $true
    MailNickname = "databricks-users-dyn"
    GroupTypes = @("DynamicMembership")
    # Nota: Substitua "databricks-service-plan-id" pelo Service Plan ID real
    # Para encontrar: Get-MgSubscribedSku | Where-Object {$_.SkuPartNumber -like "*Databricks*"} | Select-Object -ExpandProperty ServicePlans
    MembershipRule = '(user.assignedLicenses -any (x:x.servicePlanId -eq "databricks-service-plan-id"))'
    MembershipRuleProcessingState = "On"
}

New-MgGroup @params
```

### 3.4 Iniciar Provisionamento

#### Modo Inicial (Teste)

1. Provisioning > Start provisioning
2. Aguardar sincronização inicial (pode levar até 40 minutos)
3. Monitorar: Provisioning > Current cycle status

#### Validação

```powershell
# Verificar usuários provisionados no Databricks
$headers = @{
    "Authorization" = "Bearer $databricksToken"
}

$users = Invoke-RestMethod `
    -Uri "https://$workspaceUrl/api/2.0/preview/scim/v2/Users" `
    -Headers $headers

Write-Host "Total de usuários provisionados: $($users.totalResults)"
$users.Resources | Format-Table userName, displayName, active
```

---

## 4. Melhores Práticas

### 4.1 Estratégia de Grupos

#### Estrutura Recomendada

```
Grupos hierárquicos:
├── GRP-Databricks-All (todos os usuários)
│   ├── GRP-Databricks-Admins (administradores)
│   ├── GRP-Databricks-DataEngineers (engenheiros de dados)
│   ├── GRP-Databricks-DataScientists (cientistas de dados)
│   └── GRP-Databricks-Analysts (analistas)
```

#### Mapeamento de Permissões

| Grupo Entra ID | Permissões Databricks |
|----------------|----------------------|
| GRP-Databricks-Admins | Workspace Admin |
| GRP-Databricks-DataEngineers | Can Manage clusters, Can Restart |
| GRP-Databricks-DataScientists | Can Attach To, Can Restart |
| GRP-Databricks-Analysts | Can Attach To (Read-only) |

### 4.2 Ciclo de Vida do Usuário

#### Onboarding

```
Dia 0: Novo funcionário
  ↓
Entra ID: Criar conta
  ↓
Entra ID: Adicionar a grupo Databricks
  ↓
SCIM: Provisionar automaticamente (15-40 min)
  ↓
Databricks: Usuário ativo com permissões do grupo
  ↓
Notificação: Email de boas-vindas
```

**Script de onboarding:**

```powershell
# Onboard-DatabricksUser.ps1

param(
    [Parameter(Mandatory=$true)]
    [string]$UserPrincipalName,
    
    [Parameter(Mandatory=$true)]
    [string]$GroupName = "GRP-Databricks-Users"
)

# 1. Obter usuário
$user = Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'"

if (-not $user) {
    Write-Error "Usuário não encontrado no Entra ID"
    exit 1
}

# 2. Obter grupo
$group = Get-MgGroup -Filter "displayName eq '$GroupName'"

# 3. Adicionar usuário ao grupo
New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $user.Id

Write-Host "✅ Usuário adicionado ao grupo $GroupName"
Write-Host "⏳ SCIM irá provisionar em 15-40 minutos"
Write-Host ""
Write-Host "Para forçar sincronização imediata:"
Write-Host "   Portal Entra ID > Enterprise Apps > Azure Databricks > Provisioning > Provision on demand"
```

#### Offboarding

```
Dia de saída:
  ↓
Entra ID: Desabilitar conta (IsSoftDeleted = True)
  ↓
SCIM: Detectar mudança no próximo ciclo (40 min)
  ↓
Databricks: Usuário desabilitado (active = false)
  ↓
Após 30 dias: Entra ID deleta permanentemente
  ↓
SCIM: Remove usuário do Databricks
```

**Script de offboarding:**

```powershell
# Offboard-DatabricksUser.ps1

param(
    [Parameter(Mandatory=$true)]
    [string]$UserPrincipalName
)

# 1. Desabilitar usuário no Entra ID
$user = Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'"

Update-MgUser -UserId $user.Id -AccountEnabled:$false

Write-Host "✅ Usuário desabilitado no Entra ID"
Write-Host "⏳ SCIM irá desabilitar no Databricks em até 40 minutos"
Write-Host ""

# 2. Remover de grupos Databricks
$databricksGroups = Get-MgUserMemberOf -UserId $user.Id |
    Where-Object { $_.AdditionalProperties.displayName -like "*Databricks*" }

foreach ($group in $databricksGroups) {
    Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $user.Id
    Write-Host "   Removido de: $($group.AdditionalProperties.displayName)"
}

Write-Host ""
Write-Host "Para forçar sincronização imediata, force sync no portal Entra ID"
```

### 4.3 Sincronização On-Demand

**Quando usar:**
- Onboarding urgente
- Testar mapeamentos
- Troubleshooting

**Como fazer:**
1. Portal Entra ID > Enterprise Applications
2. Selecionar aplicação Databricks
3. Provisioning > Provision on demand
4. Selecionar usuário/grupo
5. Provision
6. Aguardar resultado (1-2 min)

### 4.4 Monitoramento de Provisionamento

#### Métricas Importantes

| Métrica | Target | Como medir |
|---------|--------|------------|
| Tempo de provisionamento | < 40 min | Logs de provisionamento |
| Taxa de sucesso | > 99% | Provisioning logs |
| Usuários órfãos | 0 | Audit Databricks vs Entra ID |
| Sincronização de grupos | 100% | Comparar memberships |

#### Query de Auditoria

```kusto
// Logs de provisionamento SCIM
AuditLogs
| where TargetResources[0].displayName == "Azure Databricks - Production"
| where Category == "Provisioning"
| where TimeGenerated > ago(7d)
| project 
    TimeGenerated,
    OperationName,
    Result,
    TargetUserPrincipalName = tostring(TargetResources[0].userPrincipalName),
    ErrorDetails = tostring(parse_json(tostring(AdditionalDetails[0].value)))
| order by TimeGenerated desc
```

---

## 5. Troubleshooting

### 5.1 Problemas Comuns

#### Problema: "Test Connection" falha

**Causas possíveis:**
- Token SCIM inválido
- Token expirado
- SCIM URL incorreta
- Firewall bloqueando

**Solução:**
```powershell
# Testar conexão SCIM manualmente
$headers = @{
    "Authorization" = "Bearer $scimToken"
}

Invoke-RestMethod `
    -Uri "https://$workspaceUrl/api/2.0/preview/scim/v2/Users?count=1" `
    -Headers $headers
```

#### Problema: Usuário não é provisionado

**Diagnóstico:**
1. Verificar se usuário está atribuído ao app
2. Verificar escopo de provisionamento
3. Verificar logs de provisionamento
4. Verificar mapeamento de atributos

**Query de diagnóstico:**
```kusto
AuditLogs
| where Category == "Provisioning"
| where TargetResources[0].userPrincipalName == "user@contoso.com"
| where TimeGenerated > ago(7d)
| project TimeGenerated, OperationName, Result, ResultReason
```

#### Problema: Grupo não sincroniza

**Causas:**
- Grupo não está atribuído ao app
- Mapeamento de grupo desabilitado
- Grupo vazio (sem membros)

**Solução:**
```powershell
# Verificar grupos provisionados
$headers = @{
    "Authorization" = "Bearer $databricksToken"
}

$groups = Invoke-RestMethod `
    -Uri "https://$workspaceUrl/api/2.0/preview/scim/v2/Groups" `
    -Headers $headers

$groups.Resources | Format-Table displayName, @{Name="Members";Expression={$_.members.Count}}
```

### 5.2 Logs de Provisionamento

**Acessar logs:**
1. Portal Entra ID
2. Enterprise Applications
3. Azure Databricks app
4. Provisioning > Provisioning logs

**Filtros úteis:**
- Status: Failed (para ver erros)
- Action: Create/Update/Delete
- Date range: Last 7 days

---

## 6. Segurança e Compliance

### 6.1 Segurança do Token SCIM

- [ ] Token armazenado em Azure Key Vault
- [ ] Acesso ao token restrito (RBAC)
- [ ] Rotação de token agendada (anualmente)
- [ ] Auditoria de uso do token
- [ ] Alerta de expiração configurado

**Rotação de token:**
```powershell
# 1. Gerar novo token no Databricks
# 2. Atualizar no Key Vault
az keyvault secret set `
    --vault-name myKeyVault `
    --name databricks-scim-token `
    --value "dapi-new-token-here"

# 3. Atualizar no Entra ID
# Portal > Enterprise Apps > Azure Databricks > Provisioning > Admin Credentials
# Cole novo token e Test Connection

# 4. Revogar token antigo no Databricks
```

### 6.2 Auditoria de Compliance

**Evidências para auditoria:**
- [ ] Logs de provisionamento (90 dias+)
- [ ] Logs de desprovisionamento
- [ ] Relatórios de sincronização
- [ ] Documentação de mapeamentos
- [ ] Política de SCIM documentada

**Controles de compliance:**

| Framework | Controle | Evidência |
|-----------|----------|-----------|
| ISO 27001 | A.9.2.1 - User registration | Logs SCIM de provisionamento |
| ISO 27001 | A.9.2.6 - Removal of access rights | Logs SCIM de desprovisionamento |
| SOC 2 | CC6.2 - Logical access | Relatórios de sincronização |
| GDPR | Art. 5(1)(d) - Accuracy | Sincronização automatizada |

---

## 7. Roadmap de Implementação

### Fase 1: Preparação (Semana 1)
- [ ] Verificar pré-requisitos
- [ ] Definir estrutura de grupos
- [ ] Criar grupos no Entra ID
- [ ] Documentar estratégia

### Fase 2: Configuração (Semana 2)
- [ ] Habilitar SCIM no Databricks
- [ ] Gerar token SCIM
- [ ] Configurar app no Entra ID
- [ ] Configurar mapeamentos

### Fase 3: Teste (Semana 3)
- [ ] Atribuir grupo piloto (5-10 usuários)
- [ ] Iniciar provisionamento
- [ ] Validar provisionamento de usuários
- [ ] Validar provisionamento de grupos
- [ ] Testar desprovisionamento

### Fase 4: Rollout (Semana 4)
- [ ] Atribuir todos os grupos
- [ ] Monitorar sincronização inicial
- [ ] Resolver erros
- [ ] Documentar processo

### Fase 5: Operação (Contínuo)
- [ ] Monitoramento diário de erros
- [ ] Auditoria mensal de sincronização
- [ ] Revisão trimestral de grupos
- [ ] Rotação anual de token

---

## 8. Referências

- [Databricks SCIM API](https://docs.databricks.com/dev-tools/api/latest/scim/index.html)
- [Entra ID Provisioning](https://docs.microsoft.com/azure/active-directory/app-provisioning/)
- [SCIM Protocol RFC](https://datatracker.ietf.org/doc/html/rfc7644)
- [Azure Databricks Admin Guide](https://docs.microsoft.com/azure/databricks/administration-guide/)

---

**Versão:** 1.0  
**Última atualização:** 2025-11-06  
**Owner:** Identity Team  
**Próxima revisão:** _______
