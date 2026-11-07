# 月石活动预渲染资源

`tiles.png` 按 6 层 × 16 变体排列：开放地砖两色、凹槽、覆盖石板、边缘石板、藤蔓石锁覆盖层。每格 128 px，内容 96 px，周围各留 16 px，运行时只画纹理矩形，揭开动画仍用位移、旋转和透明度。

其余 PNG 保存背景、边框、藤蔓、进度底板、陈列台、信息卡和投放气泡；四周各留 8 px。动态物品、进度、数字和特效单独绘制。装饰动画最多 20 次/秒，棋盘不监听全局笔触重绘。

重新烘焙（需可渲染的 Godot 4.6.3 环境）：

```sh
godot --path . --script tools/bake_moon.gd -- --cloud-off --save=user://bake-moon.json
godot --headless --editor --path . --import
```

源绘图仅在 `tools/MoonBakeArt.gd`，不进入网页游戏包；游戏启动和打开活动时均不会现场烘焙。
