# 资产来源

| 资源 | 来源 | 用途 |
| --- | --- | --- |
| 资产/原画/v140_enemies.png | 本机配置的 image2.5；以项目角色和花园原画作风格参考 | 蜂巢女王、月冠古树、倒地状态、8 种新敌人 |
| 资产/原画/v140_inventory.png | 本机配置的 image2.5；以项目角色和花园原画作风格参考 | 武器、装备、主动道具、建筑图标 |
| 资产/精灵 中新增的 v1.4 对应贴图 | 上述图集经 tools/build_v140_assets.py 裁切整理 | 游戏内贴图、商品图标、手持武器 |
| audio/boss_intro.wav、boss_down.wav、build_place.wav、loot_chime.wav | tools/build_v140_audio.py 使用 Python 标准库原创合成 | Boss、建造和拾取音效 |
| 资产/原画/v150/*.png、资产/动画/*.png | 本机配置的 image2.5，以现有角色、敌人、时装和武器贴图为参考生成；再由 tools/build_v150_animations.py 裁切 | 角色、时装、敌人、Boss 与战斗特效的八帧动画 |
| assets/fonts/NotoSansSC.ttf | Noto Sans SC；上游许可信息见 [Google Fonts](https://github.com/google/fonts/tree/main/ofl/notosanssc) 与 [Noto CJK](https://github.com/notofonts/noto-cjk) | SIL Open Font License 1.1；全文见 assets/fonts/OFL.txt |

本工程记录没有列出从素材网站下载的第三方游戏图像或音效。较早的资源处理过程见 docs/v1.1.0.md 至 docs/v1.3.0.md 和各版本生成脚本。来源记录不等于对素材的再授权；许可证范围见 ASSET_LICENSES.md。图像生成服务的凭据保存在本机配置中，不在工程内。
