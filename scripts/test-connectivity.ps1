# Connectivity Test Script for Constellation Fabric ALBs
# Handles SSL certification validation for PowerShell 5.1 (SkipCertificateCheck support)

# --- CONFIGURATION ---
$ALBs = @(
    "constellation-fabric-us-east-1-a-2070272044.us-east-1.elb.amazonaws.com",
    "constellation-fabric-eu-west-1-a-1169085611.eu-west-1.elb.amazonaws.com"
)

$HealthPaths = @(
    "/health",                   # Auth Service
    "/api/v1/players/health",    # Player State Service
    "/api/v1/combat/health"      # Combat Engine
)

# --- SSL VALIDATION BYPASS (PS 5.1 COMPATIBLE) ---
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# --- TEST EXECUTION ---
Write-Host "`n--- Constellation Fabric Connectivity Test ---" -ForegroundColor Cyan
Write-Host "Targeting ALBs via HTTP (Port 80) as per Infrastructure Design`n"

foreach ($alb in $ALBs) {
    Write-Host "Checking ALB: $alb" -ForegroundColor Yellow
    foreach ($path in $HealthPaths) {
        # Note: We use http:// because the ALB listeners are only on port 80.
        # HTTPS is terminated at Cloudflare Edge before reaching the tunnel.
        $url = "http://$alb$path"
        Write-Host "  Testing: $path (HTTP) ... " -NoNewline
        
        try {
            $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 10 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Host "OK (200)" -ForegroundColor Green
            } else {
                Write-Host "FAIL ($($response.StatusCode))" -ForegroundColor Red
            }
        } catch {
            Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

Write-Host "Nota Técnica: O timeout ocorre em HTTPS (443) porque os ALBs não possuem listeners SSL." -ForegroundColor Gray
Write-Host "O tráfego HTTPS é gerenciado pelo Cloudflare Tunnel, não diretamente pelo ALB.`n" -ForegroundColor Gray
Write-Host "Tests completed.`n" -ForegroundColor Cyan
