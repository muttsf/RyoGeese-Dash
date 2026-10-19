# RyoGeese-Dash

[English](#english)

RyoGeese 的配套游戏信息面板，由手电加鞭制作，在魔兽世界内显示技能冷却、目标 DOT、资源和 BUFF 等信息，代替官方CDM并提供窗口给配套工具做视觉采集。

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

---

## English

[返回中文 / Back to Chinese](#ryogeese-dash)

RyoGeese-Dash is the companion in-game information panel for RyoGeese, created by **手电加鞭**. It displays ability cooldowns, target DoTs, resources, and buffs in World of Warcraft, replacing the game's built-in CDM and providing an on-screen panel for companion tools to capture visually.

**[Download addon ZIP](https://github.com/muttsf/RyoGeese-Dash/archive/refs/heads/main.zip) · [Download desktop app](https://github.com/muttsf/RyoGeese/releases) · [Report an issue](https://github.com/muttsf/RyoGeese-Dash/issues)**

The current addon version is **1.45-S1**, for **Retail 12.1.5 · Shadow Priest**. Templates for other specializations are not yet complete; Demonology Warlock and other specializations are planned for future updates.

If you like this project, please consider giving it a **Star**.

### Installation

1. **Exit the game.**
2. Click “Download addon ZIP” above, or use the green **Code → Download ZIP** button on this repository.
3. Extract the ZIP and find the **`MindBlastBox01`** folder inside.
4. Copy the entire folder into **`_retail_/Interface/AddOns/`** in your current Retail installation.
5. Launch the game, make sure the addon is enabled in the addon list, and log into your character to see the Dash panel.

The resulting folder structure should look like this:

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

**Keep the folder name `MindBlastBox01`.** Do not put the outer `RyoGeese-Dash-main` folder into `AddOns`, and do not nest an extra `MindBlastBox01` folder inside it.

This repository provides the addon source directly, without a separate addon installer. The desktop app must be [downloaded and installed separately](https://github.com/muttsf/RyoGeese/releases).

### Panel settings

Enter these commands in the in-game chat:

| Command | Purpose |
| --- | --- |
| `/dashconfig` | Open settings to adjust the panel position, size, and number font size. |
| `/dash` | Show addon status for troubleshooting. |

To move the panel, unlock it, drag its title, then lock it again. Keep the entire panel visible while using RyoGeese. After changing its position, size, or font size, **locate the panel again** in the desktop app.

### What the panel shows

| Area | Current Shadow Priest template |
| --- | --- |
| **Column A** | Ability cooldowns, charges, or current use counts. |
| **Column B** | Shadow Word: Pain, Vampiric Touch, and Shadow Word: Madness on the target. |
| **Column C** | Target health percentage and player Insanity. |
| **Column D** | Player buffs, including Entropic Rift, Voidform, and Power Infusion. |

Slots use a fixed grid to help with panel location and visual recognition. See [README.txt](README.txt) for the full slot descriptions in Chinese.

### Frequently asked questions

**Does the addon recommend abilities on its own?**<br>
No. The addon displays game information. Ability recommendations require the [RyoGeese desktop app](https://github.com/muttsf/RyoGeese) to be running as well.

**Why is the addon missing from the addon list?**<br>
Check that you used the `AddOns` directory for your current Retail installation. Make sure `MindBlastBox01.toc` is directly inside `AddOns/MindBlastBox01/`, then restart the game.

**Are panel settings saved?**<br>
The game saves the position, size, and font size separately for each character. Uninstalling the desktop app does not remove these settings.

**How do I update the addon?**<br>
Exit the game, download the new version, replace the existing `MindBlastBox01` folder with the new one, then launch the game again. If the update changes the panel, locate it again in the desktop app.

**How do I report a problem?**<br>
Open an [issue](https://github.com/muttsf/RyoGeese-Dash/issues) describing the problem. Include your game version, addon version, and `/dash` status or a screenshot of the panel. For desktop installation, recognition, or recommendation issues, use the [desktop app repository](https://github.com/muttsf/RyoGeese/issues).

### Development and license

The desktop app and addon are maintained and updated separately. The current interface version is `120105`, and the layout version is `L16`. Future specialization templates will retain the basic fixed row-and-column structure.

In-game icons reference game textures. This repository does not include extracted game images.

Project-owned source code is licensed under **GPL-3.0-only**; see [LICENSE](LICENSE). Contributions through issues and pull requests are welcome.
