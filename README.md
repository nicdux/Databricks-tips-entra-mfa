# Databricks-tips-entra-mfa

Playbook prático para exigir MFA no Azure Databricks via Microsoft Entra ID (Acesso Condicional). Inclui guia passo a passo, consultas Kusto para auditoria, scripts Graph/PowerShell para descobrir todos os Enterprise Apps (SPNs) do Databricks, checklist de endurecimento (PATs, SCIM) e exemplos de políticas.

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Pré-requisitos](#pré-requisitos)
- [Como Aplicar MFA no Azure Databricks](#como-aplicar-mfa-no-azure-databricks)
- [Estrutura do Repositório](#estrutura-do-repositório)
- [Início Rápido](#início-rápido)
- [Contribuindo](#contribuindo)

## 🎯 Visão Geral

Este repositório fornece um guia completo para implementar Multi-Factor Authentication (MFA) no Azure Databricks usando **Acesso Condicional do Microsoft Entra ID** (anteriormente Azure AD). A solução garante que todos os usuários que acessam o Databricks sejam obrigados a usar MFA, aumentando significativamente a segurança do ambiente.

### Por que MFA no Databricks?

- **Proteção de Dados Sensíveis**: O Databricks frequentemente processa dados corporativos críticos
- **Conformidade Regulatória**: Atende requisitos de GDPR, LGPD, SOC2, e outros frameworks
- **Prevenção de Acesso Não Autorizado**: Reduz drasticamente o risco de credenciais comprometidas
- **Governança Corporativa**: Implementa políticas de segurança centralizadas

## ✅ Pré-requisitos

- **Azure Subscription** com permissões de administrador
- **Microsoft Entra ID P1 ou P2** (requerido para Acesso Condicional)
- **Azure Databricks Workspace** já provisionado
- **Permissões necessárias**:
  - Administrador de Acesso Condicional
  - Administrador de Aplicações (para SPNs)
  - Leitor de Logs (para auditoria)

## 🔐 Como Aplicar MFA no Azure Databricks

### Passo 1: Identificar Aplicações Databricks

Use os scripts PowerShell fornecidos para descobrir todos os Enterprise Applications (SPNs) relacionados ao Databricks:

```powershell
# Execute o script de inventário
.\powershell\Get-DatabricksServicePrincipals.ps1
```

### Passo 2: Criar Política de Acesso Condicional

1. Acesse o **Microsoft Entra ID** no portal do Azure
2. Navegue até **Segurança** > **Acesso Condicional**
3. Clique em **Nova política**
4. Configure conforme o template em `samples/conditional-access-policy.json`

**Configurações principais:**
- **Usuários**: Todos os usuários ou grupos específicos
- **Aplicações de nuvem**: Selecione o Azure Databricks (AppId: `2ff814a6-3304-4ab8-85cb-cd0e6f879c1d`)
- **Controles de concessão**: Exigir autenticação multifator
- **Estado**: Ativar após testes

### Passo 3: Testar a Política

1. Use o modo **Somente relatório** inicialmente
2. Monitore com as consultas Kusto em `kusto/signin-logs-queries.kql`
3. Valide que usuários de teste são desafiados com MFA
4. Ative a política em produção

### Passo 4: Auditoria Contínua

Use as consultas Kusto fornecidas para:
- Monitorar tentativas de login
- Identificar falhas de MFA
- Auditar acessos sem MFA (se houver exceções)

## 📁 Estrutura do Repositório

```
.
├── README.md                          # Este arquivo
├── docs/                              # Documentação detalhada
│   ├── guia-completo.md              # Guia passo a passo completo
│   ├── arquitetura.md                # Visão arquitetural da solução
│   └── troubleshooting.md            # Solução de problemas comuns
├── kusto/                            # Consultas KQL para auditoria
│   ├── signin-logs-queries.kql       # Queries para SigninLogs
│   └── audit-mfa-compliance.kql      # Verificação de compliance MFA
├── powershell/                       # Scripts PowerShell
│   ├── Get-DatabricksServicePrincipals.ps1  # Inventário de SPNs
│   ├── Export-ConditionalAccessPolicies.ps1 # Backup de políticas
│   └── Test-MFAEnforcement.ps1       # Teste de enforcement
├── samples/                          # Templates e exemplos
│   ├── conditional-access-policy.json # Template de política CA
│   ├── naming-conventions.md         # Convenções de nomenclatura
│   └── deployment-checklist.md       # Checklist de implantação
└── hardening/                        # Endurecimento de segurança
    ├── security-checklist.md         # Checklist de segurança
    ├── pat-governance.md             # Governança de PATs
    └── scim-best-practices.md        # Melhores práticas SCIM
```

## 🚀 Início Rápido

### 1. Clone o Repositório

```bash
git clone https://github.com/nicdux/Databricks-tips-entra-mfa.git
cd Databricks-tips-entra-mfa
```

### 2. Execute o Inventário de SPNs

```powershell
# Conecte-se ao Microsoft Graph
Connect-MgGraph -Scopes "Application.Read.All"

# Execute o script de inventário
.\powershell\Get-DatabricksServicePrincipals.ps1
```

### 3. Aplique a Política de Acesso Condicional

Siga o guia detalhado em `docs/guia-completo.md` para configurar a política passo a passo.

### 4. Configure Auditoria

Importe as consultas Kusto de `kusto/signin-logs-queries.kql` no Azure Log Analytics ou Microsoft Sentinel para monitoramento contínuo.

## 📊 Auditoria e Monitoramento

### Consultas Kusto Essenciais

```kusto
// Ver tentativas de login no Databricks
SigninLogs
| where AppDisplayName contains "Databricks"
| where TimeGenerated > ago(7d)
| project TimeGenerated, UserPrincipalName, AppDisplayName, 
          ResultType, AuthenticationRequirement, MfaDetail
```

Veja mais exemplos em `kusto/signin-logs-queries.kql`.

## 🛡️ Hardening e Governança

Além do MFA, implemente as seguintes medidas de segurança:

1. **Personal Access Tokens (PATs)**
   - Defina tempo máximo de vida
   - Audite PATs ativos regularmente
   - Veja `hardening/pat-governance.md`

2. **SCIM Provisioning**
   - Configure provisionamento automático
   - Implemente deprovisioning ao sair da empresa
   - Veja `hardening/scim-best-practices.md`

3. **Checklist de Segurança**
   - Revise todos os itens em `hardening/security-checklist.md`
   - Implemente controles progressivamente
   - Audite regularmente

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:

1. Fork o repositório
2. Crie uma branch para sua feature (`git checkout -b feature/NovaFuncionalidade`)
3. Commit suas mudanças (`git commit -m 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/NovaFuncionalidade`)
5. Abra um Pull Request

## 📝 Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais detalhes.

## 📞 Suporte

Para questões e suporte:
- Abra uma [Issue](https://github.com/nicdux/Databricks-tips-entra-mfa/issues)
- Consulte a [Documentação Oficial do Azure Databricks](https://docs.microsoft.com/azure/databricks/)
- Consulte a [Documentação do Microsoft Entra ID](https://docs.microsoft.com/azure/active-directory/)

---

**⚠️ Importante**: Sempre teste políticas de Acesso Condicional em modo "Somente relatório" antes de ativar em produção para evitar bloqueios acidentais de acesso.
