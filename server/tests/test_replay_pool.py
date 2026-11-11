"""Process reuse, bounded admission and recovery are observable pool contracts."""
import json
import sys
import threading
from concurrent.futures import ThreadPoolExecutor

import pytest

from app.errors import ApiError
from app.replay_engine import ReplayPool, ReplayProcess

WORKER = '''import json,os,sys,time
print('worker startup',flush=True)
for line in sys.stdin:
    value=json.loads(line)
    time.sleep(value.get('delay',0))
    if value.get('exit'): sys.exit(2)
    print('TRIBE_REPLAY_RESPONSE '+json.dumps({'ok':True,'engine':'4.6.3-stable (official)','pid':os.getpid(),'value':value}),flush=True)
'''


@pytest.fixture()
def processes(monkeypatch):
    monkeypatch.setattr(ReplayProcess, 'command', lambda self, directory: [sys.executable, '-u', '-c', WORKER])


def test_one_process_is_reused_and_requests_do_not_cross(processes):
    pool = ReplayPool(sys.executable, 1, 1, 0.2, 1)
    try:
        first = pool.run({'player':'A','seed':'first'})
        second = pool.run({'player':'B','seed':'second'})
        assert first['pid'] == second['pid']
        assert second['value'] == {'player':'B','seed':'second'}
        assert pool.processes[0].starts == 1
    finally:
        pool.close()
    assert pool.processes[0].process is None


def test_timeout_discards_process_and_next_request_recovers(processes):
    pool = ReplayPool(sys.executable, 1, 0, 0.2, 0.1)
    try:
        with pytest.raises(ApiError) as error:
            pool.run({'delay': 2})
        assert error.value.error == 'replay_timeout'
        assert pool.run({'player':'B'})['value'] == {'player':'B'}
        assert pool.processes[0].starts == 2
    finally:
        pool.close()


def test_exited_process_is_replaced(processes):
    pool = ReplayPool(sys.executable, 1, 0, 0.2, 1)
    try:
        with pytest.raises(ApiError): pool.run({'exit':True})
        assert pool.run({'player':'healthy'})['ok']
        assert pool.processes[0].starts == 2
    finally:
        pool.close()


def test_admission_does_not_create_unbounded_processes(monkeypatch):
    started, release = threading.Event(), threading.Event()
    def execute(self, payload, timeout):
        started.set()
        assert release.wait(2)
        return {'ok':True}
    monkeypatch.setattr(ReplayProcess, 'call', execute)
    pool = ReplayPool(sys.executable, 1, 0, 0.05, 1)
    try:
        with ThreadPoolExecutor(max_workers=2) as executor:
            pending = executor.submit(pool.run, {})
            assert started.wait(1)
            with pytest.raises(ApiError) as error: pool.run({})
            assert error.value.error == 'replay_busy'
            assert len(pool.processes) == 1
            release.set()
            assert pending.result()['ok']
    finally:
        release.set(); pool.close()


def test_waiting_request_has_a_deadline_and_capacity_is_released(monkeypatch):
    started, release = threading.Event(), threading.Event()
    def execute(self, payload, timeout):
        started.set(); assert release.wait(2)
        return {'ok':True}
    monkeypatch.setattr(ReplayProcess, 'call', execute)
    pool = ReplayPool(sys.executable, 1, 1, 0.03, 1)
    try:
        with ThreadPoolExecutor(max_workers=2) as executor:
            pending = executor.submit(pool.run, {})
            assert started.wait(1)
            with pytest.raises(ApiError) as error: pool.run({})
            assert error.value.error == 'replay_busy'
            release.set(); assert pending.result()['ok']
        assert pool.run({})['ok']
    finally:
        release.set(); pool.close()


def test_script_error_during_boot_is_not_accepted_as_a_healthy_worker(monkeypatch):
    script="print('SCRIPT ERROR: failed to compile rule module',flush=True);import time;time.sleep(2)"
    monkeypatch.setattr(ReplayProcess,'command',lambda self,directory:[sys.executable,'-u','-c',script])
    pool=ReplayPool(sys.executable,1,0,0.1,1)
    try:
        with pytest.raises(ApiError) as failure: pool.run({'mode':'rules'})
        assert failure.value.error=='replay_failed'
        assert pool.processes[0].process is None
    finally: pool.close()


def test_first_rules_initialization_has_a_bounded_wait(monkeypatch):
    started,release=threading.Event(),threading.Event()
    def execute(self,payload,timeout):
        started.set();assert release.wait(2)
        return {'ok':True,'rules':'ab'*32}
    monkeypatch.setattr(ReplayProcess,'call',execute)
    pool=ReplayPool(sys.executable,1,1,0.03,1)
    try:
        with ThreadPoolExecutor(max_workers=2) as executor:
            pending=executor.submit(pool.rules)
            assert started.wait(1)
            with pytest.raises(ApiError) as failure: pool.rules()
            assert failure.value.error=='replay_busy'
            release.set();assert pending.result()=='ab'*32
        assert pool.rules()=='ab'*32
    finally:release.set();pool.close()
