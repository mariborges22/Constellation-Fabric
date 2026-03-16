import http from 'k6/http';
import { check } from 'k6';

export const options = {
    thresholds: { 'http_req_failed': ['rate<0.01'] }, 
};

const US_URL = __ENV.US_URL || 'http://constellation-fabric-us-east-1-a-176562278.us-east-1.elb.amazonaws.com';

export default function () {
    const payloads = [
        "' OR '1'='1",
        "'; DROP TABLE players; --",
        "1; SELECT pg_sleep(5)"
    ];

    payloads.forEach(sql => {
        let res = http.get(`${US_URL}/api/v1/players/${encodeURIComponent(sql)}`);
        check(res, {
            'SQLi: status is NOT 500 (No Crash)': (r) => r.status < 500,
            'SQLi: rejected or handled (4xx)': (r) => r.status >= 400 && r.status < 500,
        });
    });
}
