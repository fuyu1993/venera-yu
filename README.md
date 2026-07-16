# Venera

[![Flutter](https://img.shields.io/badge/flutter-3.41.4-blue)](https://flutter.dev/)
[![License](https://img.shields.io/github/license/venera-app/venera)](https://github.com/venera-app/venera/blob/master/LICENSE)
[![Stars](https://img.shields.io/github/stars/venera-app/venera?style=flat)](https://github.com/venera-app/venera/stargazers)

Venera 是一款跨平台漫画阅读器，支持阅读本地漫画、远程漫画库以及通过 JavaScript 自定义漫画源。项目面向桌面和移动端，提供较完整的阅读、收藏、历史记录和导入体验。

## 功能特点

- 支持阅读本地漫画
- 支持阅读 PDF、ZIP/CBZ/7z 等压缩包漫画
- 支持通过 WebDAV 连接远程书库
- 支持使用 JavaScript 创建和扩展漫画源
- 支持收藏、历史记录、标记管理
- 支持漫画下载与本地导入
- 支持查看评论、标签、相关信息（取决于漫画源支持）
- 支持登录后进行评论、评分等操作（取决于漫画源支持）

## 平台支持

- Android
- iOS
- macOS
- Linux
- Windows

## 快速开始

### 1. 环境要求

- Flutter 3.41.4 或更高版本
- Rust toolchain（请参考 [rustup.rs](https://rustup.rs/)）
- 依赖平台对应的构建工具链，例如 Xcode、Android SDK、CocoaPods 等

### 2. 安装依赖

```bash
git clone https://github.com/venera-app/venera.git
cd venera
flutter pub get
```

### 3. 运行应用

```bash
flutter run
```

### 4. 构建发行包

```bash
# Android
flutter build apk

# Linux
flutter build linux

# macOS
flutter build macos

# Windows
flutter build windows
```

> 如果你在 iOS 或 macOS 上构建，可能还需要先安装并完成对应平台依赖。

## 文档

- [漫画源开发文档](doc/comic_source.md)
- [JavaScript API 文档](doc/js_api.md)
- [导入漫画说明](doc/import_comic.md)
- [无头模式文档](doc/headless_doc.md)
- [使用手册](doc/操作手册.md)

## 创建新的漫画源

如果你想为应用添加新的漫画源，请参考 [漫画源文档](doc/comic_source.md) 和 [JavaScript API 文档](doc/js_api.md)。

## 贡献

欢迎提交 Issue、Pull Request 或提供反馈。

## 致谢

### 标签翻译

[EhTagTranslation](https://github.com/EhTagTranslation/Database)

项目中的部分漫画标签中文翻译来自该项目。
