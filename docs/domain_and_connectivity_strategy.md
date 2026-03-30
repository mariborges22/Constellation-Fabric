# Estratégia de Domínio e Acesso Público

Para que o **Constellation** seja acessível externamente (especialmente para integração com Nakama, Steam e Google Play), precisamos resolver a questão do domínio. 

## 1. Por que um Domínio é Obrigatório?
- **Publicação (Steam/Google)**: As lojas exigem um endpoint fixo e seguro (HTTPS) para autenticação e callbacks.
- **Segurança (SSL/TLS)**: Certificados SSL são emitidos para domínios. Sem um domínio, o tráfego não é criptografado de forma padronizada.
- **Cloudflare Tunnel**: Embora exista o "TryCloudflare" (temporário), um tunnel persistente e confiável exige um domínio gerenciado na Cloudflare.

## 2. Opções de Domínio (Custo-Benefício)
Se você ainda não tem um, recomendo comprar diretamente pela **Cloudflare Registrar**:
-**.com**: ~$10/ano (Padrão ouro)
-**.dev**: ~$15/ano (Ótimo para backend/dev)
-**.gg**: ~$15-30/ano (Muito usado em games, mas um pouco mais caro)
-**.me / .io**: Alternativas populares no meio tech.

> [!TIP]
> Comprando na Cloudflare, o custo é "preço de custo" (sem margem de lucro deles) e a integração com o Tunnel é automática.

## 3. Como testar SEM domínio (Agora)
Se você quiser testar a conexão externa hoje mesmo sem gastar nada:
1.  **TryCloudflare**: Ao rodar o `cloudflared tunnel`, você pode adicionar a flag `--url http://localhost:8080`. Ele vai gerar um link aleatório como `https://quiet-stars-jump.trycloudflare.com`.
    - *Limitação*: Esse link muda toda vez que você reinicia o túnel.
2.  **Pinggy.io / Localtunnel**: Outras ferramentas que dão URLs temporárias gratuitas via SSH.

## 4. Plano de Ação sugerido
1.  **Escolha um nome**: Algo como `constellation-fabric.com` ou `constellation-api.dev`.
2.  **Assine o domínio**: Na Cloudflare ou Namecheap.
3.  **Vincule ao Swarm**: No nosso `docker-stack.yml`, o `tunnel` usará o token desse domínio para criar subdomínios fixos (ex: `auth.seu-dominio.com`, `combat.seu-dominio.com`).

---

**Sem um domínio fixo, não conseguiremos implementar a segurança e a orquestração que planejamos para a Steam/Google Play.** É um investimento baixo que "destrava" todo o resto da infraestrutura profissional.
