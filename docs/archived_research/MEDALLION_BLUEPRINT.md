# 🏅 Blueprint: Arquitetura Medallion no Constellation Fabric

Este guia orienta engenheiros de dados juniores sobre como transformar os eventos crus de combate em inteligência estratégica utilizando a arquitetura Medallion.

## 🥉 Camada Bronze (Raw)
**Fonte**: AWS Kinesis Data Stream (`constellation-fabric-combat-events`)
**Formato**: JSON (Raw CombatAction)

Nesta camada, os dados são armazenados exatamente como saíram do motor de combate Rust.
- **Objetivo**: Persistência histórica e imutabilidade.
- **Dica**: Utilize o Kinesis Firehose para despejar esses eventos no S3 em formato Parquet para economia de custo e performance.

### Exemplo de Evento:
```json
{
  "id": "uuid-v4",
  "actor_id": "player-123",
  "action_type": "Skill",
  "damage": 1250.5,
  "reaction": "Vaporize",
  "timestamp": 1678901234
}
```

## 🥈 Camada Silver (Cleaned & Normalized)
**Fonte**: Bronze Layer (S3/Data Lake)
**Objetivo**: Limpeza, deduplicação (usando a `idempotency_key`) e enriquecimento.

Nesta fase, você deve cruzar os logs de combate com os dados dimensionais do **RDS (Player-State)**:
- Juntar o `actor_id` com o nome do personagem e nível.
- Normalizar carimbos de data/hora para o fuso horário padrão.
- Validar se os valores de dano estão dentro de faixas esperadas (detecção de anomalias/cheats).

## 🥇 Camada Gold (Business/Analytics)
**Fonte**: Silver Layer
**Objetivo**: Tabelas prontas para consumo por dashboards (Grafana/Tableau) ou modelos de ML.

Exemplos de tabelas Gold:
1.  **Métricas de Balanceamento**: Dano médio por Elemento (Pyro vs Hydro).
2.  **Churn Analytics**: Frequência de ações de combate por sessão de usuário.
3.  **Performance de Boss**: Taxa de sucesso de jogadores contra inimigos específicos.

---
*Dúvidas? Abra uma issue com a tag `help-wanted` ou fale com os mantenedores no canal de Data Engineering.*
