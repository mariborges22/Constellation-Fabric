# 🚀 Estratégia de Lançamento Open Source (No-Domain Ready)

O **Constellation Fabric** está em um estado técnico invejável. A falta de um domínio próprio não é um impedimento, mas sim uma oportunidade de mostrar a flexibilidade da arquitetura. Aqui está como devemos proceder para o lançamento:

## 1. O Valor é a Receita (Blueprint), não o Bolo (Live URL)
Para a comunidade open-source, o que importa é:
- **Infraestrutura como Código (Terraform)**: Como você orquestrou multirregionalidade e segurança.
- **performance do Rust**: Os padrões de concorrência e o motor autoritativo.
- **Pipeline de Dados**: O blueprint da arquitetura Medallion.

## 2. Abordagem "Bring Your Own Domain"
No `README.md` e nos guias de deploy, vamos documentar que o sistema é agnóstico. 
- **O que entregamos**: Terraform que cria o Load Balancer e o ECS.
- **O que o usuário provê**: O nome do domínio nas variáveis do Terraform (`var.domain_name`).

## 3. Demo via ALB DNS (Grátis e Funcional)
Para mostrar que está funcionando sem comprar um domínio:
- O AWS Application Load Balancer (ALB) gera uma URL automática (ex: `constell-alb-123.us-east-1.elb.amazonaws.com`).
- Podemos documentar como usar essa URL bruta para orquestrar o k6 e os simuladores de combate.

## 4. Próximos Passos Imediatos
1.  **Merge para Master**: Consolidar a sprint de blindagem.
2.  **Limpeza Final**: Remover qualquer referência hardcoded a domínios temporários.
3.  **Documentação de Setup**: Garantir que o `scripts/setup-all.ps1` funcione "out of the box" para um novo usuário.

---
*Conclusão: O projeto está pronto. O domínio é apenas um registro; a engenharia aqui dentro é o que vai atrair os desenvolvedores.* 🌌💎🦀
