# 恐龙化石活动

主棋盘活动栏新增「恐龙化石」。7 级开放，单期持续 1 天 20 小时（44 小时，在周档中与合成活动轮换）。

铲子来源：
1. 完成主棋盘订单：按订单理论体力（火苗）换算铲子数，约每 120 体力对应 1 把铲子（最少 1 把，例如 8 级 10% 概率副产物 1280 体力对应 11 把）。
2. 消耗体力产出物品：点击消耗体力的生产器时，每消耗 1 点体力有独立概率（默认 `tap_drop_chance = 0.05`）掉落 1 把铲子，使用独立随机流 `fossil_tap`。

每挖一格消耗 1 把铲子，空地同样消耗，重复点击已挖开的格子不扣除。

一期最多 6 关，从 3×3 逐关增加一行一列到 8×8。第一关 2 块骨头，之后每关增加 1 块，总计 27 块。骨头尺寸包括 1×2、1×3、1×4、2×2、2×3、3×3、1×5、2×4，支持旋转，骨头之间不会重叠。

顶部展示本关全部骨头的剪影。挖开一块骨头覆盖的全部格子后，骨头飞入对应剪影；本关骨头全部收集后可进入下一关，不要求清空其余泥土。未用完的铲子和未领取的进度奖励会保留。累计收集 2、5、9、14、20、27 块骨头（对应第 1～6 关），可点击顶部宝箱预览并领取奖励。

数值、形状和奖励统一配置于 `data/fossil_dig.json`。存档字段 `fossil_dig` 保存独立布局种子、铲子、累计收集数、当前格子及领奖记录。布局只使用自身的哈希种子，不消耗卡牌、产物等其他系统的随机流。

验证：

```sh
godot --headless --path . --script tools/check_fossil.gd -- --cloud-off --save=user://fossil-test.json --layouts=/tmp/fossil-layouts.json
godot --headless --path . --script tools/check_fossil_ui.gd -- --cloud-off --save=user://fossil-ui-test.json
godot --headless --path . --script tools/check_activity_schedule.gd -- --replay-test --cloud-off
```
