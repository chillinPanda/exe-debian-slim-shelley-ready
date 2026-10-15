#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
// Run on the host: only Chromium itself is needed inside the image/VM.
import { spawn, execFileSync } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

const args = process.argv.slice(2);
const remote = args[0] === '--ssh';
const existing = args[0] === '--container';
const target = (remote || existing) ? args[1] : (args[0] || 'exe-debian-slim-shelley-ready:dev');
const screenshot = (remote || existing) ? args[2] : args[1];
if (!target) throw new Error('Supply an image, or --ssh followed by an SSH destination.');
const platform = (remote || existing) ? null : execFileSync('docker', ['image', 'inspect', '--format', '{{.Os}}/{{.Architecture}}', target], { encoding: 'utf8' }).trim();
const started = performance.now();
const command = 'exec headless-shell --no-sandbox --remote-debugging-pipe 3<&0 4>&1';
const child = remote
  ? spawn('ssh', ['-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', target, command])
  : existing ? spawn('docker', ['exec', '--user', 'exedev', '-i', target, '/bin/sh', '-c', command])
  : spawn('docker', ['run', '--rm', '--platform', platform, '--network', 'none',
      '--user', 'exedev', '--shm-size=256m', '--tmpfs', '/run/browser:rw,exec,nosuid,nodev,uid=1000,gid=1000,mode=0700,size=320m', '--entrypoint', '/bin/sh', '-i', target, '-c', command]);
let stderr = '';
child.stderr.on('data', data => { stderr = (stderr + data).slice(-12000); });
let pendingData = '';
let nextID = 0;
const pending = new Map();
child.stdout.on('data', data => {
  pendingData += data;
  for (;;) {
    const end = pendingData.indexOf('\0');
    if (end < 0) break;
    const raw = pendingData.slice(0, end);
    pendingData = pendingData.slice(end + 1);
    if (!raw) continue;
    const message = JSON.parse(raw);
    const waiter = pending.get(message.id);
    if (waiter) {
      pending.delete(message.id);
      if (message.error) waiter.reject(new Error(JSON.stringify(message.error)));
      else waiter.resolve(message.result);
    }
  }
});
child.on('error', error => { for (const waiter of pending.values()) waiter.reject(error); });
child.on('exit', code => {
  for (const waiter of pending.values()) waiter.reject(new Error(`Browser transport exited (${code}): ${stderr}`));
});
function call(method, params = {}, sessionId) {
  const id = ++nextID;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    child.stdin.write(JSON.stringify({ id, method, params, ...(sessionId && { sessionId }) }) + '\0');
  });
}
function check(condition, description) {
  if (!condition) throw new Error(description);
}
const deadline = setTimeout(() => {
  console.error(`Browser test timed out. ${stderr}`);
  child.kill('SIGKILL');
  process.exit(1);
}, 60000);
try {
  const version = await call('Browser.getVersion');
  const startupMs = Math.round(performance.now() - started);
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const page = (method, params) => call(method, params, sessionId);
  await page('Page.enable');
  await page('Runtime.enable');
  const evaluate = async expression => {
    const result = await page('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    return result.result.value;
  };
  const html = `<!doctype html><meta charset="utf-8"><title>Shelley browser test</title>
<style>body{font:24px sans-serif;padding:32px;background:#f4f7fb;color:#17324d}input,button{font:inherit;padding:10px}canvas{display:block;margin-top:24px}</style>
<h1>Grüße from Shelley 🙂</h1><label>Name <input id="name"></label>
<button id="save" onclick="document.querySelector('#result').textContent='Saved: '+document.querySelector('#name').value">Save</button>
<p id="result">Waiting</p><canvas id="canvas" width="240" height="100"></canvas>
<script>const c=document.querySelector('canvas').getContext('2d');c.fillStyle='#189b69';c.fillRect(0,0,240,100);c.fillStyle='white';c.fillText('Canvas works',20,50)</script>`;
  await page('Page.navigate', { url: 'data:text/html;charset=utf-8,' + encodeURIComponent(html) });
  await evaluate(`new Promise(resolve => { if(document.readyState==='complete') resolve(true); else addEventListener('load',()=>resolve(true),{once:true}); })`);
  check(await evaluate('document.title') === 'Shelley browser test', 'Page navigation/title failed');
  await evaluate('document.querySelector("#name").focus()');
  await page('Input.insertText', { text: 'Shelley' });
  const point = await evaluate('(()=>{const r=document.querySelector("#save").getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}})()');
  await page('Input.dispatchMouseEvent', { type: 'mousePressed', button: 'left', clickCount: 1, ...point });
  await page('Input.dispatchMouseEvent', { type: 'mouseReleased', button: 'left', clickCount: 1, ...point });
  check(await evaluate('document.querySelector("#result").textContent') === 'Saved: Shelley', 'Input/click failed');
  check(await evaluate('Array.from(document.querySelector("#canvas").getContext("2d").getImageData(0,0,1,1).data).join(",")') === '24,155,105,255', 'Canvas rendering failed');
  const webgl = await evaluate('(()=>{const gl=document.createElement("canvas").getContext("webgl");if(!gl)return false;gl.clearColor(0.125,0.25,0.5,1);gl.clear(gl.COLOR_BUFFER_BIT);const p=new Uint8Array(4);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,p);return Array.from(p).join(",")})()');
  check(webgl === '32,64,128,255', 'WebGL rendering failed');
  const png = Buffer.from((await page('Page.captureScreenshot', { format: 'png' })).data, 'base64');
  check(png.subarray(0, 8).toString('hex') === '89504e470d0a1a0a', 'Invalid screenshot');
  if (screenshot) { await mkdir(dirname(screenshot), { recursive: true }); await writeFile(screenshot, png); }
  if (remote) {
    const navigation = await page('Page.navigate', { url: 'https://example.com' });
    check(!navigation.errorText, `HTTPS navigation failed: ${navigation.errorText}`);
    await evaluate(`new Promise(resolve => { if(document.readyState==='complete') resolve(true); else addEventListener('load',()=>resolve(true),{once:true}); })`);
    check(await evaluate('document.title') === 'Example Domain', 'HTTPS title failed');
  }
  console.log(JSON.stringify({ browser: version.product, startupMs, totalMs: Math.round(performance.now() - started), javascript: true, typing: true, clicking: true,
    canvas2d: true, webgl: true, screenshotBytes: png.length, https: remote ? true : 'not tested (offline)' }));
  await call('Browser.close');
} catch (error) {
  console.error(error.message);
  console.error(stderr);
  child.kill('SIGKILL');
  process.exitCode = 1;
} finally {
  clearTimeout(deadline);
  child.stdin.end();
}
