# 🌬️ Guia: Integração com Apache Airflow

O Airflow é o maestro do Constellation Fabric. Ele orquestra o fluxo de dados entre o motor de combate (Rust) e as camadas de análise (Databricks/Snowflake/S3).

## 🎯 Casos de Uso
1.  **Recuperação de Métricas do k6**: Puxar os resultados dos testes de carga/segurança e enviar para um banco de dados de telemetria.
2.  **ETL Batch**: Mover dados da camada Bronze para a Silver a cada 1 hora.
3.  **Snapshot de Estado**: Fazer backup programado das tabelas críticas do RDS.

## 🛠️ Exemplo de DAG (Pseudocódigo)
```python
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG("combat_metrics_pipeline", start_date=datetime(2024, 1, 1), schedule_interval="@hourly") as dag:

    # 1. Executar auditoria de carga/segurança
    run_pentest = BashOperator(
        task_id="run_k6_security_audit",
        bash_command="k6 run tests/k6/security-audit.js --out json=metrics.json"
    )

    # 2. Processar métricas do k6
    process_metrics = BashOperator(
        task_id="process_k6_results",
        bash_command="python scripts/process_metrics.py metrics.json"
    )

    run_pentest >> process_metrics
```

## 🔑 Configuração de Acesso (IAM)
Para que o Airflow (rodando em EC2/Lambda/Local) acesse os dados:
- Use a **Role OIDC** configurada no módulo de security para permissões de leitura no Kinesis.
- Nunca coloque `AWS_ACCESS_KEY` diretamente no código; use o **Airflow Connections** com integração ao AWS Secrets Manager.

## 📊 Visualização de Dados
Os dados processados pelo Airflow podem ser visualizados no Grafana. Recomendamos criar dashboards que mostrem:
- Latência de publicação do Kinesis.
- Sucesso de transações do RDS durante picos de carga.
- Alertas de segurança disparados pelo pipeline.

---
*Este guia é focado em engenheiros juniores. Experimente criar sua primeira DAG na pasta `pipelines/`!*
