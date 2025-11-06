# Checklist de Implantação - MFA no Azure Databricks

## Visão Geral

Este checklist guia a implantação completa de MFA obrigatório no Azure Databricks usando Microsoft Entra ID Conditional Access.

---

## Fase 1: Pré-requisitos e Planejamento

### 1.1 Licenciamento

- [ ] Confirmar licença Microsoft Entra ID P1 ou P2
- [ ] Verificar licenças Azure Databricks ativas
- [ ] Documentar número total de usuários impactados

**Notas:**
- Usuários necessários: _______
- Licenças disponíveis: _______
- Gap de licenciamento: _______

### 1.2 Permissões e Acesso

- [ ] Validar permissões de Administrador de Acesso Condicional
- [ ] Validar permissões de Administrador de Aplicações
- [ ] Validar acesso ao Log Analytics Workspace
- [ ] Configurar acesso ao Microsoft Graph API

**Responsáveis:**
- Administrador Entra ID: _______
- Administrador Azure: _______
- Equipe de Segurança: _______

### 1.3 Inventário de Recursos

- [ ] Listar todos os workspaces Databricks
- [ ] Identificar ambientes (Produção, Desenvolvimento, Teste)
- [ ] Documentar SPNs e service accounts existentes
- [ ] Mapear grupos de usuários atuais

**Ferramenta:** Execute `Get-DatabricksServicePrincipals.ps1`

**Workspaces identificados:**
- Produção: _______
- Desenvolvimento: _______
- Teste: _______

### 1.4 Planejamento de Comunicação

- [ ] Definir estratégia de comunicação aos usuários
- [ ] Preparar documentação de ajuda (FAQ)
- [ ] Agendar reuniões de kickoff com stakeholders
- [ ] Definir canais de suporte

**Timeline de comunicação:**
- Anúncio inicial: _______
- Treinamento usuários: _______
- Lembrete pré-ativação: _______
- Ativação: _______

---

## Fase 2: Preparação do Ambiente

### 2.1 Configuração de Log Analytics

- [ ] Criar ou identificar Log Analytics Workspace
- [ ] Configurar retenção de logs (mínimo 90 dias)
- [ ] Configurar diagnóstico do Entra ID
  - [ ] SigninLogs
  - [ ] AuditLogs
  - [ ] RiskyUsers
- [ ] Validar ingestão de logs (aguardar 15 min)

**Workspace configurado:** _______

### 2.2 Configuração de MFA

- [ ] Revisar métodos MFA habilitados no tenant
  - [ ] Microsoft Authenticator
  - [ ] SMS
  - [ ] Chamada telefônica
  - [ ] FIDO2 (opcional)
- [ ] Configurar página de registro MFA customizada
- [ ] Definir políticas de registro MFA

**Métodos habilitados:**
- [ ] Push notification (Authenticator)
- [ ] SMS
- [ ] Chamada
- [ ] Outros: _______

### 2.3 Criação de Grupos

- [ ] Criar grupo para usuários Databricks
  - Nome: `GRP-SEC-Databricks-Users-Producao`
  - Tipo: Segurança
  - Membros: _______
  
- [ ] Criar grupo de exclusão temporária
  - Nome: `GRP-SEC-CA-Exclusion-Databricks`
  - Tipo: Segurança
  - Uso: Exceções temporárias
  
- [ ] Criar grupo break-glass
  - Nome: `GRP-SEC-BreakGlass-Global`
  - Tipo: Segurança
  - Membros: Contas de emergência

**ObjectIds dos grupos:**
- Usuários Databricks: _______
- Exclusão temporária: _______
- Break-glass: _______

### 2.4 Contas Break-Glass

- [ ] Criar 2 contas de emergência
  - Conta 1: `breakglass1@contoso.com`
  - Conta 2: `breakglass2@contoso.com`
- [ ] Atribuir role Global Administrator
- [ ] Gerar senhas complexas
- [ ] Armazenar credenciais em cofre seguro
- [ ] Documentar localização das credenciais
- [ ] Configurar alertas para uso dessas contas

**Credenciais armazenadas em:** _______

---

## Fase 3: Criação e Teste da Política

