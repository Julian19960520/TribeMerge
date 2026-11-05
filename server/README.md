# 排行榜服务器

按「部落解锁进度」（已建成的建造部件总数）给玩家排名。只用 Python 3 标准库，不用装依赖。

## 启动

双击 `启动排行榜服务器.bat`，或：

```
python server/rank_server.py --host 127.0.0.1 --port 8765 --db server/rank.db
```

默认监听 `http://127.0.0.1:8765`，数据存在 `server/rank.db`（SQLite，已在 .gitignore 里）。
游戏连哪个地址由 `data/rules.json` 的 `rank_server` 决定。

## 接口

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/health` | 健康检查，返回 `{"ok": true}` |
| POST | `/api/submit` | 提交成绩，body：`{"id": "TRB12345678", "name": "昵称", "progress": 7, "time": 1793000000}`。`time` 是达到这个进度的 Unix 时间（秒），缺省取服务器时间，未来时间会被截到当前。返回 `{"ok", "rank", "total", "progress"}` |
| GET | `/api/top?n=50&id=TRB12345678` | 前 n 名（最多 200），并返回自己的名次 `me`（没提交过为 null） |

规则：
- 每个 id 只保留最高进度。进度上涨时记录新的达成时间；进度没涨只更新昵称。
- 排序：进度从高到低；平分时先达到的排前面；再相同按 id。
- id 只允许字母、数字、`_`、`-`，最长 32；昵称最长 16 字。

## 手动验证

```
curl -X POST http://127.0.0.1:8765/api/submit -H "Content-Type: application/json" -d "{\"id\":\"TEST1\",\"name\":\"测试\",\"progress\":3}"
curl "http://127.0.0.1:8765/api/top?n=10&id=TEST1"
```

或运行 `python server/test_rank.py`（会在临时目录起一个独立服务器，不碰 rank.db）。
