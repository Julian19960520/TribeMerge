# 面板角色图片清单

本次只删除标题上方额外添加的角色装饰，内部角色图片保留。

## 已删除的标题角色

| 面板或状态 | 来源 |
| --- | --- |
| 更多体力 | `ShopPopups.energy` → `Popups.frame` |
| 建筑建造详情（所有建筑共用） | `ProgressionPopups.build` → `Popups.frame` |
| 香蕉竞速：报名 | `RacePopup.start` → `Popups.frame` |
| 香蕉竞速：匹配族人 | `RacePopup.matching_panel` → `Popups.frame` |
| 香蕉竞速：比赛进行中 | `RacePopup.race_panel` → `Popups.frame` |
| 香蕉竞速：比赛结果（第一名） | `RacePopup.result` → `Popups.frame` |
| 部落礼包链 | `GiftChainPopup._setup` → `Popups.frame` |
| 获得奖励（共用奖励展示） | `RewardPopups.board_reward` |

共 8 处面板或状态入口，角色绘制来自 2 个位置。标题火种、横幅、文字和关闭按钮保留。

## 内部仍使用角色图片的面板

| 面板 | 位置、数量与用途 | 代码位置 |
| --- | --- | --- |
| 赶大集 | 中央集市场景中的 1 张主角半身像 | `scripts/ui/SpreePopup.gd`，`_paint_market` |
| 主角等级 | 中部场景的主角与同伴，共 2 张画像 | `scripts/ui/popups/RewardPopups.gd`，`level_info` |
| 主角升级 | 底部庆祝插画的主角与同伴，共 2 张画像 | `scripts/ui/popups/RewardPopups.gd`，`levelup` |
| 丰收祭 | 头图左侧 1 张同伴画像，另有 4 个人形岩画剪影 | `scripts/ui/popups/CollectionPopups.gd`，`_paint_event` |
| 丰收通行证 | 头图两侧共 3 张画像：左侧主角和同伴，右侧同伴 | `scripts/ui/PassPopup.gd`，`_paint_head` |
| 香蕉竞速 | 匹配座位最多 5 个头像；赛道最多 5 个头像；结算名单最多 5 个头像 | `scripts/ui/RacePopup.gd`，`_paint_matching`、`_paint_race`、`_result_row` |
| 双人竞速 | 报名对阵 2 个头像；匹配 2 个头像；比赛对阵 2 个头像；结算主角头像 1 个 | `scripts/ui/DuelPopup.gd`，`_start_panel`、`_matching_panel`、`_progress_panel`、`_result_panel` |
| 逃离剑齿虎 | 路径上的主角头像及同行者头像，人数随活动状态变化 | `scripts/ui/TigerEscapePopup.gd`，`_runners` |
| 部落排行 | 前三名领奖台最多 3 个头像；仅联网且有排名数据时显示，本地试玩不展示 | `scripts/ui/RankPopup.gd`，`_paint_avatar` |

按功能合并为 9 类；香蕉竞速的 3 个状态、双人竞速的 4 个状态分别计数时，共 14 个面板或状态。

典藏卡册、单卡详情和开包中的卡牌原画也可能包含人物，属于卡牌内容，不计入单独叠加的角色图片。主棋盘的主角卡、订单头像、地图移动头像、新手引导立绘及配置编辑器的订单预览不属于弹窗内部图片，本表未计入。
