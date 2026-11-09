# 游戏服务器

账号、云存档、服务器经济（货币、集市、建造、通行证、卡包、领奖）、热卖、排行榜。
FastAPI + Uvicorn，SQLAlchemy 2 + Alembic，本地 SQLite / 正式 PostgreSQL。
设计、归属表、接口清单、部署和开销估算见仓库根目录 `DESIGN.md`「十二」。

活动棋盘与主棋盘一样即时在本地操作，`merge_board` 事件通过 `/v1/events` 或
`PUT /v1/save` 分批同步；服务端按队列顺序回放，阶段领奖仍单独确认。
先部署支持该事件的服务端，再更新联网客户端；旧版逐操作接口继续兼容。
Godot 联调：`--headless --path . --script tools/check_merge_event_cloud.gd -- --python=/path/to/python`。

## 启动

不用 Docker（Python 3.12）：

```
pip install -r server/requirements.txt
python server/run.py                 # 先 alembic upgrade head，再起 Uvicorn：http://127.0.0.1:8765
```

或双击 `启动服务器.bat`（第一次自动装依赖）。数据在 `server/tribe.db`。接口文档：http://127.0.0.1:8765/docs

用 Docker（app + PostgreSQL）：

```
cd server
docker compose up --build
```

配置全部是 `TRIBE_` 开头的环境变量，复制 `.env.example` 为 `.env` 再改。正式环境前面必须放 HTTPS 反向代理。

## 测试

```
pip install -r server/requirements-dev.txt
cd server && python -m pytest -q
```

游戏联调（自起临时服务器，两台设备各一套测试文件）：

```
Godot_v4.6.3-stable_win64_console.exe --headless --path . --script tools/cloud_check.gd
```

## 表结构迁移

```
cd server
alembic revision --autogenerate -m "说明"   # 生成迁移，检查后提交
alembic upgrade head                        # run.py 启动时也会自动执行
```

## 离线操作重放（v2）

客户端登录后调用 `POST /v2/session`，取得服务器确认过的存档、规则指纹和各系统的随机状态。
随后生产、合成、交单、建造、购买游戏币商品、开箱开卡、活动和免费领奖都在本地即时执行。
`POST /v2/sync` 只接收 `base/rules/batch/ops/hash`，不接收客户端存档：服务端用同一份
Godot reducer 从确认点重放最多 256 个输入，并用规范化业务状态的 SHA-256 校验结果。
校验通过才事务提交新存档；失败时保留已确认点，下发它覆盖本地，记录原因，不自动认定封号。
相同 batch 的重试返回原确认结果；本地在途请求和之后的新输入分别持久化，断网不删日志。

- Godot 必须固定 **4.6.3**，配置 `TRIBE_REPLAY_GODOT` 指向可执行文件；Docker 镜像已包含此运行时。
- `python tools/stamp_replay.py` 固定规则代码指纹，Web 导出自动运行。客户端和服务端必须发布同一份
  data/scripts；旧规则的未提交日志需要旧版本校验程序，不应直接使用新规则强制结算。
- 升级前先部署 v2 服务端。已存在的服务器确认存档可迁移；不会首次接受客户端自报的货币和进度。
- 开启 v2 的账号会禁止通过旧 v1 游戏写接口绕过重放；账号登录/转移功能保留。
- 收藏卡、体力生产器、各普通生产器、宝箱、订单、主棋盘掉落、气泡、各期活动、竞速分别保存随机状态。
  查询界面和播放特效不会推进收藏卡序列；非法操作回滚其随机状态；重登不会重置种子。
- 真实支付与广告奖励需要平台凭证验证。重放模式不接受“我已付款/看完广告”的本地操作，既有模拟支付
  不会生成可进入 v2 存档的付费资产。第三方实际支付和广告 SDK 仍需接平台。
- 校验只能证明输入在规则内可重现。客户端持有种子，可以预知结果；输入时间还会校验顺序及服务器当前
  时间上限，但完全离线时无法证明每次点击实际发生的时间，不能承诺消除所有时间与试算作弊。
- 生产部署应按活跃玩家量规划校验进程资源；当前实现使用受限时长的独立 headless 进程，每批最多 256 条。

验证：

```sh
TRIBE_REPLAY_GODOT=/path/to/godot python -m pytest -q server/tests/test_replay.py
/path/to/godot --headless --path . --script tools/check_replay.gd -- --replay-test --cloud-off --save=user://replay_check/start.json --python=/path/to/python
```

### 压缩传输

v2 同步使用 `Content-Type: application/x-tribe-replay`、`Content-Encoding: gzip`，
直接发送压缩二进制，不套 JSON/Base64。TRP1 编码使用固定操作编号、位置参数、连续序号起点、
秒级时间差、变长整数、去重字符串表，以及原始 32/16 字节摘要与批次 ID。
操作/字段注册表由两端共享 `scripts/net/replay_wire.json`，编号只能追加，不能重排。
它属于传输协议，不改变游戏规则指纹或随机序列。重试仍保留原批次 ID，解码后走相同校验流程。

服务端在读取和解压时分别限制大小（压缩 96 KiB、解压 128 KiB、最多 256 条操作），并拒绝
截断数据、未知编号、尾随数据和超限字符串。旧 JSON 请求继续兼容，支持升级前保存的待重试批次。
成功同步只返回确认信息；首次登录和校验失败需要恢复时才返回完整的压缩存档。

压缩回归：`TRIBE_REPLAY_GODOT=/path/to/godot python -m pytest -q -s server/tests/test_replay_wire.py`。
