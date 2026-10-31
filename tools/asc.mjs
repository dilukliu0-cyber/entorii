// Мини-клиент App Store Connect API.
// node tools/asc.mjs GET /v1/bundleIds?filter[identifier]=com.diluk.entorii
// node tools/asc.mjs POST /v1/bundleIds '{"data":{...}}'
// Ключ: ASC_KEY_PATH (файл .p8), ASC_KEY_ID, ASC_ISSUER_ID — из переменных окружения.
import crypto from 'node:crypto';
import fs from 'node:fs';

const { ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID } = process.env;
if (!ASC_KEY_PATH || !ASC_KEY_ID || !ASC_ISSUER_ID) {
  console.error('Нужны ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID');
  process.exit(1);
}

const b64 = (o) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const head = b64({ alg: 'ES256', kid: ASC_KEY_ID, typ: 'JWT' });
const body = b64({ iss: ASC_ISSUER_ID, iat: now, exp: now + 1100, aud: 'appstoreconnect-v1' });
const sig = crypto.sign('sha256', Buffer.from(`${head}.${body}`), {
  key: fs.readFileSync(ASC_KEY_PATH, 'utf8'),
  dsaEncoding: 'ieee-p1363',
}).toString('base64url');
const token = `${head}.${body}.${sig}`;

const [method = 'GET', path = '/v1/apps', arg] = process.argv.slice(2);
// Тело можно передать файлом: @body.json (PowerShell портит кавычки в аргументах).
const payload = arg?.startsWith('@') ? fs.readFileSync(arg.slice(1), 'utf8') : arg;
const res = await fetch('https://api.appstoreconnect.apple.com' + path, {
  method,
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: payload,
});
const text = await res.text();
console.log(res.status);
console.log(text);