### 3.1 Criação da Política CA

- [ ] Acessar Entra ID > Proteção > Acesso Condicional
- [ ] Criar nova política: `MFA-Obrigatório-Azure-Databricks`
- [ ] Configurar Assignments:
  - [ ] Usuários: Selecionar grupo ou "Todos os usuários"
  - [ ] Excluir: Grupo break-glass
  - [ ] Aplicações: Azure Databricks (AppId: 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d)
  - [ ] Condições: Todas as plataformas, todas as localizações
- [ ] Configurar Controles de Acesso:
  - [ ] Exigir MFA
- [ ] Configurar Controles de Sessão:
  - [ ] Frequência de login: 8 horas
- [ ] Estado inicial: **Somente relatório**
- [ ] Criar política

**Policy ID criado:** _______

### 3.2 Validação em Modo Relatório

- [ ] Aguardar 24 horas de coleta de dados
- [ ] Executar query Kusto de análise de impacto
- [ ] Revisar relatório de Conditional Access no portal
- [ ] Identificar exceções necessárias
- [ ] Validar que política está sendo avaliada corretamente

**Impacto identificado:**
- Usuários que serão desafiados: _______
- Usuários que já têm MFA: _______
- Exceções necessárias: _______

### 3.3 Teste com Grupo Piloto

- [ ] Criar grupo piloto: `GRP-SEC-Databricks-Pilot`
- [ ] Adicionar 3-5 usuários de diferentes equipes ao piloto
- [ ] Modificar política para incluir apenas grupo piloto
- [ ] Alterar estado da política para: **Ativado**
- [ ] Notificar usuários piloto
- [ ] Executar testes:
  - [ ] Login via browser
  - [ ] Login via Databricks CLI
  - [ ] Acesso via notebook
  - [ ] API calls
- [ ] Coletar feedback dos usuários piloto
- [ ] Validar logs com `Test-MFAEnforcement.ps1`

**Membros do piloto:**
1. _______
2. _______
3. _______
4. _______
5. _______

**Resultados dos testes:**
- [ ] Todos os cenários funcionaram
- [ ] Problemas identificados: _______
- [ ] Ações corretivas: _______

---

## Fase 4: Comunicação e Treinamento

### 4.1 Campanha de Registro MFA

- [ ] Enviar email 2 semanas antes da ativação
- [ ] Incluir link: https://aka.ms/mfasetup
- [ ] Fornecer instruções passo a passo
- [ ] Oferecer sessões de treinamento
- [ ] Criar vídeo tutorial (opcional)

**Data do primeiro email:** _______
**Taxa de registro atual:** _______ %

### 4.2 Suporte e Documentação

- [ ] Criar página de FAQ interna
- [ ] Preparar equipe de suporte com documentação
- [ ] Definir SLAs para resolução
  - [ ] Crítico (bloqueio total): 1 hora
  - [ ] Alto (dificuldades MFA): 4 horas
  - [ ] Normal: 1 dia útil
- [ ] Configurar chatbot/knowledge base (opcional)

**URL da documentação:** _______
**Canal de suporte:** _______

### 4.3 Comunicação Final

- [ ] Email 1 semana antes: Lembrete
- [ ] Email 1 dia antes: Última chamada
- [ ] Anúncio no dia: Política ativa
- [ ] Follow-up pós-ativação: Status e suporte

---

## Fase 5: Rollout em Produção

### 5.1 Estratégia de Rollout

**Escolher uma estratégia:**

- [ ] **Opção A: Big Bang** (recomendado se >95% usuários têm MFA)
  - Data de ativação: _______
  - Horário: _______ (fora do pico)
  
- [ ] **Opção B: Rollout Gradual** (recomendado se <95%)
  - Semana 1: Equipe TI (_______ usuários)
  - Semana 2: Equipe Data Engineering (_______ usuários)
  - Semana 3: Equipe Analytics (_______ usuários)
  - Semana 4: Todos os usuários (_______ usuários)

### 5.2 Ativação da Política

