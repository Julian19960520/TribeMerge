"""排行榜服务器自测：在临时目录起一个独立实例，跑一遍提交/查询/平分/非法输入。"""

import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

PORT = 18765
BASE = "http://127.0.0.1:%d" % PORT


def call(path, body=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(BASE + path, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=3) as r:
            return r.status, json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode("utf-8"))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    tmp = tempfile.mkdtemp()
    proc = subprocess.Popen([sys.executable, os.path.join(here, "rank_server.py"), "--port", str(PORT),
                             "--db", os.path.join(tmp, "t.db")], stdout=subprocess.DEVNULL)
    try:
        for _ in range(50):
            try:
                if call("/api/health")[1].get("ok"):
                    break
            except OSError:
                time.sleep(0.1)
        t = time.time() - 1000
        assert call("/api/submit", {"id": "A", "name": "甲", "progress": 5, "time": t})[1]["rank"] == 1
        assert call("/api/submit", {"id": "B", "name": "乙", "progress": 5, "time": t + 10})[1]["rank"] == 2
        assert call("/api/submit", {"id": "C", "name": "丙", "progress": 9, "time": t + 20})[1]["rank"] == 1
        # 进度回退不生效，只改昵称
        r = call("/api/submit", {"id": "C", "name": "丙丙", "progress": 1})[1]
        assert r["progress"] == 9 and r["rank"] == 1, r
        code, d = call("/api/top?n=2&id=B")
        assert code == 200 and [x["id"] for x in d["top"]] == ["C", "A"], d
        assert d["me"]["rank"] == 3 and d["total"] == 3 and d["top"][0]["name"] == "丙丙", d
        assert call("/api/top?n=5&id=nobody")[1]["me"] is None
        assert call("/api/submit", {"id": "bad id!", "progress": 1})[0] == 400
        assert call("/api/submit", {"id": "D", "progress": -1})[0] == 400
        print("OK: rank server self-test passed")
    finally:
        proc.terminate()
        proc.wait()


if __name__ == "__main__":
    main()
