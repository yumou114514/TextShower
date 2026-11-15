# TextShower · 文字展示

> 把一段文字按屏幕大小自动排好版，像一张干净的「小测文稿」一样展示出来。

TextShower 是一个 Flutter 应用：它把普通文本或 `.tst` 文稿放进文稿库，阅读时根据当前窗口尺寸自动计算字号，让内容尽量在一屏内完整呈现；需要修改时可以进入大字号编辑界面，改完保存、导出或直接分享。

主要面向 Windows 桌面，同时适配 Android。

## 功能

- **文稿库**：新建、打开、重命名、删除文稿；列表展示类型徽章、内容预览和更新时间。
- **打开任意文本文件**：自动识别 UTF-8（含 BOM）、UTF-16 LE/BE 和 GBK 编码，统一按 `.tst` 格式解析。
- **单屏自动排版**：在 14–200 号字之间二分搜索最大可容纳字号；短内容整块居中，长内容可滚动阅读。
- **手动调字号**：查看页用加减按钮按 10 号步进调整，「自动」按钮恢复自适应。
- **编辑**：大字号输入、实时字数/行数统计；双指捏合或 `Ctrl + 滚轮` 调整编辑字号。
- **安全保存**：未保存退出时询问「保存 / 不保存 / 取消」；`.tst` 文稿保存后会同时写回源文件。
- **导出与分享**：桌面端弹系统另存为对话框；Android 端生成临时文件后调用系统分享。
- **Windows 文件关联**：启动时注册 `.tst` 关联，双击 `.tst` 文件可直接用 TextShower 打开。
- **本地文稿库**：数据保存在应用支持目录的 `docs.json`，采用临时文件 + 原子重命名写入；文件损坏时会备份为 `.broken-<时间戳>` 并重新开始。

## `.tst` 文稿格式

`.tst` 是「YAML 文件头 + 正文」的纯文本格式。文件头可省略，省略时整段内容都是正文，标题回退为文件名。

```markdown
---
version: 1
title: Unit 3 单词小测
columns: 2
defaultGroup: 英文
hideGroups:
  - name: 英文
    defaultHidden: false
  - name: 音标
    defaultHidden: true
---
#FFD166 apple #FFFFFF 苹果
{hide:音标}/bəˈnɑːnə/{/hide}
```

### 文件头字段

| 字段 | 说明 |
| --- | --- |
| `version` | 格式版本，目前固定为 `1` |
| `title` | 文稿标题；缺省时使用文件名 |
| `columns` | 列数，仅支持 `1` 或 `2`，缺省为 `2` |
| `defaultGroup` | 默认隐藏组，需在 `hideGroups` 中存在 |
| `hideGroups` | 隐藏组列表，可写成字符串，或 `{ name, defaultHidden }` |

### 正文标记

- **颜色**：`#RGB` 或 `#RRGGBB` 后跟一个空白字符开始染色，颜色持续到下一个色码或本行结束。例如 `#F00 红色文字`。
- **隐藏组**：`{hide:组名}内容{/hide}`。正文中出现但未在文件头声明的组会自动补建；组名不能包含 `{`、`}`、`:` 或换行。
- **转义**：反斜杠 `\` 可转义后续字符，避免 `{`、`#` 等被当作标记解析。

> 当前版本的阅读页始终按单列渲染，`columns` 与隐藏标记会被完整解析并保留，但尚未提供双列布局和隐藏组开关。详见[已知限制](#已知限制)。

## 快速开始

### 环境要求

- Flutter 3.41+（Dart SDK `^3.11.4`）
- Windows 桌面开发需安装 Visual Studio C++ 桌面开发组件
- Android 开发需配置 Android SDK

### 运行

```bash
flutter pub get

# Windows
flutter run -d windows

# Android（先连接设备或启动模拟器）
flutter run -d android
```

也可以直接用 `flutter run` 选择可用设备。

### 测试与检查

```bash
flutter analyze
flutter test
```

### 构建

```bash
flutter build windows
flutter build apk
```

> `pubspec.yaml` 和 `android/app/build.gradle.kts` 中的包名仍为占位的 `com.example.text_shower`，应用显示名也是默认的 `text_shower`。正式分发前请改为自己的标识与名称。

## 项目结构

```text
lib/
├── main.dart                 # 入口：初始化仓库、Windows 文件关联、启动参数打开 .tst
├── app.dart                  # MaterialApp 与主题
├── models/
│   ├── text_doc.dart         # TextDoc / DocConfig / HideGroup
│   ├── parsed_document.dart  # 带样式与隐藏组的 Run / Block 文档模型
│   └── reader_pref.dart      # 阅读字号偏好
├── data/
│   ├── doc_repository.dart   # docs.json 文稿库（含损坏隔离）与内存实现
│   ├── tst_codec.dart        # .tst 解析与序列化
│   ├── tst_loader.dart       # 读文件 → 解码 → 解析 → 入库
│   ├── text_importer.dart    # UTF-8 / UTF-16 / GBK 编码识别
│   ├── export_service.dart   # 桌面另存为 / Android 分享
│   ├── file_pick_service.dart# 系统文件选择封装
│   └── windows_association.dart # .tst 关联注册与启动参数解析
├── pages/
│   ├── library_page.dart     # 文稿库首页
│   ├── display_page.dart     # 阅读页（自动字号、单列渲染）
│   └── editor_page.dart      # 编辑页（保存、副本、导出、删除）
├── services/
│   ├── text_measurer.dart    # TextPainter 测量与共享行高样式
│   ├── auto_fit.dart         # 自动字号二分搜索
│   ├── column_packer.dart    # 固定高度列/页装箱
│   └── marker_editor.dart    # 隐藏标记的包裹与移除
├── widgets/                  # 文稿条目、字号栏、富文本块、命名对话框
└── utils/date_format.dart    # 列表时间显示
test/                         # 单元测试与 Widget 测试
```

## 已知限制

- 阅读页目前固定单列，`columns: 2` 会被解析但不会切换成双列布局。
- 隐藏组没有开关按钮，`{hide:...}` 中的内容在阅读页仍会显示。
- 文稿库只保存在本机，没有云同步或导入导出整个库的功能。
- Windows 文件关联写入 `HKCU\Software\Classes`，卸载应用后不会自动清理注册表项。

## 许可证

[MIT](LICENSE)
