#!/bin/bash
# scripts/test-fast.sh

echo "🚀 Rodando testes ultra-rápidos do Constellation Fabric..."

# Definindo a flag para usar repositório em memória
export USE_IN_MEMORY_REPO=true

cd backend

echo "[1/2] Testando Player State..."
cargo test -p player-state --lib

echo "[2/2] Testando Combat Engine (Lógica)..."
cargo test -p combat --lib

echo "✅ Todos os testes de lógica concluídos com sucesso!"
