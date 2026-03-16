import http from 'k6/http';
import { check } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

const US_URL = __ENV.US_URL || 'http://constellation-fabric-us-east-1-a-176562278.us-east-1.elb.amazonaws.com';

export default function () {
    // --- IDOR Test ---
    const victimId = uuidv4();
    let resIdor = http.get(`${US_URL}/api/v1/players/${victimId}`);
    check(resIdor, {
        'IDOR: blocked or handled correctly (404/403)': (r) => r.status === 404 || r.status === 403,
    });

    // --- JWT/Auth Test ---
    const params = {
        headers: { 'Authorization': 'Bearer fake-malicious-token' },
    };
    let resAuth = http.get(`${US_URL}/api/v1/combat/health`, params);
    check(resAuth, {
        'Auth: unauthorized access rejected': (r) => r.status === 401 || r.status === 403 || r.status === 422,
    });
}
