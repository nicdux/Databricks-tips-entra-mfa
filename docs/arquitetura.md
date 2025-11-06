# Arquitetura da Solução MFA Azure Databricks

## Visão Geral da Arquitetura

Esta documentação detalha a arquitetura técnica da solução de MFA para Azure Databricks usando Microsoft Entra ID Conditional Access.

## Diagrama de Arquitetura

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Camada de Usuário                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ Browser  │  │  Jupyter │  │   CLI    │  │   API    │          │
│  │   UI     │  │ Notebook │  │  Tools   │  │ Clients  │          │
│  └─────┬────┘  └─────┬────┘  └─────┬────┘  └─────┬────┘          │
│        │             │              │              │                │
└────────┼─────────────┼──────────────┼──────────────┼────────────────┘
         │             │              │              │
         └─────────────┴──────────────┴──────────────┘
                              │
                              │ HTTPS / OAuth 2.0
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Microsoft Entra ID (Azure AD)                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │            Acesso Condicional (Conditional Access)         │   │
│  │                                                             │   │
│  │  ┌──────────────────────────────────────────────────────┐ │   │
│  │  │ Policy: MFA-Required-Databricks                      │ │   │
│  │  │                                                       │ │   │
│  │  │ Assignments:                                          │ │   │
│  │  │  • Users: All users / Specific groups                │ │   │
│  │  │  • Cloud apps: Azure Databricks                      │ │   │
│  │  │  • Conditions: All locations, devices, platforms     │ │   │
│  │  │                                                       │ │   │
│  │  │ Access Controls:                                      │ │   │
│  │  │  • Grant: Require MFA                                │ │   │
│  │  │  • Session: Sign-in frequency 8h                     │ │   │
│  │  └──────────────────────────────────────────────────────┘ │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │            MFA Methods                                     │   │
│  │  • Microsoft Authenticator (push notification)            │   │
│  │  • Phone call                                              │   │
│  │  • SMS text message                                        │   │
│  │  • OATH tokens (hardware/software)                         │   │
│  │  • FIDO2 security keys                                     │   │
│  │  • Windows Hello for Business                             │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │            Authentication Flow                             │   │
│  │  1. Receive authentication request                        │   │
│  │  2. Evaluate Conditional Access policies                  │   │
│  │  3. Challenge MFA if required                             │   │
│  │  4. Validate MFA response                                 │   │
│  │  5. Issue JWT token with claims                           │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                           │ JWT Token (with MFA claim)
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       Azure Databricks                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │            Control Plane                                   │   │
│  │  • Workspace Management                                    │   │
│  │  • User Authentication & Authorization                     │   │
│  │  • Notebook & Job Management                               │   │
│  │  • SCIM Provisioning                                       │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │            Data Plane                                      │   │
│  │  • Spark Clusters                                          │   │
│  │  • Data Processing                                         │   │
│  │  • Storage Access (ADLS, Blob, etc.)                       │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                           │ Audit Logs
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Monitoring & Audit                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │   Azure Monitor / Log Analytics                            │   │
│  │   • SigninLogs                                             │   │
│  │   • AuditLogs                                              │   │
│  │   • RiskyUsers                                             │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │   Microsoft Sentinel (SIEM)                                │   │
│  │   • Security Analytics                                     │   │
│  │   • Incident Management                                    │   │
│  │   • Automated Response                                     │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Fluxo de Autenticação Detalhado

### 1. Iniciação do Login

```
User                     Browser                   Entra ID               Databricks
  |                         |                          |                        |
  |---(1) Access Databricks-->                        |                        |
  |                         |                          |                        |
  |                         |---(2) Redirect to login----->                     |
  |                         |                          |                        |
  |                         |<---(3) Auth request------|                        |
```

**Detalhes técnicos:**
- Protocol: OAuth 2.0 / OpenID Connect
- Endpoint: `https://login.microsoftonline.com/{tenant}/oauth2/v2.0/authorize`
- Parameters:
  - `client_id`: Azure Databricks AppId
  - `response_type`: code
  - `scope`: openid profile email
  - `redirect_uri`: Databricks callback URL

