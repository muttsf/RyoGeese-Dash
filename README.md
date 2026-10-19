# RyoGeese-Dash

**RyoGeese 的配套游戏信息面板，由手电加鞭制作，开源免费。**

Dash 在魔兽世界内显示技能冷却、目标 DOT、资源和 BUFF 等信息，供 [RyoGeese 桌面软件](https://github.com/muttsf/RyoGeese) 通过画面识别读取。插件只显示信息，技能推荐由桌面软件计算，技能由玩家自行施放。

**[下载插件 ZIP](https://github.com/muttsf/RyoGeese-Dash/archive/refs/heads/main.zip) · [下载桌面软件](https://github.com/muttsf/RyoGeese/releases) · [反馈问题](https://github.com/muttsf/RyoGeese-Dash/issues)**

当前插件版本 **1.45-S1**，用于 **正式服 12.1.5 · 暗牧**。其他职业模板尚未完成，恶魔术等职业为后续计划。

喜欢这个项目的话，欢迎点个 **Star**。

## 安装插件

1. **退出游戏。**
2. 点击上方“下载插件 ZIP”，或者点击仓库绿色 **Code → Download ZIP**。
3. 解压后，找到里面的 **`MindBlastBox01`** 文件夹。
4. 把这个文件夹整个复制到你当前正式服游戏的 **`_retail_/Interface/AddOns/`** 目录。
5. 启动游戏，在插件列表中确认插件已启用，进入角色后查看 Dash 面板。

安装后的目录应当是：

```text
World of Warcraft/
└─ _retail_/
   └─ Interface/
      └─ AddOns/
         └─ MindBlastBox01/
            ├─ MindBlastBox01.toc
            ├─ MindBlastBox01_Dash.lua
            └─ ...
```

**请保留 `MindBlastBox01` 这个文件夹名。** 不要把外层的 `RyoGeese-Dash-main` 文件夹放进 `AddOns`，也不要再多套一层同名文件夹。

本项目直接提供插件源码，不另做插件安装器。桌面软件需要[单独下载安装](https://github.com/muttsf/RyoGeese/releases)。

## 调整面板

在游戏聊天框输入以下命令：

| 命令 | 用途 |
| --- | --- |
| `/dashconfig` | 打开设置，调整面板位置、大小和数字字号。 |
| `/dash` | 查看插件状态，便于排查问题。 |

需要移动时，先解锁，再拖动面板标题，完成后锁定。使用 RyoGeese 时，请让面板完整可见；移动面板或调整大小、字号后，要在桌面软件中**重新定位**。

## 面板显示什么

| 区域 | 当前暗牧模板的内容 |
| --- | --- |
| **A 列** | 技能冷却、充能或当前使用次数。 |
| **B 列** | 目标身上的暗言术：痛、吸血鬼之触、暗言术：癫。 |
| **C 列** | 目标血量百分比、玩家狂乱资源。 |
| **D 列** | 熵能裂隙、虚空形态、能量灌注等玩家 BUFF。 |

各槽位按固定网格排列，方便定位和识别。完整槽位说明见 [README.txt](README.txt)。

## 常见问题

**只装插件会推荐技能吗？**<br>
不会。插件负责显示游戏信息，技能推荐需要同时运行 [RyoGeese 桌面软件](https://github.com/muttsf/RyoGeese)。

**装好了，插件列表却找不到？**<br>
先检查是否放进当前正式服的 `AddOns` 目录，再确认 `MindBlastBox01.toc` 直接位于 `AddOns/MindBlastBox01/` 内，最后重新启动游戏。

**插件设置会保存吗？**<br>
位置、大小和字号由游戏按角色保存。卸载桌面软件不会删除这些设置。

**怎么更新？**<br>
退出游戏，下载新版，用新的 `MindBlastBox01` 文件夹替换原插件文件夹，然后重新进入游戏。若新版涉及面板变化，请在桌面软件中重新定位。

**遇到问题怎么反馈？**<br>
在 [Issues](https://github.com/muttsf/RyoGeese-Dash/issues) 中描述现象，附游戏版本、插件版本，以及 `/dash` 状态或面板截图。桌面软件的安装、识别和推荐问题，请提交到[软件仓库](https://github.com/muttsf/RyoGeese/issues)。

## 开发与许可

软件和插件分别维护、分别更新。当前接口为 `120105`，布局版本为 `L16`；扩展职业模板时，会继续保持固定行列的基本框架。

游戏内图标通过游戏纹理引用显示，本仓库不附带提取的游戏图片。

自有源码采用 **GPL-3.0-only**，见 [LICENSE](LICENSE)。欢迎通过 Issue 和 PR 参与改进。
