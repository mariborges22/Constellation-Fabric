# ============================================================================
# CONSTELLATION FABRICK - Auth Wiring Setup Script (REMOTE VERSION)
# Frontend <-> Remote AWS ECS Backend Integration
# ============================================================================

$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "SETTING UP: Auth Wiring Integration (Remote)" -ForegroundColor Cyan
Write-Host "================================================"
Write-Host ""

# Variables
$FRONTEND_DIR = "frontend"
$STAGING_INFRA_DIR = "infra/enviroments/staging"
$DEFAULT_ALB_URL = ""

# ============================================================================
# CHECK PREREQUISITES
# ============================================================================

Write-Host "[1/4] Checking prerequisites..." -ForegroundColor Yellow

if (-not (Test-Path $FRONTEND_DIR)) {
    Write-Host "ERRO: Frontend directory not found: $FRONTEND_DIR" -ForegroundColor Red
    exit 1
}

$terraformExists = Get-Command terraform -ErrorAction SilentlyContinue
if ($null -eq $terraformExists) {
    Write-Host "AVISO: Terraform nao encontrado no PATH." -ForegroundColor Yellow
}

Write-Host "  OK -> Prerequisites validated" -ForegroundColor Green

# ============================================================================
# DISCOVER REMOTE BACKEND URL
# ============================================================================

Write-Host ""
Write-Host "[2/4] Discovering Remote Backend URL..." -ForegroundColor Yellow

if ($null -ne $terraformExists -and (Test-Path $STAGING_INFRA_DIR)) {
    Write-Host "[*] Tentando obter ALB URL do Terraform (Staging)..." -ForegroundColor Cyan
    Push-Location $STAGING_INFRA_DIR
    try {
        $DEFAULT_ALB_URL = terraform output -raw alb_url_us 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($DEFAULT_ALB_URL)) {
             Write-Host "AVISO: Nao foi possivel obter o output automatico do Terraform." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "AVISO: Erro ao executar terraform output." -ForegroundColor Yellow
    }
    Pop-Location
}

