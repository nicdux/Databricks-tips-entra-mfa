# Convenções de Nomenclatura - Azure Databricks MFA

## Objetivo

Este documento estabelece convenções de nomenclatura para recursos relacionados à implementação de MFA no Azure Databricks, facilitando gestão, auditoria e troubleshooting.

## Políticas de Acesso Condicional

### Padrão de Nomenclatura

```
[TIPO]-[AÇÃO]-[APLICAÇÃO]-[CONTEXTO]
```

### Componentes

- **TIPO**: Categoria da política
  - `MFA` - Políticas de multi-factor authentication
  - `BLK` - Políticas de bloqueio
  - `MON` - Políticas em modo monitoramento
  - `DEV` - Políticas para desenvolvimento/teste
  
- **AÇÃO**: O que a política faz
  - `Obrigatório` - Exige algo
  - `Bloquear` - Bloqueia acesso
  - `Permitir` - Permite acesso condicional
  - `Auditar` - Apenas audita (modo relatório)
  
- **APLICAÇÃO**: Sistema alvo
  - `Azure-Databricks` - Azure Databricks
  - `Todos-Apps` - Todas as aplicações
  - `M365` - Microsoft 365
  
- **CONTEXTO**: Contexto adicional (opcional)
  - `Externo` - Acessos externos
  - `Interno` - Rede corporativa
  - `Producao` - Ambiente de produção
  - `Desenvolvimento` - Ambiente de dev/teste

### Exemplos

| Nome | Descrição |
|------|-----------|
| `MFA-Obrigatório-Azure-Databricks` | MFA obrigatório para Databricks (uso geral) |
| `MFA-Obrigatório-Azure-Databricks-Externo` | MFA obrigatório apenas para acessos externos |
| `MFA-Obrigatório-Azure-Databricks-Producao` | MFA para workspace de produção |
| `MON-MFA-Azure-Databricks-Piloto` | Política em modo relatório para teste |
| `BLK-LegacyAuth-Azure-Databricks` | Bloquear autenticação legada |

## Grupos de Segurança

### Padrão de Nomenclatura

```
[PREFIXO]-[PROPÓSITO]-[SISTEMA]
```

### Componentes

- **PREFIXO**: Tipo de grupo
  - `GRP-SEC` - Grupo de segurança
  - `GRP-DYN` - Grupo dinâmico
  - `GRP-M365` - Grupo Microsoft 365
  
- **PROPÓSITO**: Finalidade do grupo
  - `Databricks-Users` - Usuários do Databricks
  - `Databricks-Admins` - Administradores
  - `Databricks-DataEngineers` - Engenheiros de dados
  - `CA-Exclusion` - Exclusão de política CA
  - `BreakGlass` - Contas de emergência
  
- **SISTEMA**: Sistema relacionado
  - `Databricks` - Azure Databricks
  - `EntraID` - Microsoft Entra ID
  - `Azure` - Azure em geral

### Exemplos

| Nome | Descrição | Uso |
|------|-----------|-----|
| `GRP-SEC-Databricks-Users-Producao` | Usuários do Databricks produção | Atribuir à política CA |
| `GRP-SEC-CA-Exclusion-Databricks` | Exclusão temporária de MFA | Exceções temporárias |
| `GRP-SEC-BreakGlass-Global` | Contas break-glass | Emergências |
| `GRP-DYN-Databricks-LicenseHolders` | Usuários com licença Databricks | Provisionamento automático |
| `GRP-SEC-Databricks-DataScientists` | Cientistas de dados | RBAC no Databricks |

## Service Principals (SPNs)

### Padrão de Nomenclatura

```
spn-[ambiente]-[aplicacao]-[propósito]
```

### Componentes

- **ambiente**: Ambiente de execução
  - `prd` - Produção
  - `dev` - Desenvolvimento
  - `tst` - Teste
  - `hom` - Homologação
  
- **aplicacao**: Aplicação proprietária
  - `databricks` - Azure Databricks
  - `datafactory` - Azure Data Factory
  - `synapse` - Azure Synapse
  
- **propósito**: Finalidade do SPN
  - `automation` - Automação
  - `cicd` - CI/CD pipelines
  - `backup` - Backups
  - `monitoring` - Monitoramento

### Exemplos

| Nome | Descrição |
|------|-----------|
| `spn-prd-databricks-automation` | SPN para automação em produção |
| `spn-dev-databricks-cicd` | SPN para CI/CD em desenvolvimento |
| `spn-prd-databricks-backup` | SPN para backups automatizados |

## Workspaces do Log Analytics

### Padrão de Nomenclatura

```
law-[region]-[ambiente]-[propósito]
```

### Componentes

- **region**: Região Azure
  - `eastus` - East US
  - `brazilsouth` - Brazil South
  - `westeurope` - West Europe
  
- **ambiente**: Ambiente
  - `prd` - Produção
  - `nprd` - Não-produção
  
- **propósito**: Finalidade
  - `security` - Logs de segurança
  - `databricks` - Logs do Databricks
  - `general` - Logs gerais

### Exemplos

| Nome | Descrição |
|------|-----------|
| `law-brazilsouth-prd-security` | Workspace de logs de segurança (prod) |
| `law-eastus-prd-databricks` | Workspace específico para Databricks |

## Alertas do Azure Monitor

### Padrão de Nomenclatura

```
alert-[severidade]-[sistema]-[condicao]
```

### Componentes

