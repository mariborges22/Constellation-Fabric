# Análise Técnica: Integração Nakama

Esta análise detalha a viabilidade e os aspectos estratégicos da integração do **Nakama** como a engine de mercado e meta-game para o **Constellation**.

## 1. Riscos e Cuidados
- **SDK de Rust Arquivado**: O SDK oficial (`nakama-rs`) está arquivado. 
  - *Mitigação*: Devemos usar o **gRPC** diretamente. O Nakama exporta arquivos `.proto`, e em Rust podemos usar o `tonic` para gerar um cliente robusto e sempre atualizado, sem depender de wrappers de terceiros.
- **Interoperabilidade**: O Nakama é escrito em Go. A lógica "server-side" dele é em Go, JS ou Lua.
  - *Cuidados*: Nossa lógica de combate (Constellation Fabric) continuará em Rust. O Nakama cuidará do "Lobby" e do "Matchmaking", orquestrando a criação de instâncias do nosso motor de combate.

## 2. Vantagens vs. Desvantagens

### Vantagens
- **Time-to-Market**: Funcionalidades de amigos, chat, ranking, autenticação (Steam/Google/Apple) e economia (carteiras virtuais) vêm prontas.
- **Integração com Lojas**: Possui hooks nativos para validar compras na Google Play e Steam.
- **Escalabilidade Provada**: Projetado para milhões de usuários simultâneos (CCU).

### Desvantagens
- **Complexidade de Infra**: Adiciona um componente de peso (e um banco CockroachDB ou Postgres extra) à arquitetura.
- **Curva de Aprendizado**: Exige entender o modelo de "Match" do Nakama.

## 3. Aspectos Técnicos

- **Escalabilidade**: O Nakama escala horizontalmente de forma excelente. A versão Enterprise possui clustering mais avançado, mas a Open Source atende muito bem o início do projeto.
- **Estabilidade e Disponibilidade**: Altíssima. É usado por grandes estúdios e possui mecanismos de auto-healing em ambientes orquestrados (como o Swarm que você planeja).
- **Segurança**: Oferece autenticação JWT, expiração de sessões e proteção contra injeção por meio de sua API estruturada.
- **Performance**: Usando gRPC/HTTP2, a latência de integração entre o Nakama e o nosso backend Rust será mínima.

## 4. Custos e Economia
- **Open Source**: Gratuito para self-host. O custo principal será a infraestrutura (CPU/RAM para rodar o Nakama e o banco de dados).
- **Heroic Cloud**: Opção gerenciada (SaaS) que remove a dor de cabeça do DevOps, mas possui custos mensais que escalam com o uso.
- **Manutenção**: Reduz drasticamente o custo de desenvolvimento (horas de programador) ao não precisarmos reinventar a roda para sistemas sociais e de mercado.

## 5. Estratégia de Integração Sugerida

1.  **Nakama como "Master Server"**: O jogo se conecta primeiro ao Nakama para Auth e Social.
2.  **Matchmaking**: O Nakama decide quando uma partida começa e chama o nosso `combat-engine` (via RPC ou disparando um serviço no Swarm).
3.  **Persistência**: O Nakama guarda o inventário e economia; o `combat-engine` apenas valida as ações e reporta o resultado final para o Nakama atualizar a carteira do player.

> [!TIP]
> Dado que você quer publicar, a economia de tempo em **segurança e validação de compras** que o Nakama oferece compensa o risco do SDK arquivado.
