import http from 'k6/http';
import { check } from 'k6';

export const options = {
    vus: 10,
    duration: '10s',
};

const US_URL = __ENV.US_URL || 'http://constellation-fabric-us-east-1-a-176562278.us-east-1.elb.amazonaws.com';

export default function () {
    let res = http.get(`${US_URL}/health`);
    check(res, {
        'Rate-Limit: system remains stable': (r) => r.status === 200 || r.status === 429,
    });
}
