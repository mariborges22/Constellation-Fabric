import http from 'k6/http';
import { check, sleep } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

export const options = {
    // Escalonamento agressivo para forçar throttling no Kinesis (limite de 1000 rec/s por shard)
    stages: [
        { duration: '30s', target: 50 },  // Carga normal (~500 req/s se 10 req/VU)
        { duration: '1m', target: 300 }, // Spike para forçar Throttling (3000+ req/s)
        { duration: '30s', target: 50 },  // Cool down para observar recuperação
    ],
    thresholds: {
        'http_req_duration': ['p(95)<500'], // Latência da API deve continuar BAIXA pois o Kinesis é assíncrono
        'http_req_failed': ['rate<0.01'],    // API não deve falhar mesmo se o Kinesis estiver sofrendo
    },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8082';

export default function () {
    const payload = JSON.stringify({
        idempotency_key: uuidv4(),
        player_id: uuidv4(),
        character_id: uuidv4(),
        target_id: uuidv4(),
        action_type: "NormalAttack"
    });

    const params = {
        headers: {
            'Content-Type': 'application/json',
        },
    };

    const res = http.post(`${BASE_URL}/api/v1/combat/attack`, payload, params);

    // Verificação de Resiliência:
    // A API deve retornar 200 OK IMEDIATAMENTE (non-blocking) mesmo que o
    // worker de Kinesis esteja em backoff ou com o Circuit Breaker aberto.
    check(res, {
        'API is resilient (non-blocking)': (r) => r.status === 200,
    });

    sleep(0.1); // Cada VU faz ~10 requisições por segundo
}
