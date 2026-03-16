import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    thresholds: {
        // Para testes de segurança, esperamos 4xx (acesso negado/erro de validação).
        // Só falhamos se o servidor retornar 5xx (crash/panic).
        'http_req_failed{status:500}': ['rate<0.01'], 
    },
    scenarios: {
        sqli_fuzzing: {
            executor: 'constant-vus',
            vus: 10,
            duration: '30s',
        },
    },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const COMBAT_URL = __ENV.COMBAT_URL || 'http://localhost:8082';

const SQLI_PAYLOADS = [
    "' OR '1'='1",
    "'; DROP TABLE users; --",
    "admin' --",
    "' UNION SELECT NULL, NULL, NULL --",
    "1'; WAITFOR DELAY '0:0:5'--",
    "1' AND SLEEP(5)--",
    "\" OR \"\" = \"",
    "admin' #",
    "')) OR 1=1--",
];

export default function () {
    const payload = SQLI_PAYLOADS[Math.floor(Math.random() * SQLI_PAYLOADS.length)];
    
    // 1. Testando Auth Service (Login)
    const loginRes = http.post(`${BASE_URL}/api/v1/auth/login`, JSON.stringify({
        username: payload,
        password: "password123"
    }), { headers: { 'Content-Type': 'application/json' } });
    
    check(loginRes, {
        'Login: SQLi handled (not 5xx)': (r) => r.status < 500,
    });

    // 2. Testando Combat Engine (Authoritative Math)
    // Mesmo que o combat não use SQL diretamente no hot path, testamos a resiliência do parser
    const combatRes = http.post(`${COMBAT_URL}/api/v1/combat/attack`, JSON.stringify({
        action_type: "Attack",
        invoker_id: payload, 
        idempotency_key: "test-key"
    }), { headers: { 'Content-Type': 'application/json' } });

    check(combatRes, {
        'Combat: SQLi handled (not 5xx)': (r) => r.status < 500,
    });

    sleep(0.5);
}
