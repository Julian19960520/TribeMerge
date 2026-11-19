# 界面文案总表

**按功能分文件编辑：[texts/](texts/)。** 每个文件只放一个功能的文案，例如 `texts/content/onboarding.json` 是新手引导，`texts/ui/boardscreen.json` 是棋盘界面。一条文案只有编号和各语言。`texts.json` 是清单：语言、条数和文件列表。

| 字段 | 含义 |
| --- | --- |
| 条目编号 | 文件里只写这条文案自己的编号。读取时用所在目录和 `feature` 拼成完整编号，例如 `texts/content/onboarding.json` 里的 `dbaa88f6efb8` 就是 `content.onboarding.dbaa88f6efb8` |
| `zh_CN` | 中文文案 |

中文和译文用 `${0}`、`${1}` 按序号填空，同一序号可以重复，调用时每个序号只传一次。译文必须保留同样的序号。`%` 直接写百分号。图片内烘焙的字、引擎自带界面、历史存档迁移快照和离线素材工具不属于此统计。

配置中的 `§条目编号§` 会在加载时还原成 `zh_CN`，再进入玩法校验。界面显示时按条目编号读取目标语言。配置编辑器保存已知文案时仍写编号。代码用 `TextCatalog.source("条目编号")` 或 `TextCatalog.text("条目编号", [参数])` 取文案。

新增文案后执行 `python tools/text_catalog.py --sync`，自动提取、去重、绑定显示入口，并按功能写回对应文件。发布检查执行 `python tools/text_catalog.py --check`，代码里新出现、还没登记的文案会阻止发布。发布版本会把这些文件合成一份 `/texts.json`。

增加语言时，在 `locales` 中加入语言代码，并在各条目中填同名字段；空译文不要占位。启动界面前调用 `TextCatalog.set_locale("语言代码")`；已构建的界面需重新创建或刷新，当前没有额外添加语言选择界面。没有该语言字段时显示中文。字体覆盖、译文长度和不同语言排版需随具体译文验收。
