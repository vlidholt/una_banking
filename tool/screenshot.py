"""Screenshots a page in headless Chrome after a real-time wait, over the
DevTools protocol: usage cdp_shot.py URL OUT WIDTH HEIGHT SCALE WAIT."""
import base64, json, subprocess, sys, time, urllib.request, tempfile

import websocket

url, out, width, height, scale, wait = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6])
chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
profile = tempfile.mkdtemp()
proc = subprocess.Popen([chrome, '--headless=new', '--remote-debugging-port=9333',
    f'--user-data-dir={profile}', '--hide-scrollbars', 'about:blank'],
    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    for _ in range(50):
        try:
            targets = json.load(urllib.request.urlopen('http://127.0.0.1:9333/json'))
            page = next(t for t in targets if t['type'] == 'page')
            break
        except Exception:
            time.sleep(.2)
    ws = websocket.create_connection(page['webSocketDebuggerUrl'])
    n = [0]
    def call(method, **params):
        n[0] += 1
        ws.send(json.dumps({'id': n[0], 'method': method, 'params': params}))
        while True:
            msg = json.loads(ws.recv())
            if msg.get('id') == n[0]:
                return msg.get('result', {})
    call('Emulation.setDeviceMetricsOverride', width=width, height=height,
         deviceScaleFactor=scale, mobile=width < 600)
    call('Page.enable')
    call('Page.navigate', url=url)
    time.sleep(wait)
    shot = call('Page.captureScreenshot', format='png')
    open(out, 'wb').write(base64.b64decode(shot['data']))
    print('saved', out)
finally:
    proc.kill()
