import http from 'k6/http';
import { check, sleep } from 'k6';

const targetUrl = (__ENV.TARGET_URL || 'http://127.0.0.1:8080').replace(
  /\/$/,
  '',
);

export const options = {
  scenarios: {
    web_load: {
      executor: 'ramping-vus',
      startVUs: 0,
      gracefulRampDown: '10s',
      stages: [
        { duration: '20s', target: 50 },
        { duration: '30s', target: 50 },
        { duration: '20s', target: 100 },
        { duration: '30s', target: 100 },
        { duration: '10s', target: 0 },
      ],
    },
  },
  thresholds: {
    checks: ['rate>0.99'],
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<2000'],
  },
};

export default function () {
  const response = http.get(`${targetUrl}/`, {
    tags: { name: 'SnackUp home' },
  });

  check(response, {
    'responde HTTP 200': (result) => result.status === 200,
    'entrega la aplicación Flutter': (result) =>
      result.body.includes('main.dart.js'),
  });

  sleep(1);
}

export function handleSummary(data) {
  const summary = JSON.stringify(data, null, 2);
  return {
    'artifacts/k6-summary.json': summary,
    stdout: `${summary}\n`,
  };
}
