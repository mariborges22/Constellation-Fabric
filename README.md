# 🌌 Constellation Fabric

![Coverage](https://img.shields.io/badge/coverage-85%25-green)
![Status](https://img.shields.io/badge/status-production--ready-blue)
![License](https://img.shields.io/badge/license-MIT-orange)

**Constellation Fabric** é um motor de combate autoritativo de alto desempenho, construído em **Rust** e escalonado nativamente na **AWS**. Projetado para sistemas que exigem precisão matemática em tempo real, segurança "Zero Trust" e pipelines de dados de escala Petabyte.

## 🚀 Visão Geral
O projeto resolve o desafio de manter a integridade do estado de jogo em ambientes distribuídos, processando cálculos de dano, reações elementares e persistência de estado de forma síncrona, enquanto transmite eventos assíncronos para pipelines de Data Engineering.

### Core Tech Stack
- **Backend**: Rust (Axum, SQLx, Tokio)
- **Infraestrutura**: Terraform (AWS ECS, RDS, Kinesis, Secrets Manager)
- **Segurança**: KMS Encryption, JWT Auth, OIDC GitHub Actions
- **Qualidade**: Pentesting com k6 e Auditoria Zero Trust

## 🏗️ Arquitetura
O sistema é dividido em três camadas principais:
1.  **Ingress Layer**: Cloudflare Tunnels + ALB para terminação segura.
2.  **Compute Layer**: Serviços Rust no ECS Fargate com Autoscaling dinâmico.
3.  **Data Layer**: RDS PostgreSQL para estado persistente e Kinesis para streaming em tempo real.

## 📊 Para Engenheiros de Dados (Blueprint Medallion)
Este projeto foi desenhado para ser o laboratório perfeito para quem quer aprender Big Data.
- **Bronze Layer**: Consuma os eventos crus do Kinesis.
- **Silver Layer**: Modele os logs de combate em tabelas dimensionais.
- **Gold Layer**: Gere insights estratégicos sobre o meta de jogo.

Confira o [Guia Medallion](./docs/MEDALLION_BLUEPRINT.md), o [Architectural Decision Records (ADR)](./docs/ADR.md) e o [Playbook de Data Engineering](./docs/DATA_PLAYBOOK.md).

## 🛠️ Começando
### Pré-requisitos
- Rust & Cargo
- Docker
- AWS CLI (configurado para Staging)
- Terraform

### Setup Rápido
```bash
# Rodar setup de infra
cd infra/enviroments/staging
terraform init && terraform apply

# Subir os serviços locais
cargo build
./setup-all-crates.ps1
```

## 🛡️ Segurança
Todas as chaves sensíveis são gerenciadas via **AWS Secrets Manager** e os dados em repouso são criptografados via **KMS**. Para auditorias de segurança, execute:
```bash
k6 run tests/k6/security-audit.js
```

## 🤝 Contribuição
Se você é um dev júnior querendo praticar, este é o seu lugar! Leia o nosso `CONTRIBUTING.md` (em breve) e comece pelas "Good First Issues".

---
*Desenvolvido com ❤️ para a comunidade Constellation.*