### 2. Avaliação de Políticas

```
Entra ID Policy Engine
  |
  |---> Identify User
  |---> Check: Is app = Azure Databricks? (YES)
  |---> Check: Conditional Access Policies
  |       |
  |       |---> Policy: MFA-Required-Databricks
  |       |       |---> Assignments matched? (YES)
  |       |       |---> Access controls: Require MFA
  |       |
  |       |---> Check: MFA already done in session?
  |               |---> NO: Challenge MFA
  |               |---> YES: Skip challenge (if within frequency)
```

### 3. Desafio MFA

```
Entra ID                  User                    MFA Service
  |                         |                          |
  |---(4) MFA challenge---->|                          |
  |                         |                          |
  |                         |---(5) Choose method----->|
  |                         |                          |
  |                         |<---(6) Push notification-|
  |                         |                          |
  |                         |---(7) Approve---------->|
  |                         |                          |
  |<---(8) MFA success------|                          |
```

**Métodos MFA suportados:**

| Método | Tipo | Segurança | UX |
|--------|------|-----------|-----|
| Microsoft Authenticator | Push | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| FIDO2 | Hardware | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Windows Hello | Biometric | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| SMS | Text | ⭐⭐⭐ | ⭐⭐⭐ |
| Phone call | Voice | ⭐⭐⭐ | ⭐⭐ |

### 4. Emissão de Token

```
Entra ID
  |
  |---> Generate JWT Token
  |       |
  |       |---> Claims:
  |       |       • oid: User Object ID
  |       |       • upn: User Principal Name
  |       |       • amr: ["mfa", "pwd"]  ← MFA claim
  |       |       • iat: Issued at timestamp
  |       |       • exp: Expiration timestamp
  |       |
  |---> Sign token with private key
  |
  |---> Return to Databricks
```

**Estrutura do JWT:**

```json
{
  "header": {
    "alg": "RS256",
    "typ": "JWT",
    "kid": "key-id"
  },
  "payload": {
    "aud": "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d",
    "iss": "https://sts.windows.net/{tenant-id}/",
    "iat": 1699287600,
    "exp": 1699291200,
    "amr": ["mfa", "pwd"],
    "oid": "user-object-id",
    "upn": "user@contoso.com",
    "roles": [".."],
    "tid": "tenant-id"
  }
}
```

### 5. Validação e Acesso

```
Databricks
  |
  |---> Receive JWT token
  |---> Validate signature (public key from Entra ID)
  |---> Check expiration
  |---> Verify amr claim contains "mfa"
  |---> Extract user identity
  |---> Grant access to workspace
```

## Componentes Principais

### Microsoft Entra ID

**Responsabilidades:**
- Identity Provider (IdP)
- Policy Enforcement (Conditional Access)
- MFA Challenge & Validation
- Token Issuance
- Audit Logging

**Configurações críticas:**
```yaml
Tenant Settings:
  - MFA methods enabled: All recommended methods
  - Security defaults: Disabled (using CA policies)
  - Password protection: Enabled
  - Risk-based policies: Enabled (P2 only)

Conditional Access:
  - Baseline policies: Configured
  - MFA policies: Active
  - Device compliance: Optional
  - Location-based: Optional
```

### Azure Databricks

**Responsabilidades:**
- Workspace management
- Token validation
- User session management
- RBAC enforcement
- Audit logging

**Configurações críticas:**
```yaml
Workspace Settings:
  - Authentication: Entra ID (AAD)
  - SCIM provisioning: Enabled
  - Personal Access Tokens: Governed
  - IP Access Lists: Configured (optional)
  - Workspace access control: Enabled
```

### Monitoring & Audit

**Responsabilidades:**
- Log collection
- Security analytics
- Compliance reporting
- Incident response

**Logs coletados:**
```
Entra ID:
  - SigninLogs: All authentication attempts
  - AuditLogs: Configuration changes
  - RiskyUsers: Identity protection events

Databricks:
  - Cluster events
  - Job execution
  - Notebook access
  - Workspace activities
```

