import { createServer } from 'node:net';
import { readFileSync, existsSync, appendFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

const parent = process.ppid;
if (parent === 1) process.exit(0);
setInterval(() => {
  try { process.kill(parent, 0); }
  catch (error) { if (error.code === 'ESRCH') process.exit(0); }
}, 250).unref();

const socketPath = process.argv[2];
let state = 'off';
let config = [];
createServer(socket => {
  let request = Buffer.alloc(0);
  socket.on('error', () => {});
  socket.on('data', data => {
    request = Buffer.concat([request, data]);
    const boundary = request.indexOf('\r\n\r\n');
    if (boundary < 0) return;
    const [line, ...headers] = request.subarray(0, boundary).toString().split('\r\n');
    const header = Object.fromEntries(headers.map(value => {
      const colon = value.indexOf(':');
      return [value.slice(0, colon).toLowerCase(), value.slice(colon + 1).trim()];
    }));
    const length = Number(header['content-length'] || 0);
    if (request.length < boundary + 4 + length) return;
    socket.removeAllListeners('data');
    const [method, path] = line.split(' ');
    appendFileSync(join(dirname(socketPath), 'requests.log'), `${path}\n`);
    const reply = (status, body) => {
      const json = JSON.stringify(body);
      socket.end(`HTTP/1.1 ${status} Response\r\nContent-Length: ${Buffer.byteLength(json)}\r\nConnection: close\r\n\r\n${json}`);
    };
    const token = readFileSync(join(dirname(socketPath), 'portato.token'), 'utf8');
    if (header.authorization !== `Bearer ${token}`) return reply(401, { error: 'unauthorized' });
    const overrideFile = join(dirname(socketPath), 'responses.json');
    if (existsSync(overrideFile)) {
      const override = JSON.parse(readFileSync(overrideFile, 'utf8'))[path];
      if (override) return reply(override.status, override.body);
    }
    const body = () => JSON.parse(request.subarray(boundary + 4, boundary + 4 + length));
    if (method === 'GET') {
      if (path === '/info') return reply(200, { protocol: 1, config_path: '/tmp/config.yaml' });
      if (path === '/config') return reply(200, { tubers: config });
      if (path === '/events') {
        socket.write('HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n');
        for (const frame of [': heartbeat\n\n', 'data:', ' {}\n', '\n']) {
          socket.write(`${Buffer.byteLength(frame).toString(16)}\r\n${frame}\r\n`);
        }
        return socket.end('0\r\n\r\n');
      }
      return reply(200, [{ name: 'web', type: 'local', local: '127.0.0.1:3200', remote: '127.0.0.1:3000', state }]);
    }
    if (method === 'POST') {
      if (path === '/tubers') { config.push(body()); return reply(201, { status: 'created' }); }
      if (path === '/reload') return reply(200, { ok: true });
      if (['/tubers/web/enable', '/tubers/web/restart'].includes(path)) state = 'connected';
      else if (path === '/tubers/web/disable') state = 'off';
      else return reply(404, { error: 'unknown tunnel' });
      return reply(200, { status: state });
    }
    if (method === 'PUT') { config[0] = body(); return reply(200, { status: 'updated' }); }
    if (method === 'DELETE') { config = []; return reply(200, { status: 'deleted' }); }
    reply(404, { error: 'unknown route' });
  });
}).listen(socketPath);
