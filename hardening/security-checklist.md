# Checklist de Segurança - Azure Databricks com MFA

## Visão Geral

Este checklist abrangente cobre todos os aspectos de segurança para uma implementação robusta do Azure Databricks com MFA obrigatório via Microsoft Entra ID.

---

## 1. Autenticação e Identidade

### 1.1 Multi-Factor Authentication (MFA)

- [ ] MFA obrigatório via Acesso Condicional configurado
- [ ] Taxa de compliance MFA: 100%
- [ ] Métodos MFA seguros habilitados:
  - [ ] Microsoft Authenticator (push notification)
  - [ ] FIDO2 security keys
  - [ ] Windows Hello for Business
- [ ] Métodos MFA fracos desabilitados/desencorajados:
  - [ ] SMS (permitido apenas como backup)
  - [ ] Chamada telefônica (permitido apenas como backup)
- [ ] Políticas de registro MFA configuradas
- [ ] Campanhas de registro MFA realizadas
- [ ] Numberless MFA configurado (anti-fatigue)

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 1.2 Acesso Condicional

- [ ] Política MFA para Databricks ativa
- [ ] Política testada em modo "Somente relatório" antes de ativar
- [ ] Grupo de exclusão break-glass configurado
- [ ] Contas break-glass documentadas e testadas
- [ ] Políticas para bloquear autenticação legada
- [ ] Políticas baseadas em localização (se aplicável)
- [ ] Políticas baseadas em risco configuradas (Entra ID P2)
- [ ] Frequência de signin configurada (8h recomendado)
- [ ] Persistência de sessão configurada adequadamente

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 1.3 Gestão de Identidades

- [ ] SCIM provisioning configurado para sync automático
- [ ] Deprovisioning automático ao sair da empresa
- [ ] Revisão de acesso trimestral configurada
- [ ] Grupos de segurança bem definidos
- [ ] Separação de privilégios (usuários vs admins)
- [ ] Service Principals documentados
- [ ] Rotação de credenciais de SPNs agendada

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

---

## 2. Controle de Acesso e Autorização

### 2.1 RBAC no Databricks

- [ ] Workspace Access Control habilitado
- [ ] Roles personalizadas definidas conforme princípio de menor privilégio
- [ ] Usuários admin limitados (máximo 5)
- [ ] Table Access Control (Premium tier) habilitado
- [ ] Column-level security implementado para dados sensíveis
- [ ] Row-level security implementado onde necessário
- [ ] Revisão trimestral de permissões

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 2.2 Personal Access Tokens (PATs)

- [ ] Tempo máximo de vida configurado (≤ 90 dias)
- [ ] Política de expiração forçada
- [ ] Auditoria regular de PATs ativos
- [ ] Processo de revogação de PATs ao sair da empresa
- [ ] Proibição de compartilhamento de PATs
- [ ] PATs armazenados em Key Vault (não em código)
- [ ] Alertas para PATs próximos da expiração
- [ ] Documentação de uso apropriado de PATs

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 2.3 Secrets Management

- [ ] Azure Key Vault integrado ao Databricks
- [ ] Secret scopes configurados
- [ ] ACLs em secret scopes definidas
- [ ] Sem credenciais hardcoded em notebooks
- [ ] Sem credenciais em variáveis de ambiente não seguras
- [ ] Rotação automática de secrets configurada
- [ ] Auditoria de acesso a secrets habilitada

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

---

## 3. Segurança de Rede

### 3.1 Isolamento de Rede

- [ ] VNet injection implementado (recomendado)
- [ ] Network Security Groups (NSGs) configurados
- [ ] Regras de firewall definidas
- [ ] Azure Private Link configurado (opcional, maior segurança)
- [ ] IP Access Lists configuradas no Databricks
- [ ] Acesso público desabilitado (se possível)
- [ ] Conexões apenas via ExpressRoute/VPN (se aplicável)

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 3.2 Conectividade Segura

- [ ] TLS 1.2 ou superior enforçado
- [ ] Certificados válidos e atualizados
- [ ] HTTPS obrigatório para todas as comunicações
- [ ] Websockets seguros (WSS) para notebooks
- [ ] Conexões ao storage criptografadas
- [ ] Cluster-to-cluster encryption habilitado

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

---

## 4. Proteção de Dados

### 4.1 Criptografia

- [ ] Encryption at rest habilitado em todos os storages
- [ ] Customer-managed keys (CMK) configurado (recomendado)
- [ ] Encryption in transit habilitado
- [ ] DBFS encryption habilitado
- [ ] Managed disks encryption habilitado
- [ ] Azure Key Vault para gestão de chaves
- [ ] Rotação de chaves agendada

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 4.2 Classificação de Dados

