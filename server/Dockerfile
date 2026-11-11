# 合合部落游戏服务器。构建上下文是仓库根目录（要带上 data/ 里的游戏配置）：
#   docker build -f server/Dockerfile -t tribe-server .
FROM python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /srv/server
COPY server/requirements.txt .
RUN pip install -r requirements.txt
COPY data /srv/data
COPY server /srv/server
RUN useradd --system --uid 10001 tribe && chown -R tribe /srv
USER tribe
ENV TRIBE_DATA_DIR=/srv/data TRIBE_HOST=0.0.0.0 TRIBE_PORT=8765
EXPOSE 8765
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request,sys;sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8765/v1/health',timeout=2).status==200 else 1)"
# 启动先迁移再起服务；多核机器用 --workers（PostgreSQL 下）
CMD ["python", "run.py", "--host", "0.0.0.0", "--port", "8765", "--workers", "2"]
