import http from 'k6/http';
import { check, sleep } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

// --- CONFIGURAÇÃO DO TESTE ---
export const options = {
    scenarios: {
        // Cenário 1: Jogadores nos EUA atingindo o ALB da Virginia
        us_players: {
            executor: 'ramping-arrival-rate',
            startRate: 5,
            timeUnit: '1s',
            preAllocatedVUs: 10,
            maxVUs: 50,
            stages: [
                { target: 20, duration: '1m' }, // Sobe para 20 req/s
                { target: 20, duration: '2m' }, // Mantém estabilidade
                { target: 0, duration: '30s' }, // Desce pra esfriar
            ],
            tags: { region: 'us-east-1' },
            exec: 'combat_action',
        },
        // Cenário 2: Jogadores na Europa atingindo o ALB da Irlanda
        eu_players: {
            executor: 'constant-arrival-rate',
            rate: 10,
            timeUnit: '1s',
            duration: '3m',
            preAllocatedVUs: 5,
            maxVUs: 20,
            tags: { region: 'eu-west-1' },
            exec: 'combat_action',
        },
    },
    thresholds: {
        'http_req_duration{region:us-east-1}': ['p(95)<500'], // 95% das reqs em < 500ms
        'http_req_duration{region:eu-west-1}': ['p(95)<800'], // Latência intercontinental pode ser maior
        'http_req_failed': ['rate<0.01'], // Menos de 1% de erro
    },
};

// --- VARIÁVEIS DE AMBIENTE (Passe via -e) ---
const US_URL = __ENV.US_URL || 'http://constellation-fabric-us-east-1-a-176562278.us-east-1.elb.amazonaws.com';
const EU_URL = __ENV.EU_URL || 'http://constellation-fabric-eu-west-1-a-151676040.eu-west-1.elb.amazonaws.com';

export function combat_action() {
    const region = __ITER % 2 === 0 ? 'us' : 'eu';
    const baseUrl = region === 'us' ? US_URL : EU_URL;
    
    const url = `${baseUrl}/api/v1/combat/attack`;
    const actionTypes = ["NormalAttack", "ChargedAttack", "ElementalSkill", "ElementalBurst"];
    
    const payload = JSON.stringify({
        idempotency_key: uuidv4(),
        player_id: uuidv4(),
        character_id: uuidv4(),
        target_id: uuidv4(),
        action_type: actionTypes[Math.floor(Math.random() * actionTypes.length)],
    });

    const params = {
        headers: { 'Content-Type': 'application/json' },
        tags: { region: region === 'us' ? 'us-east-1' : 'eu-west-1' },
    };

    const res = http.post(url, payload, params);

    check(res, {
        'is status 200': (r) => r.status === 200,
        'has damage': (r) => r.json().damage_dealt !== undefined,
    });

    // Pequena pausa para simular tempo de reação humano (opcional no arrival-rate)
    sleep(Math.random() * 0.5);
}
