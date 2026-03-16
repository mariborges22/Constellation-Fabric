import http from 'k6/http';
import { check, sleep } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

// --- CONFIGURAÇÃO DE SOAK TEST (Teste de Estabilidade) ---
export const options = {
    stages: [
        { duration: '1m', target: 20 }, 
        { duration: '10m', target: 20 }, 
        { duration: '1m', target: 0 },  
    ],
    thresholds: {
        'http_req_failed': ['rate<0.01'], 
    },
};

const US_URL = __ENV.US_URL || 'http://constellation-fabric-us-east-1-a-176562278.us-east-1.elb.amazonaws.com';

export default function () {
    const actionTypes = ["NormalAttack", "ChargedAttack", "ElementalSkill", "ElementalBurst"];
    const payload = JSON.stringify({
        idempotency_key: uuidv4(),
        player_id: uuidv4(),
        character_id: uuidv4(),
        target_id: uuidv4(),
        action_type: actionTypes[Math.floor(Math.random() * actionTypes.length)],
    });

    const params = { headers: { 'Content-Type': 'application/json' } };
    let res = http.post(`${US_URL}/api/v1/combat/attack`, payload, params);

    check(res, { 'status 200': (r) => r.status === 200 });
    sleep(0.1); 
}
