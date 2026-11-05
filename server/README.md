# 游戏服务器

账号、云存档、服务器经济（货币、集市、建造、通行证、卡包、领奖）、热卖、排行榜。
FastAPI + Uvicorn，SQLAlchemy 2 + Alembic，本地 SQLite / 正式 PostgreSQL。
设计、归属表、接口清单、部署和开销估算见仓库根目录 `DESIGN.md`「十二」。

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
