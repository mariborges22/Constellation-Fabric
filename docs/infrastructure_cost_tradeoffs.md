# Trade-offs de Infraestrutura e Custos (Staging)

Este documento registra as decisões de design de infraestrutura tomadas para equilibrar a fidelidade técnica (simulação multi-região) com as limitações de orçamento do AWS Free Tier durante a fase de desenvolvimento do **Constellation**.

## 1. Eliminação do NAT Gateway
**Data:** 22/04/2026  
**Contexto:** O uso de NAT Gateways em múltiplas regiões consome ~ $65/mês de custo fixo, o que excede rapidamente os limites gratuitos.

### O Trade-off
*   **Decisão:** Remover o NAT Gateway e mover os nodes do EKS para **Subnets Públicas**.
*   **Prós:** Economia imediata de custos fixos; mantém conectividade de saída para ECR e APIs AWS.
*   **Contras:** Cada node agora possui um IP público (mesmo que dinâmico), aumentando teoricamente a superfície de ataque se os Security Groups falharem.
*   **Mitigação:** Security Groups extremamente restritivos que permitem apenas tráfego interno do cluster e tráfego vindo do Application Load Balancer (ALB).

## 2. Redução da Baseline de Nodes (Single Node per Region)
**Data:** 22/04/2026

### O Trade-off
*   **Decisão:** Alterar o `min_size` e `desired_size` de 2 para **1** em cada região de Staging.
*   **Prós:** Redução de 50% no consumo de horas de EC2 (permitindo que o Free Tier de 750h dure mais tempo).
*   **Contras:** Perda de Alta Disponibilidade (HA) dentro de uma única região. Se o node cair (reclamação de Spot), a região fica offline temporariamente.
*   **Impacto no Sistema Distribuído:** Aceitável. Na verdade, força o teste de resiliência global (failover entre regiões), que é o objetivo principal da arquitetura "estilo Genshin".

## 3. Uso de EKS vs K3s
**Data:** 22/04/2026

### O Trade-off
*   **Decisão:** Manter o **Amazon EKS**, apesar da taxa de $0.10/h.
*   **Razão:** Manter a paridade total com o ambiente de Produção final e evitar o overhead de gerenciar o plano de controle do Kubernetes manualmente.
*   **Gatilho de Mudança:** Se o custo de $144/mês tornar-se insustentável antes do lançamento, o projeto deverá migrar para **K3s em instâncias EC2 Spot**.

---

*Nota: Em ambiente de **Produção**, o NAT Gateway e a baseline de 2+ nodes por região DEVEM ser restaurados para garantir conformidade com o SLA de disponibilidade e segurança padrão da indústria.*