- [ ] Fazer backup da política atual: `Export-ConditionalAccessPolicies.ps1`
- [ ] Modificar política para incluir usuários finais
- [ ] Revisar todas as configurações uma última vez
- [ ] Alterar estado da política para: **Ativado**
- [ ] Documentar:
  - Data/hora de ativação: _______
  - Responsável: _______
  - Configuração aplicada: _______

### 5.3 Monitoramento Pós-Ativação

**Primeiras 4 horas:**
- [ ] Monitorar dashboard em tempo real
- [ ] Verificar fila de suporte
- [ ] Executar `Test-MFAEnforcement.ps1` a cada hora
- [ ] Responder a incidentes imediatamente

**Primeiras 24 horas:**
- [ ] Executar query de compliance MFA
- [ ] Analisar falhas de autenticação
- [ ] Identificar usuários sem MFA registrado
- [ ] Gerar relatório de status

**Primeira semana:**
- [ ] Relatório diário de compliance
- [ ] Análise de tickets de suporte
- [ ] Ajustes de política se necessário
- [ ] Comunicação de status aos stakeholders

---

## Fase 6: Auditoria e Monitoramento Contínuo

### 6.1 Configuração de Alertas

- [ ] Alerta: Login sem MFA detectado (crítico)
- [ ] Alerta: Taxa de compliance < 95% (alto)
- [ ] Alerta: Alto volume de falhas MFA (médio)
- [ ] Alerta: Uso de conta break-glass (crítico)

**Alertas configurados em:** _______

### 6.2 Dashboards e Relatórios

- [ ] Configurar dashboard de compliance MFA
- [ ] Agendar relatório semanal automático
- [ ] Agendar relatório mensal executivo
- [ ] Configurar workbook de análise detalhada

**URLs dos dashboards:**
- Compliance: _______
- Executivo: _______

### 6.3 Processos Contínuos

- [ ] Revisar política CA mensalmente
- [ ] Auditar grupo de exclusões semanalmente
- [ ] Validar alertas estão funcionando
- [ ] Revisar e atualizar documentação
- [ ] Treinar novos membros da equipe

**Próxima revisão agendada:** _______

---

## Fase 7: Governança e Melhoria Contínua

### 7.1 Documentação

- [ ] Documentar decisões de design
- [ ] Manter changelog de modificações na política
- [ ] Documentar exceções e justificativas
- [ ] Atualizar runbooks conforme necessário

### 7.2 Compliance e Auditoria

- [ ] Adicionar controle ao registro de compliance (ISO, SOC2, etc.)
- [ ] Gerar evidências para auditoria
- [ ] Documentar alinhamento com frameworks
- [ ] Preparar relatório anual de compliance

**Frameworks cobertos:**
- [ ] ISO 27001
- [ ] SOC 2
- [ ] GDPR
- [ ] LGPD
- [ ] NIST 800-63B
- [ ] PCI DSS

### 7.3 Próximos Passos

- [ ] Considerar políticas baseadas em risco (Entra ID P2)
- [ ] Implementar requirement de dispositivo gerenciado
- [ ] Expandir MFA para outras aplicações críticas
- [ ] Implementar governança de PATs (Personal Access Tokens)
- [ ] Configurar SCIM provisioning

---

## Validação Final

### Critérios de Sucesso

- [ ] Taxa de compliance MFA: 100%
- [ ] Tempo médio de autenticação: < 30 segundos
- [ ] Taxa de satisfação dos usuários: > 80%
- [ ] Incidentes de bloqueio: 0
- [ ] Tickets de suporte: < 5% dos usuários
- [ ] SLA de suporte: Cumprido em 95% dos casos

### Sign-Off

| Stakeholder | Nome | Assinatura | Data |
|-------------|------|------------|------|
| Segurança da Informação | _______ | _______ | _______ |
| Arquitetura | _______ | _______ | _______ |
| Operações | _______ | _______ | _______ |
| Compliance | _______ | _______ | _______ |
| Sponsor Executivo | _______ | _______ | _______ |

---

## Notas e Observações

**Lições aprendidas:**

_______

**Problemas encontrados:**

_______

**Melhorias futuras:**

_______

---

**Versão:** 1.0  
**Última atualização:** 2025-11-06  
**Próxima revisão:** _______