- **severidade**: Severidade do alerta
  - `crit` - Crítico (Sev0)
  - `high` - Alto (Sev1)
  - `med` - Médio (Sev2)
  - `low` - Baixo (Sev3)
  
- **sistema**: Sistema monitorado
  - `databricks` - Azure Databricks
  - `ca` - Conditional Access
  - `mfa` - MFA
  
- **condicao**: Condição do alerta
  - `compliance-drop` - Queda de compliance
  - `mfa-failures` - Falhas de MFA
  - `no-mfa-detected` - Login sem MFA detectado

### Exemplos

| Nome | Descrição |
|------|-----------|
| `alert-crit-databricks-no-mfa-detected` | Login sem MFA no Databricks |
| `alert-high-mfa-compliance-drop` | Taxa MFA < 95% |
| `alert-med-databricks-mfa-failures` | Alto volume falhas MFA |

## Dashboards e Workbooks

### Padrão de Nomenclatura

```
[tipo]-[sistema]-[propósito]
```

### Componentes

- **tipo**: Tipo de visualização
  - `dash` - Dashboard
  - `wb` - Workbook
  - `report` - Relatório
  
- **sistema**: Sistema
  - `databricks` - Azure Databricks
  - `security` - Segurança
  - `compliance` - Compliance
  
- **propósito**: Finalidade
  - `mfa-compliance` - Compliance MFA
  - `signin-overview` - Visão geral de logins
  - `security-posture` - Postura de segurança

### Exemplos

| Nome | Descrição |
|------|-----------|
| `dash-databricks-mfa-compliance` | Dashboard de compliance MFA |
| `wb-security-signin-analysis` | Workbook de análise de logins |
| `report-databricks-monthly` | Relatório mensal automatizado |

## Runbooks e Scripts

### Padrão de Nomenclatura

```
[Verbo]-[Substantivo][Complemento].ps1
```

### Padrão PowerShell (PascalCase)

- **Verbo**: Use verbos aprovados do PowerShell
  - `Get-` - Obter informação
  - `Set-` - Configurar
  - `New-` - Criar
  - `Remove-` - Remover
  - `Test-` - Testar
  - `Export-` - Exportar
  - `Import-` - Importar
  
- **Substantivo**: Recurso manipulado
  - `DatabricksServicePrincipals`
  - `MFAEnforcement`
  - `ConditionalAccessPolicies`

### Exemplos

| Nome | Descrição |
|------|-----------|
| `Get-DatabricksServicePrincipals.ps1` | Listar SPNs Databricks |
| `Test-MFAEnforcement.ps1` | Testar enforcement MFA |
| `Export-ConditionalAccessPolicies.ps1` | Backup de políticas |
| `Set-DatabricksWorkspaceAccess.ps1` | Configurar acesso workspace |

## Arquivos de Configuração

### Padrão de Nomenclatura

```
[sistema]-[tipo]-[ambiente].[extensao]
```

### Exemplos

| Nome | Descrição |
|------|-----------|
| `databricks-mfa-policy-prod.json` | Política MFA produção |
| `databricks-workspace-config-dev.json` | Config workspace dev |
| `conditional-access-settings-backup.json` | Backup de settings |

## Tags Azure

### Tags Recomendadas

Aplicar em todos os recursos relacionados:

```json
{
  "Environment": "Production|Development|Test",
  "Project": "Databricks-MFA",
  "Owner": "email@contoso.com",
  "CostCenter": "IT-Security",
  "Compliance": "ISO27001|GDPR|LGPD",
  "DataClassification": "Confidential|Internal|Public",
  "BackupRequired": "Yes|No",
  "MaintenanceWindow": "Sunday-02:00-04:00"
}
```

### Exemplo de Aplicação

```powershell
$tags = @{
    "Environment" = "Production"
    "Project" = "Databricks-MFA"
    "Owner" = "security-team@contoso.com"
    "CostCenter" = "IT-Security"
    "Compliance" = "ISO27001,GDPR"
}

Set-AzResource -ResourceId $resourceId -Tag $tags -Force
```

## Documentação

### Padrão de Nomenclatura

```
[numero]-[topico]-[subtopico].md
```

### Exemplos

| Nome | Descrição |
|------|-----------|
| `01-guia-completo.md` | Guia principal |
| `02-arquitetura.md` | Documentação de arquitetura |
| `03-troubleshooting.md` | Guia de solução de problemas |
| `04-runbook-deployment.md` | Runbook de implantação |

## Queries Kusto

### Padrão de Nomenclatura

```
[propósito]-[metrica]-[sistema].kql
```

### Exemplos

| Nome | Descrição |
|------|-----------|
| `audit-mfa-compliance.kql` | Auditoria de compliance |
| `monitor-signin-failures.kql` | Monitorar falhas de login |
| `report-monthly-usage.kql` | Relatório de uso mensal |

## Checklist de Validação

Ao nomear recursos, valide:

- [ ] Nome é descritivo e autoexplicativo
- [ ] Segue o padrão estabelecido
- [ ] Não contém caracteres especiais não permitidos
- [ ] Comprimento está dentro dos limites do Azure
- [ ] Não usa abreviações não documentadas
- [ ] Inclui ambiente quando aplicável
- [ ] É consistente com outros recursos do mesmo tipo

## Referências

- [PowerShell Approved Verbs](https://docs.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
- [Azure Naming Conventions](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)
- [Conditional Access Best Practices](https://docs.microsoft.com/azure/active-directory/conditional-access/best-practices)

---

**Última atualização:** 2025-11-06
