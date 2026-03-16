import http from 'k6/http';
import { check } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

const US_URL = __ENV.US_URL || 'http://constellation-fabric-us-east-1-a-176562278.us-east-1.elb.amazonaws.com';

export default function () {
    const maliciousPayload = JSON.stringify({
        idempotency_key: uuidv4(),
        player_id: uuidv4(),
        character_id: "hack-client-v1", // Invalid UUID format
        target_id: uuidv4(),
        action_type: "InstaKill_Admin" // Non-existent enum value
    });

    let res = http.post(`${US_URL}/api/v1/combat/attack`, maliciousPayload, {
        headers: { 'Content-Type': 'application/json' },
    });

    check(res, {
        'Anti-Cheat: Malformed payload rejected by Rust/Serde (422)': (r) => r.status === 422 || r.status === 400,
    });
}
