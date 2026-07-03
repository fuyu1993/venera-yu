# Venera 无头模式

Venera 的无头模式允许你从命令行运行核心功能，方便自动化任务以及与其他工具集成。本文档介绍可用的命令及其用法。

## 使用方法

运行 Venera 可执行文件时使用 `--headless` 标志，后跟所需命令即可激活无头模式。

```bash
venera --headless <命令> [子命令] [选项]
```

## 全局选项

- **`--ignore-disheadless-log`**：抑制日志输出，为脚本提供更清晰的输出。

## 命令

### `webdav`

管理 WebDAV 数据同步。

- **`webdav up`**：将本地配置上传到 WebDAV 服务器。
- **`webdav down`**：从 WebDAV 服务器下载并应用远程配置。

**示例：**

```bash
venera --headless webdav up
```

### `updatescript`

更新漫画源脚本。

- **`updatescript all`**：检查并应用所有可用的漫画源脚本更新。

**示例：**

```bash
venera --headless updatescript all
```

**输出格式：**

`updatescript` 命令会提供详细的进度信息并输出最终摘要。

**进度日志：**

- **`Progress`**：表示单个脚本更新成功。
- **`ProgressError`**：表示脚本更新失败。

**`Progress` 日志示例：**

```json
{
  "status": "running",
  "message": "Progress",
  "data": {
    "current": 1,
    "total": 5,
    "source": {
      "key": "source-key",
      "name": "Source Name",
      "version": "1.0.0",
      "url": "https://example.com/source.js"
    }
  }
}
```

**最终摘要：**

结束时提供摘要，包含脚本总数、已更新数量和失败数量。

```json
{
  "status": "success",
  "message": "All scripts updated.",
  "data": {
    "total": 5,
    "updated": 4,
    "errors": 1
  }
}
```

### `updatesubscribe`

更新已订阅的漫画并获取已更新的漫画列表。

- **`updatesubscribe`**：检查所有已订阅漫画的更新。
- **`updatesubscribe --update-comic-by-id-type <id> <type>`**：更新由 `id` 和 `type` 指定的单个漫画。

**示例：**

```bash
# 更新所有订阅
venera --headless updatesubscribe

# 更新单个漫画
venera --headless updatesubscribe --update-comic-by-id-type "comic-id" "source-key"
```

## 输出格式

所有无头命令都会输出以 `[CLI PRINT]` 为前缀的 JSON 对象。这种结构化格式便于在自动化脚本中解析。JSON 对象始终包含 `status` 和 `message`。对于返回数据的命令，还会有 `data` 字段。

### `updatesubscribe` 输出

`updatesubscribe` 命令以 JSON 格式提供详细的进度信息和最终结果。

**进度日志：**

更新期间会收到 `Progress` 或 `ProgressError` 消息。

- **`Progress`**：表示更新过程中的一个成功步骤。
- **`ProgressError`**：表示更新某个漫画时发生错误。

**`Progress` 日志示例：**

```json
{
  "status": "running",
  "message": "Progress",
  "data": {
    "current": 1,
    "total": 10,
    "comic": {
      "id": "some-comic-id",
      "name": "Some Comic Name",
      "coverUrl": "https://example.com/cover.jpg",
      "author": "Author Name",
      "type": "source-key",
      "updateTime": "2023-10-27T12:00:00Z",
      "tags": ["tag1", "tag2"]
    }
  }
}
```

**`ProgressError` 日志示例：**

```json
{
  "status": "running",
  "message": "ProgressError",
  "data": {
    "current": 2,
    "total": 10,
    "comic": {
      "id": "another-comic-id",
      "name": "Another Comic Name",
      ...
    },
    "error": "Error message here"
  }
}
```

**最终输出：**

更新过程完成后，会返回一个包含所有已更新漫画列表的最终 JSON 对象。

```json
{
  "status": "success",
  "message": "Updated comics list.",
  "data": [
    {
      "id": "some-comic-id",
      "name": "Some Comic Name",
      "coverUrl": "https://example.com/cover.jpg",
      "author": "Author Name",
      "type": "source-key",
      "updateTime": "2023-10-27T12:00:00Z",
      "tags": ["tag1", "tag2"]
    }
  ]
}
```
