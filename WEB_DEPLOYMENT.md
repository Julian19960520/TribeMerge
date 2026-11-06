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
