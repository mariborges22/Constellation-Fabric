param(
    [string]$Domain,
    [string]$TunnelName = "constellation-staging",
    [string]$StackName = "constellation",
    [string]$DockerNetwork = "constellation-net",
    [string]$CloudflaredImage = "cloudflare/cloudflared:latest",
    [switch]$SkipDnsValidation,
    [switch]$SkipHttpValidation
)

$ErrorActionPreference = "Stop"

function Write-Step($message) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $message -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Write-Ok($message) {
    Write-Host "[OK] $message" -ForegroundColor Green
}

function Write-WarnMsg($message) {
    Write-Host "[WARN] $message" -ForegroundColor Yellow
}

function Write-ErrMsg($message) {
    Write-Host "[ERRO] $message" -ForegroundColor Red
}

function Require-Command($name, $hint) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-ErrMsg "Comando '$name' não encontrado."
        Write-Host "Dica: $hint" -ForegroundColor Gray
        exit 1
    }
}

function Run-CheckedCommand($command, $errorMessage) {
    Invoke-Expression $command | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-ErrMsg $errorMessage
        exit 1
    }
}

function Invoke-CloudflaredDocker {
    param(
        [Parameter(Mandatory = $true)][string]$Args,
        [switch]$Interactive
    )

    $configPath = (Resolve-Path ".\.cloudflared").Path
    $ttyFlag = if ($Interactive) { "-it" } else { "" }
    $cmd = "docker run --rm $ttyFlag -v `"${configPath}:/home/nonroot/.cloudflared`" $CloudflaredImage $Args"
    return $cmd
}

function Extract-TunnelIdFromList($listOutput, $name) {
    foreach ($line in $listOutput) {
        if ($line -match "^\s*([a-f0-9-]{36})\s+${name}\s+") {
            return $Matches[1]
        }
    }
    return $null
}

Write-Step "Constellation Fabric - Setup Cloudflare Tunnel + DNS (Docker/CLI)"

Require-Command "docker" "Instale o Docker Desktop e garanta que o daemon está rodando."
Require-Command "nslookup" "No Windows, o nslookup já vem por padrão."

try {
    docker version | Out-Null
    Write-Ok "Docker disponível."
} catch {
    Write-ErrMsg "Não foi possível acessar o Docker daemon."
    exit 1
}

if (-not $Domain) {
    $Domain = (Read-Host "Informe seu domínio raiz (ex: meudominio.com)").Trim().ToLowerInvariant()
}
if (-not $Domain) {
    Write-ErrMsg "Domínio é obrigatório."
    exit 1
}

$apiHost = "api.$Domain"
$wsHost = "ws.$Domain"
$authHost = "auth.$Domain"

if (-not (Test-Path ".\.cloudflared")) {
    New-Item -ItemType Directory -Path ".\.cloudflared" -Force | Out-Null
}
Write-Ok "Diretório de credenciais local: .cloudflared"

Write-Step "1) Login no Cloudflare (abre navegador)"
$doLogin = (Read-Host "Executar login agora? (S/N)").Trim().ToUpperInvariant()
if ($doLogin -eq "S") {
    $loginCmd = Invoke-CloudflaredDocker -Args "tunnel login" -Interactive
    Invoke-Expression $loginCmd
    if ($LASTEXITCODE -ne 0) {
        Write-ErrMsg "Falha no login do cloudflared."
        exit 1
    }
    Write-Ok "Login concluído."
} else {
    Write-WarnMsg "Pulando login. Certifique-se de que já existe cert em .cloudflared."
}

Write-Step "2) Criar (ou reutilizar) tunnel"
$listCmd = Invoke-CloudflaredDocker -Args "tunnel list"
$listOutput = Invoke-Expression $listCmd 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ErrMsg "Não foi possível listar túneis. Verifique se o login foi feito."
    exit 1
}

$tunnelId = Extract-TunnelIdFromList -listOutput $listOutput -name $TunnelName
if (-not $tunnelId) {
    Write-Host "Tunnel '$TunnelName' não encontrado. Criando..." -ForegroundColor Yellow
    $createCmd = Invoke-CloudflaredDocker -Args "tunnel create $TunnelName"
    $createOutput = Invoke-Expression $createCmd 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ErrMsg "Falha ao criar tunnel."
        $createOutput | ForEach-Object { Write-Host $_ }
        exit 1
    }

    foreach ($line in $createOutput) {
        if ($line -match "([a-f0-9-]{36})") {
            $tunnelId = $Matches[1]
            break
        }
    }
}

if (-not $tunnelId) {
    Write-ErrMsg "Não consegui identificar o Tunnel ID automaticamente."
    Write-Host "Saída de 'tunnel list':"
    $listOutput | ForEach-Object { Write-Host $_ }
    exit 1
}
Write-Ok "Tunnel em uso: $TunnelName ($tunnelId)"

Write-Step "3) Criar DNS routes para o tunnel"
$hosts = @($apiHost, $wsHost, $authHost)
foreach ($host in $hosts) {
    Write-Host "Criando rota DNS para $host ..." -ForegroundColor Yellow
    $routeCmd = Invoke-CloudflaredDocker -Args "tunnel route dns $TunnelName $host"
    $routeOutput = Invoke-Expression $routeCmd 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-WarnMsg "Falha ao criar rota para $host (pode já existir)."
        $routeOutput | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    } else {
        Write-Ok "Rota DNS criada/confirmada: $host"
    }
}

Write-Step "4) Gerar token do tunnel para Docker Swarm secret"
$tokenCmd = Invoke-CloudflaredDocker -Args "tunnel token $TunnelName"
$tunnelToken = (Invoke-Expression $tokenCmd 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $tunnelToken) {
    Write-ErrMsg "Falha ao gerar token do tunnel."
    exit 1
}
Write-Ok "Token gerado com sucesso."

Write-Host ""
Write-Host "Use este comando no manager do Swarm para atualizar o secret:" -ForegroundColor Cyan
Write-Host "echo '<TOKEN>' | docker secret create tunnel_token -" -ForegroundColor White
Write-Host "Se o secret já existir: docker secret rm tunnel_token; depois crie novamente." -ForegroundColor Gray

Write-Step "5) Validar Docker Swarm / serviços / rede"
$swarmState = (docker info --format "{{.Swarm.LocalNodeState}}") 2>$null
if ($swarmState -eq "active") {
    Write-Ok "Swarm ativo."
} else {
    Write-WarnMsg "Swarm não está ativo neste host. Se for deploy remoto, ignore."
}

$networkExists = (docker network ls --format "{{.Name}}" | Where-Object { $_ -eq $DockerNetwork })
if ($networkExists) {
    Write-Ok "Rede Docker encontrada: $DockerNetwork"
} else {
    Write-WarnMsg "Rede '$DockerNetwork' não encontrada neste host."
}

$serviceNames = @("auth", "nakama", "tunnel")
foreach ($svc in $serviceNames) {
    $fullName = "$StackName" + "_" + "$svc"
    $svcLine = (docker service ls --format "{{.Name}}" | Where-Object { $_ -eq $fullName })
    if ($svcLine) {
        Write-Ok "Serviço encontrado: $fullName"
    } else {
        Write-WarnMsg "Serviço não encontrado: $fullName (pode estar em outro cluster/host)."
    }
}

if (-not $SkipDnsValidation) {
    Write-Step "6) Validar resolução DNS"
    foreach ($host in $hosts) {
        try {
            $lookup = nslookup $host 2>&1 | Out-String
            if ($lookup -match "cloudflare" -or $lookup -match "canonical name" -or $lookup -match "Name:") {
                Write-Ok "DNS aparentemente resolvendo para $host"
            } else {
                Write-WarnMsg "Sem confirmação clara de DNS para $host. Confira no painel Cloudflare."
            }
        } catch {
            Write-WarnMsg "Falha no nslookup para $host"
        }
    }
}

if (-not $SkipHttpValidation) {
    Write-Step "7) Smoke test HTTP/HTTPS"
    foreach ($host in @($apiHost, $authHost)) {
        $url = "https://$host"
        try {
            $resp = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 20 -UseBasicParsing
            Write-Ok "$url -> HTTP $($resp.StatusCode)"
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            if ($statusCode) {
                Write-WarnMsg "$url respondeu com HTTP $statusCode (pode ser esperado para rota raiz)."
            } else {
                Write-WarnMsg "Falha de conexão em $url. Verifique ingress/public hostname do tunnel."
            }
        }
    }
}

Write-Step "8) Próximos passos importantes"
Write-Host "1) No Zero Trust > Tunnels, configure os Public Hostnames:" -ForegroundColor White
Write-Host "   - $apiHost  -> http://nakama:7350" -ForegroundColor White
Write-Host "   - $wsHost   -> http://nakama:7350" -ForegroundColor White
Write-Host "   - $authHost -> http://auth:8080" -ForegroundColor White
Write-Host ""
Write-Host "2) Atualize o secret tunnel_token no Swarm e faça deploy da stack." -ForegroundColor White
Write-Host "3) Teste no cliente do jogo: wss://$wsHost" -ForegroundColor White
Write-Host ""
Write-Ok "Setup finalizado. Ajustes finos podem ser feitos iterativamente."
