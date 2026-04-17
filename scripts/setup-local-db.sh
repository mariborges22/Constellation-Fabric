#!/usr/bin/env bash
# scripts/setup-local-db.sh
# Inicializa o DynamoDB Local com a tabela e GSIs do Constellation.

TABLE_NAME="constellation-local"
ENDPOINT="http://localhost:8000"

echo "--- Inicializando DynamoDB Local ---"

# 1. Remover tabela se já existir (para garantir o clean start)
aws dynamodb delete-table --table-name "$TABLE_NAME" --endpoint-url "$ENDPOINT" 2>/dev/null || true

# 2. Criar tabela principal
echo "Criando tabela: $TABLE_NAME"
aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions \
        AttributeName=pk,AttributeType=S \
        AttributeName=sk,AttributeType=S \
    --key-schema \
        AttributeName=pk,KeyType=HASH \
        AttributeName=sk,KeyType=RANGE \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --endpoint-url "$ENDPOINT"

# 3. Criar GSI para Email (gsi1)
echo "Adicionando GSI1: email_index"
aws dynamodb update-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=email_index,AttributeType=S \
    --global-secondary-index-updates \
    "[{\"Create\": {\"IndexName\": \"gsi1\", \"KeySchema\": [{\"AttributeName\": \"email_index\", \"KeyType\": \"HASH\"}], \"Projection\": {\"ProjectionType\": \"ALL\"}, \"ProvisionedThroughput\": {\"ReadCapacityUnits\": 5, \"WriteCapacityUnits\": 5}}}]" \
    --endpoint-url "$ENDPOINT"

# 4. Criar GSI para Username (gsi2)
echo "Adicionando GSI2: username_index"
aws dynamodb update-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=username_index,AttributeType=S \
    --global-secondary-index-updates \
    "[{\"Create\": {\"IndexName\": \"gsi2\", \"KeySchema\": [{\"AttributeName\": \"username_index\", \"KeyType\": \"HASH\"}], \"Projection\": {\"ProjectionType\": \"ALL\"}, \"ProvisionedThroughput\": {\"ReadCapacityUnits\": 5, \"WriteCapacityUnits\": 5}}}]" \
    --endpoint-url "$ENDPOINT"

echo "--- DynamoDB Local Pronto para Uso ---"
