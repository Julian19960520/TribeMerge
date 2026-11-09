# 浏览器试玩版

Godot 4.6.3 的 Web 导出，使用原有 `--cloud-off` 本地规则和浏览器存档。
账号、换设备登录和在线排行榜未部署。桌面版保留原有服务器配置。

## 构建

安装 Godot 4.6.3 及对应 Web 导出模板后，在工程根目录运行：

```sh
godot --headless --editor --import
python tools/export_web.py /path/to/godot
```

输出为 `dist/`。需要 HTTPS、WebGL 2 和支持 DecompressionStream 的现代浏览器。
脚本压缩 WASM，并将游戏资源包分成不超过 16 MiB 的文件，加载时自动还原，
以适配托管平台的单文件大小上限。
物品帧由 `addons/item_export` 显式加入资源包；保留 `.gdignore`，避免重复导入。
每次构建会在独立空目录验证实际导出包中的全部物品帧及动画缓存，缺图时构建失败。
Web 版打包 Noto Sans CJK SC 字体，授权见 `assets/fonts/OFL.txt`。

部署身份保存在 `.openai/hosting.json`。GitHub 的 origin 保持不变。

## 自动演算与活动

`/simulation.html` 提供自动玩家的时间轴。报告由 `tools/sim/run.py --publish-report`
生成，随游戏导出一起发布；它不读取浏览器里的玩家存档。配置与无限循环说明见
`tools/sim/README.md`。

双人竞速在浏览器试玩版使用模拟对手，按实际交单获得积分，先达目标者获胜。
目标积分、解锁等级、胜负奖励及 2/5/8/12 胜的累计奖励在 `data/duel_race.json` 配置。
桌面服务器也实现了权威积分和防重复领奖，但当前网页发布不包含真人匹配服务。

v2 客户端包含独立随机流、统一操作 reducer 与本地日志。当前托管地址继续使用 `--cloud-off`：
可以演示离线玩法和本地随机状态持久化，但该静态试玩没有运行 Python/Godot 后端，不能用于验证
线上反作弊。联网版本的 v2 登录与重放校验已在本地真实服务联调，部署见 `server/README.md`。
