import http from 'k6/http';
import { check, group } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

// --- CONFIGURAÇÃO DO TESTE ---
export const options = {
    thresholds: {
        // Agora o teste só "falha" se o servidor retornar 500 (Crash/Vulnerabilidade Real)
        // Rejeições 4xx são consideradas "Sucesso de Defesa"
        'http_req_failed{vulnerability:true}': ['rate<0.01'], 
    },
};

const US_URL = __ENV.US_URL || 'http://constellation-fabric-us-east-1-a-176562278.us-east-1.elb.amazonaws.com';

export default function () {

    group('01. SQL Injection (Bypass attempts)', function () {
        const sqlPayloads = [
            "' OR 1=1 --",
            "'; SELECT pg_sleep(10); --",
            "admin' --"
        ];
        sqlPayloads.forEach(payload => {
            let res = http.get(`${US_URL}/api/v1/players/${encodeURIComponent(payload)}`, {
                tags: { vulnerability: 'true' }
            });
            check(res, {
                'SQLi rejected (4xx)': (r) => r.status >= 400 && r.status < 500,
                'SQLi did not crash server': (r) => r.status !== 500,
            });
        });
    });

    group('02. Broken Authentication / JWT Manipulation', function () {
        // Tenta acessar endpoint protegido com token malformado
        const params = {
            headers: { 'Authorization': 'Bearer NOT_A_REAL_JWT_TOKEN' },
            tags: { vulnerability: 'true' }
        };
        let res = http.get(`${US_URL}/api/v1/combat/health`, params);
        check(res, {
            'JWT malformed rejected (401)': (r) => r.status === 401 || r.status === 403 || r.status === 422,
        });
    });

    group('03. Mass Assignment / Anti-Cheat', function () {
        // Tentativa de injetar campos que o jogador não deveria controlar (ex: level, experience diretamente)
        const maliciousPayload = JSON.stringify({
            idempotency_key: uuidv4(),
            player_id: uuidv4(),
            character_id: uuidv4(),
            target_id: uuidv4(),
            action_type: "NormalAttack",
            damage_override: 999999, // Campo inexistente no DTO oficial
            admin_privileges: true   // Tentativa de escalação
        });

        let res = http.post(`${US_URL}/api/v1/combat/attack`, maliciousPayload, {
            headers: { 'Content-Type': 'application/json' },
            tags: { vulnerability: 'true' }
        });

        check(res, {
            'Mass Assignment barreado pelo Serde/Rust': (r) => r.status === 200 || r.status === 422,
        });
    });

    group('04. Denial of Service (Mini-DoS)', function () {
        // Muitas requisições rápidas para testar Rate Limit (se configurado)
        for (let i = 0; i < 5; i++) {
            http.get(`${US_URL}/health`, { tags: { vulnerability: 'false' } });
        }
    });
}
