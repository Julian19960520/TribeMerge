# 合合部落服务器

服务器使用 FastAPI、SQLAlchemy 和 Godot 4.6.3。客户端与服务器执行同一份 Godot 玩法规则；Python 只处理账号、传输、校验调度和确认存档的事务。

## 运行

```sh
pip install -r server/requirements.txt
TRIBE_REPLAY_GODOT=/path/to/godot python server/run.py
```

默认监听 `127.0.0.1:8765`，使用 SQLite；部署时可配置 PostgreSQL。环境变量示例见 `.env.example`。Docker 的构建上下文为工程根目录：

```sh
docker compose -f server/docker-compose.yml up --build
```

数据库仅包含账号、身份绑定、会话、确认存档、快照备份、批次幂等记录和审计日志。项目未上线，初始迁移只描述当前结构，不接收旧版数据或客户端自报的存档。

## 接口

| 接口 | 用途 |
| --- | --- |
| `/v1/auth/*`、`/v1/account*` | 游客账号、登录续期、转移码和身份绑定 |
| `/v1/health`、`/v1/time` | 健康检查、服务器时钟 |
| `/v1/rank/top`、`/v1/rank/name` | 确认建筑进度的排行榜和昵称 |
| `POST /v2/session` | 取得服务器确认存档、种子和当前规则指纹 |
| `POST /v2/sync` | 提交操作批次和本地结果哈希 |

生产、合成、订单、建造、商店、卡包、成长、通行证以及全部活动都通过 `/v2/sync` 执行。不再提供上传完整存档或逐项修改经济数据的接口。真实支付和广告仍需要平台凭证验证，操作重放不接受自报付款或看完广告。

## 同步协议与事务

`/v2/sync` 仅接受 `Content-Type: application/x-tribe-replay`、`Content-Encoding: gzip` 的 TRP1 二进制数据。传输直接使用压缩字节，不套 Base64。每批最多 256 个输入，压缩体上限 96 KiB、解压后上限 128 KiB；截断、尾随字节、未知操作和参数均拒绝。

服务端从确认点重放并计算规范业务状态的 SHA-256。操作合法且哈希相同才提交。规则指纹不匹配返回 `409 rules_update_required`，不尝试旧规则。校验不一致时返回原确认点供客户端恢复。

同一批次 ID 与相同输入的重试返回原确认结果；同一 ID 换输入返回冲突。耗时校验和排队期间没有数据库事务。提交前在短事务中重新检查登录会话、账号状态和存档版本，再通过 compare-and-swap 提交快照、排行投影、备份及幂等结果。新设备登录吊销旧会话后，在途旧请求也不能提交。

## 校验进程池

每个 Uvicorn 进程按需启动一组常驻 Godot worker。worker 启动时不加载贴图、音乐或音效，每次请求完整替换账号状态、随机流和临时数据。当前规则指纹由 worker 提供，Python 不复制规则实现。

| 配置 | 默认值 | 含义 |
| --- | --- | --- |
| `TRIBE_REPLAY_WORKERS` | 2 | 每个 API 进程最多同时运行的 Godot worker |
| `TRIBE_REPLAY_QUEUE_LIMIT` | 8 | 允许等待的请求数 |
| `TRIBE_REPLAY_QUEUE_TIMEOUT_SEC` | 2 | 等待空闲 worker 的秒数 |
| `TRIBE_REPLAY_TIMEOUT_SEC` | 20 | 单批执行的超时秒数 |

超限返回可重试的 503。进程退出、脚本错误或超时会丢弃该进程，下一请求重新启动，不复用失败状态。应用关闭时回收全部 worker。部署容量需按 `Uvicorn 进程数 × TRIBE_REPLAY_WORKERS` 计算。

## 验证

```sh
pip install -r server/requirements-dev.txt
TRIBE_REPLAY_GODOT=/path/to/godot python -m pytest -q server/tests
```

测试覆盖当前初始迁移、账号与转移、压缩边界、跨运行时编码、实际共享 reducer、批次幂等、随机流隔离、进程复用与故障恢复、排队容量、并发版本冲突、校验期间释放事务和提交前会话复核。Godot 回归需要明确设置 `TRIBE_REPLAY_GODOT`；未设置时对应项目会标记跳过。
