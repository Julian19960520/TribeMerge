# 恐龙化石活动

主棋盘活动栏新增「恐龙化石」。默认 1 级开放，每完成一张主棋盘订单获得 3 把铲子；合成不计分。每挖一格消耗 1 把铲子，空地同样消耗，重复点击已挖开的格子不扣除。

一期默认 10 关，从 3×3 逐关增加一行一列，到 12×12。第一关 2 块骨头，之后每关增加 1 块，总计 65 块。骨头尺寸包括 1×2、1×3、1×4、2×2、2×3、3×3、1×5、2×4，支持旋转，骨头之间不会重叠。

顶部展示本关全部骨头的剪影。挖开一块骨头覆盖的全部格子后，骨头飞入对应剪影；本关骨头全部收集后可进入下一关，不要求清空其余泥土。未用完的铲子和未领取的进度奖励会保留。累计收集 2、9、20、35、65 块骨头，可点击顶部宝箱预览并领取奖励。

数值、形状和奖励统一配置于 `data/fossil_dig.json`。存档字段 `fossil_dig` 保存独立布局种子、铲子、累计收集数、当前格子及领奖记录。布局只使用自身的哈希种子，不消耗卡牌、产物等其他系统的随机流。

客户端与规则测试共用 `scripts/events/FossilDig.gd`。旧版服务端保留 `/v1/fossil/action` 权威接口，交单、挖掘与领奖均有服务端校验。网页试玩沿用现有本地模式。

验证：

```sh
godot --headless --path . --script tools/check_fossil.gd -- --cloud-off --save=user://fossil-test.json --layouts=/tmp/fossil-layouts.json
godot --headless --path . --script tools/check_fossil_ui.gd -- --cloud-off --save=user://fossil-ui-test.json
TRIBE_GODOT=/usr/local/bin/godot python -m pytest server/tests/test_rules_replay.py -q
```
