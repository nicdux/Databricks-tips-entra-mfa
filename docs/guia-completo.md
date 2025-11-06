# Guia Completo: MFA no Azure Databricks com Microsoft Entra ID

## Índice

1. [Introdução](#introdução)
2. [Arquitetura da Solução](#arquitetura-da-solução)
3. [Pré-requisitos Detalhados](#pré-requisitos-detalhados)
4. [Passo a Passo Completo](#passo-a-passo-completo)
5. [Testes e Validação](#testes-e-validação)
6. [Monitoramento e Auditoria](#monitoramento-e-auditoria)
7. [Troubleshooting](#troubleshooting)

## Introdução

Este guia fornece instruções detalhadas para implementar Multi-Factor Authentication (MFA) obrigatório no Azure Databricks usando o Acesso Condicional do Microsoft Entra ID.

### Objetivo

Garantir que todos os usuários que acessam o Azure Databricks sejam obrigados a usar MFA, independentemente de:
- Local de acesso (escritório, home office, etc.)
- Dispositivo utilizado
- Método de autenticação (UI, API, notebooks)

### Benefícios

- **Segurança Aprimorada**: Proteção contra credenciais comprometidas
- **Conformidade**: Atende requisitos de GDPR, LGPD, SOC2, ISO 27001
- **Centralização**: Política gerenciada centralmente no Entra ID
- **Auditoria**: Logs completos de todas as tentativas de acesso
- **Flexibilidade**: Suporte a múltiplos métodos MFA (SMS, app, token)

## Arquitetura da Solução

```
┌─────────────────┐
│   Usuário       │
│   (Browser)     │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│  Microsoft Entra ID         │
│  ┌─────────────────────┐   │
│  │ Acesso Condicional  │   │
│  │ - Requer MFA        │   │
│  │ - App: Databricks   │   │
│  └─────────────────────┘   │
└────────┬────────────────────┘
         │
         ▼ (Token JWT)
┌─────────────────────────────┐
│  Azure Databricks           │
│  - Workspace                │
│  - Clusters                 │
│  - Notebooks                │
└─────────────────────────────┘
```

### Fluxo de Autenticação

1. **Usuário tenta acessar Databricks**
2. **Redirecionamento para Entra ID** (OAuth 2.0)
3. **Avaliação da Política de Acesso Condicional**:
   - Verifica se o app é Azure Databricks
   - Verifica se o usuário já fez MFA na sessão
4. **Desafio MFA** (se necessário):
   - SMS, chamada telefônica
   - Microsoft Authenticator
   - FIDO2, Windows Hello
5. **Emissão de Token**: JWT com claim MFA
6. **Acesso concedido** ao Databricks

## Pré-requisitos Detalhados

### Licenciamento

| Componente | Licença Necessária | Notas |
|------------|-------------------|-------|
| Microsoft Entra ID | P1 ou P2 | P2 recomendado para recursos avançados |
| Azure Databricks | Standard ou Premium | Premium recomendado para SCIM |
| Microsoft 365 | E3 ou E5 | Opcional, para integração completa |

### Permissões Necessárias

#### No Microsoft Entra ID

```
Roles necessárias:
- Administrador de Acesso Condicional (criar políticas)
- Administrador de Aplicações de Nuvem (configurar SPNs)
- Leitor de Segurança (mínimo para visualização)
```

#### No Azure

```
Roles necessárias:
- Contributor na subscription do Databricks
- Leitor de Logs (para auditoria)
```

### Configurações Prévias

1. **Métodos MFA Habilitados** para usuários:
   ```
   Portal Entra ID > Segurança > Métodos de autenticação
   - Microsoft Authenticator (recomendado)
   - SMS
   - Chamada telefônica
   - FIDO2 (opcional)
   ```

2. **Registro MFA** dos usuários:
   - Inicie campanha de registro: https://aka.ms/mfasetup
   - Monitore status em: Entra ID > Usuários > Métodos de autenticação

## Passo a Passo Completo

### Fase 1: Descoberta e Inventário

#### 1.1 Identificar Aplicações Databricks

Execute o script PowerShell para descobrir todos os SPNs:

```powershell
# Conectar ao Microsoft Graph
Connect-MgGraph -Scopes "Application.Read.All", "Directory.Read.All"

# Executar script de inventário
.\powershell\Get-DatabricksServicePrincipals.ps1 -ExportPath ".\databricks-apps.csv"
```

**Output esperado:**
```
DisplayName: Azure Databricks
AppId: 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d
ObjectId: xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

#### 1.2 Documentar Aplicações Enterprise Personalizadas

Se você tem aplicações Databricks customizadas (multi-workspace):

```powershell
Get-MgServicePrincipal -Filter "startswith(displayName,'Databricks')" | 
    Select-Object DisplayName, AppId, Id | 
    Export-Csv -Path "databricks-custom-apps.csv"
```

### Fase 2: Criar Política de Acesso Condicional

#### 2.1 Acessar Portal Entra ID

1. Acesse: https://entra.microsoft.com
2. Navegue: **Proteção** > **Acesso Condicional** > **Políticas**
3. Clique: **+ Nova política**

#### 2.2 Configurar Atribuições

**Nome da Política:**
```
MFA-Obrigatório-Azure-Databricks
```

**Usuários:**
```
- Incluir: Todos os usuários
  OU
- Incluir: Grupo específico (ex: "Databricks-Users")

- Excluir: 
  - Conta de emergência (break-glass)
  - Contas de serviço (se aplicável)
```

**Aplicativos de Nuvem:**
```
- Selecionar aplicativos
- Pesquisar: "Azure Databricks"
- Marcar: Azure Databricks (AppId: 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d)
```

Se você tem workspaces personalizados, adicione também:
```
- Selecionar aplicativos
- Adicionar todos os AppIds identificados na Fase 1.2
```

**Condições:**
```
- Locais: Qualquer local (recomendado)
  OU
- Locais: 
  - Incluir: Qualquer local
  - Excluir: Rede corporativa (opcional, menos seguro)

- Dispositivos: Todos os dispositivos
- Plataformas: Todas as plataformas
```

#### 2.3 Configurar Controles de Acesso

**Concessão:**
```
☑ Conceder acesso
☑ Exigir autenticação multifator
☑ Exigir dispositivo em conformidade (opcional, recomendado)

Relação: Exigir todos os controles selecionados
```

**Sessão:**
```
- Frequência de entrada: 
  ☑ Toda vez (mais seguro)
  OU
  ☑ A cada 8 horas (balance segurança/experiência)

- Sessão de navegador persistente: 
  ☐ Não manter sessão persistente
```

#### 2.4 Ativar Política em Modo Teste

**IMPORTANTE:** Comece sempre em modo teste!

```
Estado da política: Somente relatório
```

Clique **Criar**.

### Fase 3: Teste e Validação

#### 3.1 Teste com Usuários Piloto

1. **Criar grupo de teste:**
   ```
   Nome: Databricks-MFA-Pilot
   Membros: 3-5 usuários de diferentes equipes
   ```

2. **Modificar política** para incluir apenas grupo piloto:
   ```
   Usuários > Incluir > Selecionar grupos > Databricks-MFA-Pilot
   ```

3. **Ativar política:**
   ```
   Estado: Ativado
   ```

#### 3.2 Cenários de Teste

| Cenário | Esperado | Como Testar |
|---------|----------|-------------|
| Login UI Databricks | Desafio MFA | Acesse workspace.databricks.com |
| API Databricks | Token com MFA | Use Databricks CLI |
| Notebook execution | MFA não solicitado novamente | Execute notebook |
| Token expirado | Novo desafio MFA | Espere timeout da sessão |

#### 3.3 Monitorar com Kusto

Use a consulta para monitorar logins de teste:

```kusto
SigninLogs
| where AppDisplayName contains "Databricks"
| where UserPrincipalName in ("piloto1@contoso.com", "piloto2@contoso.com")
| where TimeGenerated > ago(1h)
| project TimeGenerated, UserPrincipalName, ResultType, 
          AuthenticationRequirement, ConditionalAccessStatus, MfaDetail
| order by TimeGenerated desc
```

#### 3.4 Validar Resultados

**Sucesso esperado:**
- `ResultType` = 0 (sucesso)
- `AuthenticationRequirement` = "multiFactorAuthentication"
- `ConditionalAccessStatus` = "success"
- `MfaDetail` contém método usado

**Coletar Feedback:**
- Experiência do usuário
- Tempo para completar MFA
- Problemas encontrados

### Fase 4: Rollout Produção

#### 4.1 Planejar Rollout

**Opção 1: Rollout por Grupos**
```
Semana 1: Equipe TI (10 usuários)
Semana 2: Equipe Data Engineering (50 usuários)
Semana 3: Equipe Analytics (100 usuários)
Semana 4: Todos os usuários (500+ usuários)
```

**Opção 2: Big Bang**
```
Data: [Definir data]
Horário: Fora do horário de pico
Comunicação: 2 semanas de antecedência
```

#### 4.2 Comunicação aos Usuários

**Email template (2 semanas antes):**

```
Assunto: [AÇÃO NECESSÁRIA] MFA será obrigatório no Azure Databricks

Prezados,

A partir de [DATA], será obrigatório o uso de Multi-Factor Authentication (MFA) 
para acessar o Azure Databricks.

O QUE VOCÊ PRECISA FAZER:
1. Registrar método MFA: https://aka.ms/mfasetup
2. Recomendamos o Microsoft Authenticator

O QUE ESPERAR:
- Ao acessar Databricks, você será solicitado a fornecer segundo fator
- Isso acontecerá uma vez por sessão de 8 horas

SUPORTE:
- Email: suporte@contoso.com
- FAQ: https://wiki.contoso.com/databricks-mfa

Obrigado,
Equipe de Segurança
```

#### 4.3 Ativar Política Produção

1. **Modificar política** para incluir todos os usuários:
   ```
   Usuários > Incluir > Todos os usuários
   Usuários > Excluir > Conta break-glass
   ```

2. **Revisar todas as configurações**

3. **Ativar:**
   ```
   Estado: Ativado
   ```

4. **Documentar:**
   - Data/hora de ativação
   - Configuração aplicada
   - Responsável pela ativação

### Fase 5: Monitoramento Pós-Implantação

#### 5.1 Primeiras 24 horas

**Dashboard de Monitoramento:**

```kusto
// Acessos com e sem MFA - Últimas 24h
SigninLogs
| where AppDisplayName contains "Databricks"
| where TimeGenerated > ago(24h)
| summarize 
    TotalLogins = count(),
    ComMFA = countif(AuthenticationRequirement == "multiFactorAuthentication"),
    SemMFA = countif(AuthenticationRequirement != "multiFactorAuthentication"),
    Falhas = countif(ResultType != 0)
| extend PercentualMFA = (ComMFA * 100.0) / TotalLogins
```

**Meta:** 100% dos logins com MFA

#### 5.2 Primeira Semana

**Monitorar:**
- Tickets de suporte relacionados
- Falhas de autenticação
- Usuários que não registraram MFA

**Query para usuários sem MFA registrado:**

```kusto
SigninLogs
| where AppDisplayName contains "Databricks"
| where TimeGenerated > ago(7d)
| where ResultType != 0
| where ResultDescription contains "MFA"
| summarize Tentativas = count() by UserPrincipalName
| order by Tentativas desc
```

#### 5.3 Monitoramento Contínuo

**Criar Alertas:**

1. **Alerta: Alto volume de falhas MFA**
   ```kusto
   SigninLogs
   | where AppDisplayName contains "Databricks"
   | where TimeGenerated > ago(1h)
   | where ResultType != 0
   | where ResultDescription contains "MFA"
   | summarize Falhas = count()
   | where Falhas > 10
   ```

2. **Alerta: Acesso sem MFA detectado**
   ```kusto
   SigninLogs
   | where AppDisplayName contains "Databricks"
   | where TimeGenerated > ago(5m)
   | where ResultType == 0
   | where AuthenticationRequirement != "multiFactorAuthentication"
   ```

## Testes e Validação

### Checklist de Validação

- [ ] Política criada em modo "Somente relatório"
- [ ] Teste com grupo piloto realizado
- [ ] 100% dos testes piloto tiveram MFA desafiado
- [ ] Feedback dos usuários piloto coletado
- [ ] Comunicação enviada para todos os usuários
- [ ] Suporte preparado com documentação
- [ ] Queries de monitoramento configuradas
- [ ] Alertas configurados
- [ ] Política ativada em produção
- [ ] Monitoramento 24h realizado
- [ ] Documentação atualizada

### Casos de Teste

| ID | Cenário | Pré-condição | Ação | Resultado Esperado |
|----|---------|--------------|------|-------------------|
| T01 | Login primeiro acesso | Usuário sem MFA ativo | Login no Databricks | Desafio MFA apresentado |
| T02 | Login com MFA registrado | MFA já configurado | Login no Databricks | Desafio MFA, acesso concedido |
| T03 | Acesso via API | Token válido, MFA feito | API call | Sucesso |
| T04 | Sessão expirada | Sessão > 8h | Tentar acessar workspace | Novo desafio MFA |
| T05 | Usuário excluído | Usuário em grupo de exclusão | Login no Databricks | MFA não solicitado |

## Monitoramento e Auditoria

### KPIs Principais

1. **Taxa de Compliance MFA:**
   ```
   (Logins com MFA / Total de Logins) * 100
   Meta: 100%
   ```

2. **Tempo Médio de Autenticação:**
   ```
   Média do tempo entre redirect e token emission
   Meta: < 30 segundos
   ```

3. **Taxa de Falha MFA:**
   ```
   (Falhas MFA / Total de tentativas MFA) * 100
   Meta: < 5%
   ```

### Relatórios Regulares

**Relatório Semanal:**
- Total de acessos ao Databricks
- Percentual com MFA
- Top 10 usuários por número de acessos
- Incidentes de segurança

**Relatório Mensal:**
- Tendência de adoção
- Métodos MFA mais usados
- Compliance por departamento
- Recomendações de melhoria

## Troubleshooting

### Problema: Usuário não recebe desafio MFA

**Causas possíveis:**
1. Política não está ativada
2. Usuário está no grupo de exclusão
3. Sessão MFA ainda válida
4. AppId incorreto na política

**Solução:**
```kusto
// Verificar política aplicada
SigninLogs
| where UserPrincipalName == "usuario@contoso.com"
| where AppDisplayName contains "Databricks"
| project TimeGenerated, ConditionalAccessPolicies
```

### Problema: Usuário bloqueado por não ter MFA

**Causas:**
- Usuário não registrou método MFA

**Solução imediata:**
1. Adicionar usuário temporariamente ao grupo de exclusão
2. Instruir registro de MFA
3. Remover da exclusão

**Solução permanente:**
- Campanha de registro antes do rollout

### Problema: API calls falhando

**Causas:**
- Personal Access Token (PAT) usado sem MFA interativo prévio
- Service Principal sem configuração adequada

**Solução:**
```
Para usuários:
1. Login interativo no UI primeiro (com MFA)
2. Depois use PAT/API

Para service principals:
1. Crie política separada
2. Exclua SPNs da política MFA usuários
```

### Problema: Performance degradada

**Causas:**
- Desafios MFA muito frequentes
- Timeout de sessão muito curto

**Solução:**
- Ajustar frequência de login na política
- Aumentar de "toda vez" para "8 horas"
- Habilitar "sessão persistente" em navegadores

## Próximos Passos

Após implementar MFA, considere:

1. **Acesso Condicional Baseado em Risco**
   - Entra ID P2 required
   - MFA adaptativo baseado em comportamento

2. **Dispositivos Gerenciados**
   - Exigir dispositivos compliant (Intune)
   - Aumenta segurança significativamente

3. **Governança de PATs**
   - Implementar políticas de expiração
   - Auditar PATs regularmente
   - Ver `hardening/pat-governance.md`

4. **SCIM Provisioning**
   - Provisionamento automático de usuários
   - Deprovisioning ao sair da empresa
   - Ver `hardening/scim-best-practices.md`

## Referências

- [Azure Databricks - Security & Compliance](https://docs.microsoft.com/azure/databricks/security/)
- [Microsoft Entra Conditional Access](https://docs.microsoft.com/azure/active-directory/conditional-access/)
- [MFA Best Practices](https://docs.microsoft.com/azure/active-directory/authentication/concept-mfa-howitworks)
- [Kusto Query Language](https://docs.microsoft.com/azure/data-explorer/kusto/query/)

---

**Última atualização:** 2025-11-06
