import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
    stages: [
        { duration: '30s', target: 50 }, // ramp up to 50 users
        { duration: '1m', target: 50 },  // stay at 50 users
        { duration: '30s', target: 0 },  // ramp down
    ],
    thresholds: {
        http_req_duration: ['p(95)<100'], // 95% of requests must be below 100ms
    },
};

export default function () {
    const url = 'http://localhost:8082/api/v1/combat/attack';
    const payload = JSON.stringify({
        idempotency_key: '550e8400-e29b-41d4-a716-446655440000',
        player_id: '550e8400-e29b-41d4-a716-446655440001',
        character_id: '550e8400-e29b-41d4-a716-446655440002',
        target_id: '550e8400-e29b-41d4-a716-446655440003',
        action_type: 'NormalAttack'
    });

    const params = {
        headers: {
            'Content-Type': 'application/json',
        },
    };

    let res = http.post(url, payload, params);
    check(res, {
        'status is 200': (r) => r.status === 200,
        'has correct damage': (r) => r.json().damage_dealt > 0,
    });
    sleep(1);
}