- [ ] Data classification scheme definido
- [ ] Tags aplicadas a dados sensíveis
- [ ] Políticas DLP configuradas (se aplicável)
- [ ] Dados PII identificados e protegidos
- [ ] Mascaramento de dados em ambientes não-produção
- [ ] Segregação de dados por sensibilidade

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 4.3 Backup e Recovery

- [ ] Backup regular de workspaces configurado
- [ ] Backup de notebooks em Git/Azure DevOps
- [ ] Backup de configurações de cluster
- [ ] Backup de secret scopes documentado
- [ ] RPO e RTO definidos
- [ ] Disaster recovery plan testado anualmente
- [ ] Geo-redundância configurada (se necessário)

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

---

## 5. Auditoria e Monitoramento

### 5.1 Logging

- [ ] Diagnostic settings configurado para Entra ID
- [ ] SigninLogs enviados para Log Analytics
- [ ] AuditLogs enviados para Log Analytics
- [ ] Databricks workspace logs habilitados
- [ ] Cluster logs capturados
- [ ] Job execution logs retidos
- [ ] Retenção de logs: mínimo 90 dias (1 ano recomendado)

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 5.2 Monitoramento de Segurança

- [ ] Azure Monitor configurado
- [ ] Microsoft Sentinel integrado (SIEM)
- [ ] Alertas de segurança críticos configurados:
  - [ ] Login sem MFA
  - [ ] Uso de conta break-glass
  - [ ] Múltiplas falhas MFA
  - [ ] Acesso de localização anômala
  - [ ] Mudanças em políticas CA
- [ ] Dashboard de segurança configurado
- [ ] Workbooks de análise criados

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 5.3 Compliance e Auditoria

- [ ] Queries Kusto de compliance configuradas
- [ ] Relatórios automáticos agendados
- [ ] KPIs de segurança definidos e monitorados
- [ ] Evidências para auditoria coletadas
- [ ] Compliance dashboards criados
- [ ] Revisão trimestral de compliance
- [ ] Documentação de controles mantida atualizada

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

---

## 6. Governança e Compliance

### 6.1 Políticas e Procedimentos

- [ ] Política de uso aceitável documentada
- [ ] Política de classificação de dados publicada
- [ ] Procedimento de onboarding de usuários definido
- [ ] Procedimento de offboarding de usuários definido
- [ ] Procedimento de resposta a incidentes definido
- [ ] Runbooks operacionais criados
- [ ] Processo de change management estabelecido

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 6.2 Compliance Regulatório

- [ ] GDPR compliance validado (se aplicável)
- [ ] LGPD compliance validado (se aplicável)
- [ ] ISO 27001 controles mapeados
- [ ] SOC 2 requisitos atendidos
- [ ] HIPAA compliance (se aplicável)
- [ ] PCI DSS compliance (se aplicável)
- [ ] NIST framework mapeado
- [ ] Documentação de compliance mantida

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 6.3 Treinamento e Awareness

- [ ] Treinamento de segurança para todos os usuários
- [ ] Treinamento avançado para administradores
- [ ] Conscientização sobre phishing e MFA fatigue
- [ ] Documentação de boas práticas publicada
- [ ] Sessões de atualização regulares
- [ ] Simulações de phishing (opcional)

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

---

## 7. Gestão de Vulnerabilidades

### 7.1 Patch Management

- [ ] Databricks runtime atualizado regularmente
- [ ] Bibliotecas Python/R mantidas atualizadas
- [ ] Dependências verificadas por vulnerabilidades
- [ ] Scans de segurança automáticos configurados
- [ ] Processo de aplicação de patches críticos definido
- [ ] Teste de patches em ambiente não-produção

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 7.2 Vulnerability Scanning

- [ ] Microsoft Defender for Cloud habilitado
- [ ] Scans regulares de container images
- [ ] Code scanning configurado (GitHub Advanced Security)
- [ ] Dependency scanning habilitado
- [ ] Secret scanning habilitado
- [ ] Resultados de scans revisados regularmente
- [ ] Vulnerabilidades críticas remediadas em 7 dias

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 7.3 Penetration Testing

- [ ] Pentest anual agendado
- [ ] Escopo de pentest definido
- [ ] Resultados de pentest documentados
- [ ] Remediação de findings priorizada
- [ ] Re-teste de vulnerabilidades críticas
- [ ] Comunicação com Microsoft sobre pentest (se necessário)

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

---

## 8. Resposta a Incidentes

### 8.1 Preparação

- [ ] Incident response plan documentado
- [ ] Equipe de resposta a incidentes designada
- [ ] Contatos de emergência documentados
- [ ] Runbooks de resposta criados
- [ ] Ferramentas de investigação configuradas
- [ ] Tabletop exercises realizados semestralmente

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 8.2 Detecção e Resposta

