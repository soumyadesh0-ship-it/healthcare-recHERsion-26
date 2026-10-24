"""Run the installed Dart analyzer's line protocol if LSP fails on a Unicode path.

Usage: python tool/analyze_fallback.py C:/path/to/flutter
Does not change SDK or project configuration. Normal flutter analyze is preferred.
"""
import json
import queue
import subprocess
import sys
import threading
import time
from pathlib import Path

sdk = Path(sys.argv[1]) / 'bin/cache/dart-sdk'
project = Path(__file__).resolve().parents[1]
process = subprocess.Popen(
    [str(sdk / 'bin/dartaotruntime.exe'),
     str(sdk / 'bin/snapshots/analysis_server_aot.dart.snapshot'),
     '--protocol=analyzer', '--disable-server-feature-completion',
     '--disable-server-feature-search'],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    text=True, encoding='utf-8',
)
messages = queue.Queue()
def read():
    for line in process.stdout:
        messages.put(json.loads(line))
threading.Thread(target=read, daemon=True).start()
def send(identifier, method, params=None):
    process.stdin.write(json.dumps({'id':identifier, 'method':method, 'params':params or {}})+'\n')
    process.stdin.flush()
send('1', 'server.setSubscriptions', {'subscriptions':['STATUS']})
send('2', 'analysis.setAnalysisRoots', {'included':[str(project)], 'excluded':[
    str(project/'build'),str(project/'android'),str(project/'ios')]})
diagnostics = {}
started = False
deadline = time.monotonic()+90
try:
    while time.monotonic()<deadline:
        message=messages.get(timeout=30)
        if 'error' in message:
            raise RuntimeError(message['error'])
        if message.get('event')=='analysis.errors':
            diagnostics[message['params']['file']]=message['params']['errors']
        if message.get('event')=='server.status':
            active=message['params'].get('analysis',{}).get('isAnalyzing')
            if active:
                started=True
            if started and active is False:
                break
    else:
        raise TimeoutError('Analysis did not finish')
    errors=0
    for file,issues in sorted(diagnostics.items()):
        for issue in issues:
            location=issue['location']
            print(f"{issue['severity']} {Path(file).relative_to(project)}:{location['startLine']}: {issue['message']} ({issue['code']})")
            errors+=1
    print(f'Analyzer protocol fallback: {errors} issues in the actual package.')
    sys.exit(bool(errors))
finally:
    send('3','server.shutdown')
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.terminate()