if ([string]::IsNullOrEmpty($DEFAULT_ALB_URL)) {
    Write-Host ""
    Write-Host "Por favor, insira a URL do seu Load Balancer (Ex: http://constellation-alb-123.us-east-1.elb.amazonaws.com):" -ForegroundColor White
    $BACKEND_URL = Read-Host "URL"
    if ([string]::IsNullOrEmpty($BACKEND_URL)) {
        Write-Host "ERRO: URL do Backend e obrigatoria." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "URL detectada via Terraform: $DEFAULT_ALB_URL" -ForegroundColor Green
    $confirm = Read-Host "Deseja usar esta URL? (s/n)"
    if ($confirm -eq "s" -or $confirm -eq "S" -or [string]::IsNullOrEmpty($confirm)) {
        $BACKEND_URL = $DEFAULT_ALB_URL
    } else {
        $BACKEND_URL = Read-Host "Insira a URL customizada"
    }
}

# Ensure no trailing slash
if ($BACKEND_URL.EndsWith("/")) { $BACKEND_URL = $BACKEND_URL.Substring(0, $BACKEND_URL.Length - 1) }

Write-Host "Using Backend: $BACKEND_URL" -ForegroundColor Green

# ============================================================================
# CREATE FRONTEND AUTH INTEGRATION
# ============================================================================

Write-Host ""
Write-Host "[3/4] Setting up frontend authentication files..." -ForegroundColor Yellow

$jsDir = "$FRONTEND_DIR/js"
if (-not (Test-Path $jsDir)) { New-Item -ItemType Directory -Path $jsDir | Out-Null }

$authJsContent = @"
// ============================================================================
// Auth Service - Frontend Integration (Remote)
// ============================================================================

const AUTH_API = '$BACKEND_URL/api/v1/auth';
const TOKEN_KEY = 'constellation_token';

class AuthService {
  static async register(username, email, password) {
    try {
      const response = await fetch(`${AUTH_API}/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, email, password }),
      });
      
      if (!response.ok) throw new Error(`Registration failed: \${response.statusText}`);
      
      const data = await response.json();
      this.setToken(data.token);
      return data;
    } catch (error) {
      console.error('Registration error:', error);
      throw error;
    }
  }

  static async login(username, password) {
    try {
      const response = await fetch(`${AUTH_API}/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      });
      
      if (!response.ok) throw new Error(`Login failed: \${response.statusText}`);
      
      const data = await response.json();
      this.setToken(data.token);
      return data;
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  }

  static getToken() { return localStorage.getItem(TOKEN_KEY); }
  static setToken(token) { localStorage.setItem(TOKEN_KEY, token); }
  static logout() { localStorage.removeItem(TOKEN_KEY); }
  static isAuthenticated() { return this.getToken() !== null; }

  static getAuthHeaders() {
    const token = this.getToken();
    if (!token) return { 'Content-Type': 'application/json' };
    return {
      'Authorization': `Bearer \${token}`,
      'Content-Type': 'application/json',
    };
  }

  static async verify() {
    try {
      const response = await fetch(`${AUTH_API}/verify`, {
        method: 'POST',
        headers: this.getAuthHeaders(),
        body: JSON.stringify({ token: this.getToken() })
      });
      return response.ok;
    } catch (error) {
      return false;
    }
  }
}
"@

Set-Content -Path "$jsDir/auth.js" -Value $authJsContent -Encoding UTF8

$loginHtmlContent = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Constellation Fabric - Auth</title>
  <style>
    body { font-family: 'Segoe UI', sans-serif; background: #0b0e14; color: #fff; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
    .card { background: #1a1f26; padding: 2rem; border-radius: 12px; box-shadow: 0 8px 32px rgba(0,0,0,0.5); width: 350px; border: 1px solid #333; }
    h1 { text-align: center; color: #00ffcc; font-size: 1.5rem; margin-bottom: 1.5rem; }
    .field { margin-bottom: 1rem; }
    label { display: block; margin-bottom: 0.4rem; font-size: 0.9rem; color: #aaa; }
    input { width: 100%; padding: 10px; background: #252b33; border: 1px solid #444; border-radius: 6px; color: #fff; box-sizing: border-box; }
    button { width: 100%; padding: 12px; background: #00ffcc; border: none; border-radius: 6px; color: #0b0e14; font-weight: bold; cursor: pointer; margin-top: 1rem; }
    .toggle { text-align: center; margin-top: 1rem; font-size: 0.8rem; color: #888; }
    .toggle span { color: #00ffcc; cursor: pointer; text-decoration: underline; }
    .msg { margin-top: 1rem; text-align: center; min-height: 1.2rem; font-size: 0.9rem; }
  </style>
</head>
<body>
  <div class="card">
    <h1 id="title">Login</h1>
    <form id="form">
      <div class="field" id="userField">
        <label>Username</label>
        <input type="text" id="username" required>
      </div>
      <div class="field" id="emailField" style="display:none">
        <label>Email</label>
        <input type="email" id="email">
      </div>
      <div class="field">
        <label>Password</label>
        <input type="password" id="password" required>
      </div>
      <button type="submit" id="btn">Login</button>
    </form>
    <div class="toggle" id="toggle">New here? <span onclick="app.toggle()">Register</span></div>
    <div class="msg" id="msg"></div>
  </div>
  <script src="js/auth.js"></script>
  <script>
    const app = {
      isLogin: true,
      toggle() {
        this.isLogin = !this.isLogin;
        document.getElementById('title').innerText = this.isLogin ? 'Login' : 'Register';
        document.getElementById('emailField').style.display = this.isLogin ? 'none' : 'block';
        document.getElementById('btn').innerText = this.isLogin ? 'Login' : 'Register';
        document.getElementById('toggle').innerHTML = this.isLogin ? 'New here? <span onclick="app.toggle()">Register</span>' : 'Back to <span onclick="app.toggle()">Login</span>';
      }
    };

    document.getElementById('form').onsubmit = async (e) => {
      e.preventDefault();
      const msg = document.getElementById('msg');
      const u = document.getElementById('username').value;
      const p = document.getElementById('password').value;
      const e_ = document.getElementById('email').value;
      
      try {
        msg.innerText = app.isLogin ? 'Logging in...' : 'Registering...';
        if (app.isLogin) {
          await AuthService.login(u, p);
        } else {
          await AuthService.register(u, e_, p);
        }
        msg.style.color = '#00ffcc';
        msg.innerText = 'Success! Redirecting...';
        setTimeout(() => window.location.href = 'index.html', 1000);
      } catch (err) {
        msg.style.color = '#ff4d4d';
        msg.innerText = 'Error: ' + err.message;
      }
    };
  </script>
</body>
</html>
'@

Set-Content -Path "$FRONTEND_DIR/login.html" -Value $loginHtmlContent -Encoding UTF8

Write-Host "  OK -> Frontend files created" -ForegroundColor Green

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ""
Write-Host "[4/4] Generating summary..." -ForegroundColor Yellow

$summary = @"
================================================================
CONSTELLATION FABRICK - Auth Wiring Setup Summary (Remote)
================================================================

STATUS: Frontend Configured
Remote Backend URL: $BACKEND_URL

FILES GENERATED:
- $FRONTEND_DIR/js/auth.js
- $FRONTEND_DIR/login.html

IMPORTANT:
O backend remoto (ECS) so sera atualizado com as novas rotas (/register) 
apos voce realizar o PUSH das alteracoes para o GitHub, o que disparara 
a pipeline de CI/CD.

O frontend local agora esta apontando diretamente para o Load Balancer da AWS.
================================================================
"@

$summary | Out-File -FilePath "setup-auth-summary.txt" -Encoding UTF8
Write-Host "Done! Summary saved to setup-auth-summary.txt" -ForegroundColor Green
Write-Host ""
Read-Host "Pressione ENTER para fechar"
