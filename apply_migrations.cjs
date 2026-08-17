// Applies the combined Accommo migration script via the Supabase SQL API.
// Usage (from project root):  set SB_KEY=service_role_xxx && node apply_migrations.cjs
// The key is read from env (never echoed). Output is truncated; no secret printed.
const fs = require('fs');
const https = require('https');
const path = require('path');

const KEY = process.env.SB_KEY;
if (!KEY) {
  console.error('ERROR: set SB_KEY to the service_role key first.');
  process.exit(1);
}

const sqlFile = path.join(__dirname, 'apply_all_migrations.sql');
const sql = fs.readFileSync(sqlFile, 'utf8');
const body = sql;
const projectRef = 'xuckyyjzfwtxxiwmxvco';

const req = https.request(
  {
    hostname: `${projectRef}.supabase.co`,
    path: '/rest/v1/sql',
    method: 'POST',
    headers: {
      Authorization: `Bearer ${KEY}`,
      apikey: KEY,
      'Content-Type': 'text/plain; charset=utf-8',
      'Content-Length': Buffer.byteLength(body),
    },
  },
  (res) => {
    let out = '';
    res.on('data', (c) => (out += c));
    res.on('end', () => {
      console.log('HTTP', res.statusCode);
      console.log(out.slice(0, 3000));
    });
  },
);
req.on('error', (e) => {
  console.error('REQUEST ERROR:', e.message);
  process.exit(1);
});
req.write(body);
req.end();
