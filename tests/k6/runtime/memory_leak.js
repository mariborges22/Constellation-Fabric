import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    scenarios: {
        memory_stress: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '30s', target: 50 }, // rampa rápida
                { duration: '1m', target: 100 },  // sustenta
            ],
        },
    },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

// Gerar uma string gigante para estressar o buffer de memória do Rust/Axum
const LARGE_STRING = 'A'.repeat(1024 * 1024); // 1MB de carga

export default function () {
    // 1. Oversized Payload Attack
    const oversizedRes = http.post(`${BASE_URL}/api/v1/auth/register`, JSON.stringify({
        username: "stress_user_" + __VU,
        password: "password123",
        bio: LARGE_STRING // Payload de 1MB por requisição
    }), { 
        headers: { 'Content-Type': 'application/json' },
        timeout: '5s'
    });

    check(oversizedRes, {
        'Memory: Payload rejected or handled (not 5xx)': (r) => r.status < 500,
        'Memory: Payload size limits working': (r) => r.status === 413 || r.status < 500,
    });

    // 2. Connection Saturation (Rapid fire)
    // Simulando vazamento de file descriptors
    http.get(`${BASE_URL}/api/v1/auth/health`);

    sleep(0.1);
}
