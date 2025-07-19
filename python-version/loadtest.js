import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';

// Custom metrics
const successfulRedirects = new Counter('successful_redirects');
const failedRedirects = new Counter('failed_redirects');

// Test configuration for 1 minute and 30 seconds
export const options = {
  stages: [
    { duration: '30s', target: 50 },   // Ramp-up to 50 VUs over 30 seconds
    { duration: '30s', target: 100 },  // Ramp-up to 100 VUs over 30 seconds
    { duration: '30s', target: 100 },  // Stay at 100 VUs for 30 seconds
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests should be below 500ms
    'http_req_duration{type:shorten}': ['p(95)<1000'],  // 95% of shortening operations should be below 1000ms
    'http_req_duration{type:redirect}': ['p(95)<300'],  // 95% of redirects should be below 300ms
    http_req_failed: ['rate<0.01'],   // Less than 1% of requests should fail
  },
};

// Shared array to store shortened URLs
const shortUrls = [];

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:3000';
  
  // Create a shortened URL
  const payload = JSON.stringify({
    url: `https://example.com/test/${Math.random()}`,
  });
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    tags: { type: 'shorten' },
  };
  
  const shortenResponse = http.post(`${baseUrl}/api/shorten`, payload, params);
  
  check(shortenResponse, {
    'shorten status is 200': (r) => r.status === 200,
    'shorten response has short_url': (r) => r.json().short_url !== undefined,
  });
  
  // Add the URL to our collection if successful
  if (shortenResponse.status === 200) {
    const shortUrl = shortenResponse.json().short_url;
    const shortCode = shortUrl.split('/').pop();
    shortUrls.push(shortCode);
  }
  
  // Use an existing short URL if available
  if (shortUrls.length > 0) {
    // Get a random short URL from our collection
    const randomIndex = Math.floor(Math.random() * shortUrls.length);
    const shortCode = shortUrls[randomIndex];
    
    // Redirect using the short URL
    const redirectResponse = http.get(`${baseUrl}/${shortCode}`, { 
      tags: { type: 'redirect' },
      redirects: 0,  // Don't follow redirects automatically to measure performance
    });
    
    const isSuccessful = check(redirectResponse, {
      'redirect status is 301': (r) => r.status === 301,
      'redirect header has location': (r) => r.headers.Location !== undefined,
    });
    
    if (isSuccessful) {
      successfulRedirects.add(1);
    } else {
      failedRedirects.add(1);
    }
  }
  
  // Access analytics endpoint occasionally
  if (Math.random() < 0.1) {
    const analyticsResponse = http.get(`${baseUrl}/api/analytics`, { 
      tags: { type: 'analytics' },
    });
    
    check(analyticsResponse, {
      'analytics status is 200': (r) => r.status === 200,
      'analytics response has total_urls': (r) => r.json().total_urls !== undefined,
    });
  }
  
  // Small sleep to make the test more realistic
  sleep(Math.random() * 0.5);
}