- [ ] Alertas de segurança com resposta definida
- [ ] Playbooks automatizados configurados (Sentinel)
- [ ] Processo de escalation definido
- [ ] SLAs de resposta estabelecidos:
  - [ ] Crítico: 1 hora
  - [ ] Alto: 4 horas
  - [ ] Médio: 1 dia
  - [ ] Baixo: 3 dias
- [ ] Comunicação durante incidentes planejada
- [ ] Post-mortem process estabelecido

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

---

## 9. Configurações Específicas do Databricks

### 9.1 Workspace Settings

- [ ] Public workspace access desabilitado (ou restrito)
- [ ] Workspace access control habilitado
- [ ] Token management settings configurados
- [ ] Cluster policy enforcement habilitado
- [ ] Notebook visibility restrita
- [ ] Library installation restrictions configuradas
- [ ] Init scripts validation habilitado

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 9.2 Cluster Configuration

- [ ] Auto-termination configurado (inatividade de 30 min)
- [ ] Cluster policies definidas
- [ ] Instance types restritos conforme necessário
- [ ] Autoscaling configurado adequadamente
- [ ] Passthrough authentication habilitado (Premium)
- [ ] Cluster tags aplicadas para governança
- [ ] Isolation mode configurado (Shared, High Concurrency)

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 9.3 Storage Configuration

- [ ] ADLS Gen2 com hierarquia habilitada
- [ ] Storage account com firewall habilitado
- [ ] Acesso via managed identities (não access keys)
- [ ] Lifecycle management policies configuradas
- [ ] Soft delete habilitado
- [ ] Versioning habilitado para dados críticos
- [ ] Storage analytics habilitado

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

---

## 10. Melhoria Contínua

### 10.1 Revisões Regulares

- [ ] Revisão mensal de acessos
- [ ] Revisão trimestral de políticas
- [ ] Revisão semestral de arquitetura de segurança
- [ ] Revisão anual de disaster recovery plan
- [ ] Benchmarking contra melhores práticas
- [ ] Participation em user groups/comunidades

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

### 10.2 Métricas e KPIs

- [ ] Taxa de compliance MFA: objetivo 100%
- [ ] Mean Time to Detect (MTTD): objetivo < 15 min
- [ ] Mean Time to Respond (MTTR): objetivo < 1 hora
- [ ] Vulnerabilities críticas abertas: objetivo 0
- [ ] Taxa de phishing clicks: objetivo < 5%
- [ ] Security training completion: objetivo 100%
- [ ] Audit findings: objetivo redução de 20% YoY

**Status:** ☐ Completo | ☐ Parcial | ☐ Não iniciado

---

## Scorecard de Segurança

### Resumo por Categoria

| Categoria | Completo | Parcial | Não Iniciado | Score |
|-----------|----------|---------|--------------|-------|
| 1. Autenticação e Identidade | ☐ | ☐ | ☐ | ___% |
| 2. Controle de Acesso | ☐ | ☐ | ☐ | ___% |
| 3. Segurança de Rede | ☐ | ☐ | ☐ | ___% |
| 4. Proteção de Dados | ☐ | ☐ | ☐ | ___% |
| 5. Auditoria e Monitoramento | ☐ | ☐ | ☐ | ___% |
| 6. Governança e Compliance | ☐ | ☐ | ☐ | ___% |
| 7. Gestão de Vulnerabilidades | ☐ | ☐ | ☐ | ___% |
| 8. Resposta a Incidentes | ☐ | ☐ | ☐ | ___% |
| 9. Config. Databricks | ☐ | ☐ | ☐ | ___% |
| 10. Melhoria Contínua | ☐ | ☐ | ☐ | ___% |

**Score Geral:** ___% 

### Interpretação do Score

- **90-100%**: Excelente - Segurança robusta
- **75-89%**: Bom - Algumas melhorias necessárias
- **60-74%**: Adequado - Melhorias significativas recomendadas
- **<60%**: Insuficiente - Ação urgente necessária

---

## Próximas Ações Prioritárias

**Top 5 itens críticos a serem completados:**

1. _______
2. _______
3. _______
4. _______
5. _______

**Responsável:** _______  
**Prazo:** _______

---

## Revisões e Sign-offs

| Data | Revisor | Score | Observações | Assinatura |
|------|---------|-------|-------------|------------|
| _______ | _______ | ___% | _______ | _______ |
| _______ | _______ | ___% | _______ | _______ |
| _______ | _______ | ___% | _______ | _______ |

---

**Versão:** 1.0  
**Última atualização:** 2025-11-06  
**Próxima revisão:** _______  
**Owner:** _______
