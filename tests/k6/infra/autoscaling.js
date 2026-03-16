import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    stages: [
        { duration: '1m', target: 200 }, // Rampa agressiva de 0 a 200 VUs em 1 min
        { duration: '2m', target: 500 }, // Forçar limite do Fargate
        { duration: '1m', target: 0 },   // Cool down
    ],
    thresholds: {
        http_req_duration: ['p(95)<2000'], // Performance aceitável mesmo sob carga
    },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
    const res = http.get(`${BASE_URL}/api/v1/auth/health`);
    
    check(res, {
        'Autoscaling: Service alive': (r) => r.status === 200,
    });

    // Simular carga de CPU real (mais complexo que health check)
    http.post(`${BASE_URL}/api/v1/auth/login`, JSON.stringify({
        username: "load_test_" + __VU,
        password: "password123"
    }), { headers: { 'Content-Type': 'application/json' } });

    sleep(0.2);
}