## Padrões de Segurança

### Defense in Depth

```
Layer 1: Network
  • IP whitelisting (optional)
  • Private Link (optional)
  • VNet injection

Layer 2: Identity
  • MFA (THIS SOLUTION)
  • Conditional Access
  • Identity Protection

Layer 3: Authorization
  • RBAC in Databricks
  • Table ACLs
  • Column-level security

Layer 4: Data
  • Encryption at rest
  • Encryption in transit
  • Key management (Azure Key Vault)

Layer 5: Monitoring
  • Log Analytics
  • Sentinel
  • Alerting
```

### Zero Trust Principles

1. **Verify explicitly**: MFA sempre, para todos
2. **Use least privilege access**: RBAC granular
3. **Assume breach**: Monitoramento contínuo

## Escalabilidade

### Performance Considerations

| Aspecto | Impacto | Mitigação |
|---------|---------|-----------|
| MFA challenge latency | +2-10s por login | Cache de sessão (8h) |
| Token validation | ~100ms por request | Token caching |
| Policy evaluation | ~50ms | Policy optimization |
| Audit log volume | Alto | Log retention policies |

### Capacidade

- **Usuários simultâneos**: Ilimitado (limitado apenas pelo Entra ID tenant)
- **Logins/minuto**: ~10,000 por tenant
- **Policies ativas**: Recomendado < 20 para performance

## Alta Disponibilidade

### SLAs

| Serviço | SLA | Observações |
|---------|-----|-------------|
| Microsoft Entra ID | 99.99% | Microsoft managed |
| Azure Databricks | 99.95% | Control plane |
| MFA Service | 99.9% | Microsoft managed |

### Failover Scenarios

```
Scenario 1: Entra ID regional outage
  → Microsoft automatic failover
  → Users may experience 2-5 min delay

Scenario 2: MFA service unavailable
  → Fallback to registered alternate method
  → Emergency access account available

Scenario 3: Databricks control plane outage
  → Running clusters continue
  → New logins blocked
  → Microsoft incident response
```

## Segurança

### Threat Model

| Ameaça | Mitigação | Residual Risk |
|--------|-----------|---------------|
| Credential theft | MFA required | Low (phishing MFA) |
| Session hijacking | Short session timeout | Low |
| MFA fatigue attack | Numberless MFA (Authenticator) | Medium |
| Insider threat | Audit logging, anomaly detection | Medium |
| Service account abuse | Separate CA policy, PAT governance | Low |

### Compliance Frameworks

Atende requisitos de:
- ✅ GDPR (Art. 32 - Security)
- ✅ LGPD (Art. 46 - Security measures)
- ✅ SOC 2 (CC6.1 - Logical access)
- ✅ ISO 27001 (A.9.4.2 - Secure authentication)
- ✅ NIST 800-63B (AAL2 - MFA required)
- ✅ PCI DSS (8.3 - MFA for remote access)

## Custos

### Estimativa de Custos Mensais

```
Licenciamento:
  - Entra ID P1: $6/user/month
  - Entra ID P2: $9/user/month (recomendado)
  - Azure Databricks: Baseado em uso (DBU)

Para 100 usuários:
  - Entra ID P2: $900/mês
  - Log Analytics (500GB): ~$250/mês
  - Total adicional: ~$1,150/mês

ROI:
  - Custo de breach evitado: ~$4.45M (média IBM)
  - Payback period: < 1 mês
```

## Referências Técnicas

- [Azure Databricks Security Architecture](https://docs.microsoft.com/azure/databricks/security/)
- [Entra ID Conditional Access Architecture](https://docs.microsoft.com/azure/active-directory/conditional-access/plan-conditional-access)
- [OAuth 2.0 Flow](https://oauth.net/2/)
- [JWT Specification](https://datatracker.ietf.org/doc/html/rfc7519)

---

**Última atualização:** 2025-11-06
