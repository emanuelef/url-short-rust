import http from 'k6/http';
import { check, sleep } from 'k6';
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';

// Configuration for the load test
export const options = {
  // Define stages for ramping up over 5 minutes to 20 VUs
  stages: [
    { duration: '1m', target: 5 },   // Ramp-up to 5 users in 1 minute
    { duration: '1m', target: 10 },  // Ramp-up to 10 users in 1 minute
    { duration: '1m', target: 15 },  // Ramp-up to 15 users in 1 minute
    { duration: '1m', target: 20 },  // Ramp-up to 20 users in 1 minute
    { duration: '1m', target: 20 },  // Stay at 20 users for 1 minute
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.01'],   // Less than 1% of requests should fail
  },
};

// Generate a random URL (equivalent to the Python random_url function)
function randomUrl() {
  const domain = randomString(8, 'abcdefghijklmnopqrstuvwxyz');
  const tlds = ['com', 'net', 'org', 'io', 'dev'];
  const tld = tlds[Math.floor(Math.random() * tlds.length)];
  const path = Math.floor(Math.random() * 10000) + 1;
  return `https://${domain}.${tld}/path/${path}`;
}

// The default function that k6 will execute
export default function() {
  // Create a short URL (equivalent to the shorten_url task)
  const url = randomUrl();
  const payload = JSON.stringify({ url: url });
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };
  
  const res = http.post('http://localhost:3000/api/shorten', payload, params);
  
  // Verify the request was successful
  check(res, {
    'status is 200': (r) => r.status === 200,
    'has short_url': (r) => JSON.parse(r.body).short_url !== undefined,
  });
  
  // Optional - add a small pause between requests
  sleep(1);
}
