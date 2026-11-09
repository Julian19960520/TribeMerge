# 石器部落游戏服务器。构建上下文是仓库根目录（要带上 data/ 里的游戏配置）：
#   docker build -f server/Dockerfile -t tribe-server .
FROM python:3.12-slim AS godot
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip ca-certificates && \
    curl -fL https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip -o /tmp/godot.zip && \
    unzip /tmp/godot.zip -d /tmp && mv /tmp/Godot_v4.6.3-stable_linux.x86_64 /usr/local/bin/godot
FROM python:3.12-slim AS base
COPY --from=godot /usr/local/bin/godot /usr/local/bin/godot
RUN apt-get update && apt-get install -y --no-install-recommends libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libgl1 libasound2 libvulkan1 && rm -rf /var/lib/apt/lists/*
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /srv/server
COPY server/requirements.txt .
RUN pip install -r requirements.txt
COPY data /srv/data
COPY server /srv/server
COPY project.godot /srv/project.godot
COPY *.tscn /srv/
COPY addons /srv/addons
COPY scripts /srv/scripts
COPY assets /srv/assets
COPY shaders /srv/shaders
# Register script classes and import resources once, never inside an HTTP request.
RUN godot --headless --editor --path /srv --import
ENV TRIBE_REPLAY_GODOT=/usr/local/bin/godot
RUN useradd --system --uid 10001 tribe && chown -R tribe /srv
USER tribe
ENV TRIBE_DATA_DIR=/srv/data TRIBE_HOST=0.0.0.0 TRIBE_PORT=8765
EXPOSE 8765
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request,sys;sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8765/v1/health',timeout=2).status==200 else 1)"
# 启动先迁移再起服务；多核机器用 --workers（PostgreSQL 下）
CMD ["python", "run.py", "--host", "0.0.0.0", "--port", "8765", "--workers", "2"]
