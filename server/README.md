# 合合部落服务器

服务器使用 FastAPI 和 SQLAlchemy，不依赖 Godot。合成、订单、建造这类单机玩法完全在客户端运行，服务器只负责账号、云存档（整份快照）、备份、排行榜，以及对上传存档做合理性检查。

## 运行

```sh
pip install -r server/requirements.txt
python server/run.py
```

默认监听 `127.0.0.1:8765`，使用 SQLite；部署时可配置 PostgreSQL。环境变量示例见 `.env.example`。Docker 的构建上下文为工程根目录：

```sh
docker compose -f server/docker-compose.yml up --build
```

## 接口

| 接口 | 用途 |
| --- | --- |
| `/v1/auth/*`、`/v1/account*` | 游客账号、登录续期、转移码和身份绑定 |
| `/v1/health`、`/v1/time` | 健康检查、服务器时钟 |
| `/v1/rank/top`、`/v1/rank/name` | 按上传存档里建筑进度排名的排行榜，以及昵称 |
| `POST /v2/session` | 取得云端存档：`version`、`hash`、`data`（gzip+Base64），`mine` 表示是否为本设备写入 |
| `POST /v2/save` | 上传整份存档：`{base, hash, data}` |

## 云存档

客户端在本地执行全部玩法命令，写本地检查点和操作日志（防崩溃），每 60 秒、切后台和退出时把整份存档上传。`hash` 是存档 JSON 文本的 SHA-256，`data` 是这段文本 gzip 后再 Base64。服务器校验哈希、大小（解压后默认上限 1 MiB）和基本字段，然后保存。

冲突规则：同一账号同一时间只有一个有效会话。

- 云端版本等于 `base`，或者云端存档也是本设备写的（例如上次的回复丢了）：覆盖，版本号加 1。
- 云端存档由别的设备在 `base` 之后写入：不覆盖，返回 `conflict: true` 和云端存档，客户端载入云端进度。
- 启动时：云端为空则上传本机进度；云端由别的设备更新过，或者是登录另一个账号，则载入云端。

每次覆盖前保留最近 `TRIBE_BACKUPS_RECENT` 份和每天一份备份。

## 合理性检查

上传时把等级、琥珀、贝壳的增量和距上次上传的时长比较（允许量 = burst + 每小时速率 × 小时数，见 `TRIBE_PLAUS_*`）。负数或超出允许量时**不拒绝存档**，只把账号标记为 `flagged`、写审计日志 `save_flagged`，并移出排行榜。首次上传没有基准，只检查负数。

付费货币、内购凭证和多人竞争玩法目前没有服务器接口；接入真实支付时应单独做服务器记账，不依赖上传的存档。

## 验证

```sh
pip install -r server/requirements-dev.txt
TRIBE_GODOT=/path/to/godot python -m pytest -q server/tests
godot --headless --path . --script res://tools/check_cloud_save.gd -- --replay-test --cloud-off --save=user://cloud_save_check/boot.json --cloud-state=user://cloud_save_check/boot-cloud.json
```

`test_save.py` 覆盖上传、冲突、丢失回复、旧设备被顶下线、完整性错误、备份和合理性标记。`test_rules_replay.py`、`test_reducer_domains.py` 等直接调用 `scripts/replay/worker.gd` 检查共享玩法规则，需要设置 `TRIBE_GODOT`，未设置时跳过。`check_cloud_save.gd` 用真实客户端连临时服务器做端到端检查。
