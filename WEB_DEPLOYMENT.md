# 浏览器试玩版

使用 Godot 4.6.3 Web 导出。试玩启动参数为 `--cloud-off`：运行统一的操作 reducer、分系统随机流、追加日志和检查点，存档保存在浏览器。账号、云存档和在线排行榜在独立后端运行，不包含在静态站点中。

## 验证和构建

安装 Godot 4.6.3 与对应 Web 导出模板，准备 `server/requirements-dev.txt` 的 Python 环境：

```sh
python tools/check_project.py --godot /path/to/godot --python /path/to/server/python
python tools/export_web.py /path/to/godot
```

输出目录为 `dist/`。运行需要 HTTPS、WebGL 2 和支持 DecompressionStream 的现代浏览器。导出会压缩 WASM、将资源包切分为不超过 16 MiB 的内容寻址文件，并在独立空目录验证实际导出包中的全部物品帧和缓存预算。缺图或脚本错误会阻止构建。

物品帧由 `addons/item_export` 显式加入资源包。运行时按需解码当前帧，不在启动时把所有 PNG 展开。Web 版包含 Noto Sans CJK SC 字体，授权见 `assets/fonts/OFL.txt`。

工程使用当前存档结构，保存目录为 `TribeMerge`。卡册手动领奖更新兼容指定的旧版离线规则指纹，保留既有进度及已发放奖励。本次云存档更新同时兼容上一版浏览器试玩存档：保留最后完整检查点，跳过旧规则下尚未写入检查点的操作日志（通常不超过 5 秒），其他未知测试规则版本不迁移。站点身份保持在 `.openai/hosting.json`，部署不改变现有访问范围。

## 自动演算

`/simulation.html` 展示自动玩家时间轴。报告由 `tools/sim/run.py --publish-report` 生成后随游戏发布，不读取浏览器玩家存档。模拟器使用相同规则和独立模拟钟，不产生玩家日志。运行与报告格式见 `tools/sim/README.md`。

当前架构见 `docs/ARCHITECTURE.md`；后端运行、协议、事务与进程池配置见 `server/README.md`。
