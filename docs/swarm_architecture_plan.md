# Plano de Arquitetura: Docker Swarm no Constellation

Este documento detalha como migraremos da arquitetura atual (ECS Fargate) para um modelo de orquestração com **Docker Swarm**, garantindo escalabilidade, segurança e baixo custo.

## 1. Infraestrutura na AWS (O "Hospedeiro")
Diferente do Fargate (serverless), o Swarm roda sobre instâncias **EC2**.
- **Nodes**: Teremos um **Auto Scaling Group (ASG)** de instâncias EC2.
- **Manager Nodes**: 1 a 3 instâncias para gerenciar o cluster.
- **Worker Nodes**: Instâncias que rodam os containers dos serviços (`auth`, `combat`, `nakama`).
- **Provisionamento**: Usaremos o **Terraform** para subir as EC2s com um script de `user_data` que executa o `docker swarm join`.

## 2. Implantação e Orquestração
- **Docker Stack**: Usaremos o comando `docker stack deploy -c docker-stack.yml constellation`.
- **Containers**: As imagens serão baixadas do **Amazon ECR** (como já fazemos).
- **Atualizações**: O Swarm gerencia **Rolling Updates** nativamente. Ao atualizar uma imagem, ele sobe a nova versão e remove a antiga gradualmente, sem downtime.

## 3. Escalonamento (Scaling)
- **Horizontal Pod Autoscaling**: Escalamos o número de `replicas` de um serviço no `docker-stack.yml`.
- **Infrastructure Scaling**: O AWS ASG adiciona mais instâncias EC2 ao cluster se o uso de CPU/RAM coletivo subir demais.

## 4. Conexão com AWS e Segurança
- **Segurança de Rede**: Usaremos **Overlay Networks** do Docker. Os containers se comunicam por uma rede interna isolada.
- **Secrets Manager**: Continuaremos usando o AWS Secrets Manager para chaves sensíveis, injetando-as como **Docker Secrets** no cluster.
- **Cloudflare Tunnel**: O `cloudflared` rodará como um serviço dentro do Swarm. Ele se conecta à Cloudflare por uma conexão de saída (sem portas abertas na AWS), garantindo segurança máxima.

## 5. Disponibilidade e Orquestração
- **Healthchecks**: O Swarm monitora a saúde de cada container. Se um serviço falhar, o Swarm o reinicia automaticamente em um node saudável.
- **Routing Mesh**: O Swarm possui um balanceador de carga interno que distribui o tráfego entre todas as réplicas de um serviço.

## 6. Como os Usuários Acessam?
1.  O usuário acessa `api.constellation.com`.
2.  A **Cloudflare** recebe a requisição.
3.  O **Cloudflare Tunnel** (dentro do Swarm) puxa essa requisição para dentro do cluster.
4.  O Swarm entrega para a réplica disponível do serviço (`auth`, `combat` ou `nakama`).

---

### Vantagens dessa Escolha
- **Custo**: EC2 com instâncias Spot é muito mais barato que Fargate para processos que rodam 24/7.
- **Controle**: Total liberdade para configurar limites de recursos e otimizar a performance do Rust.
- **Portabilidade**: O mesmo `docker-stack.yml` que roda na AWS pode rodar em um servidor local ou em outra nuvem.
