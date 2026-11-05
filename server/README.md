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

## 云存档 + 热卖

同一个服务器还提供云存档和集市热卖（`cloud.py`，配置 `cloud_config.json`，规则和开销估算见 DESIGN.md「十二」）：

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/api/register` | `{"id"}` → `{"token"}`。id 已注册返回 409 |
| GET | `/api/save?id=` | 头 `X-Token`。→ `{"version", "hash", "data"}`，data 是 base64 的 gzip JSON，没传过是空串 |
| POST | `/api/save` | 头 `X-Token`。`{"id", "base", "hash", "data"}` → `{"version"}`；base 落后 409，校验不过 422（带 reason） |
| POST | `/api/purchase` | 头 `X-Token`。`{"id", "amber"}`：充值到账，下一份快照放行这么多琥珀 |
| GET | `/api/hot?id=` | 头 `X-Token`。当天热卖换货 `{"picks": [{"slot", "id"}]}`，每人每天只抽一次；没快照 404 |
| GET | `/api/time` | 服务器时间 |

所有成功返回都带 `now`（服务器 Unix 时间）和 `day`（北京日期）。自测：`python server/test_cloud.py`。
