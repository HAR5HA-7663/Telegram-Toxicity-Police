import http from 'k6/http';
import { check, sleep } from 'k6';

// Lighter load test for 1-node cluster
export let options = {
  stages: [
    { duration: '30s', target: 10 },    // Warm up to 10 RPS
    { duration: '1m', target: 30 },     // Ramp to 30 RPS
    { duration: '2m', target: 30 },     // Sustain 30 RPS
    { duration: '30s', target: 50 },    // Spike to 50 RPS (peak)
    { duration: '1m', target: 30 },     // Back to 30 RPS
    { duration: '30s', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% under 2s
    http_req_failed: ['rate<0.1'],     // Less than 10% errors
  },
};

const toxicMessages = [
  'you are stupid',
  'shut up idiot',
  'you are dumb',
  'what a moron',
  'you suck',
];

const normalMessages = [
  'hello there',
  'how are you',
  'nice to meet you',
  'good morning',
  'thank you',
];

export default function () {
  const isToxic = Math.random() < 0.3;
  const messages = isToxic ? toxicMessages : normalMessages;
  const text = messages[Math.floor(Math.random() * messages.length)];

  const payload = JSON.stringify({
    update_id: Math.floor(Math.random() * 1000000),
    message: {
      message_id: Math.floor(Math.random() * 1000000),
      from: {
        id: Math.floor(Math.random() * 10000),
        username: `loadtest_${Math.floor(Math.random() * 100)}`,
        first_name: 'LoadTest'
      },
      chat: {
        id: -1001234567890,
        type: 'supergroup',
        title: 'Load Test Group'
      },
      date: Math.floor(Date.now() / 1000),
      text: text
    }
  });

  const res = http.post('https://bot.har5ha.in/webhook', payload, {
    headers: {
      'Content-Type': 'application/json',
    },
  });

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 2s': (r) => r.timings.duration < 2000,
  });

  sleep(Math.random() * 0.5);
}
