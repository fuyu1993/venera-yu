# JavaScript API

## 概述

JavaScript API 是一组用于与应用交互的函数。

API 包含以下几个部分：
- [Convert](#Convert) - 数据转换
- [Network](#Network) - 网络请求
- [Html](#Html) - HTML 解析
- [UI](#UI) - 用户界面
- [Utils](#Utils) - 工具函数
- [Types](#Types) - 类型定义


## Convert

Convert 是一组用于在不同类型之间转换数据的函数。

### `Convert.encodeUtf8(str: string): ArrayBuffer`

将字符串转换为 ArrayBuffer。

### `Convert.decodeUtf8(value: ArrayBuffer): string`

将 ArrayBuffer 转换为字符串。

### `Convert.encodeBase64(value: ArrayBuffer): string`

将 ArrayBuffer 转换为 Base64 字符串。

### `Convert.decodeBase64(value: string): ArrayBuffer`

将 Base64 字符串转换为 ArrayBuffer。

### `Convert.md5(value: ArrayBuffer): ArrayBuffer`

计算 ArrayBuffer 的 MD5 哈希值。

### `Convert.sha1(value: ArrayBuffer): ArrayBuffer`

计算 ArrayBuffer 的 SHA1 哈希值。

### `Convert.sha256(value: ArrayBuffer): ArrayBuffer`

计算 ArrayBuffer 的 SHA256 哈希值。

### `Convert.sha512(value: ArrayBuffer): ArrayBuffer`

计算 ArrayBuffer 的 SHA512 哈希值。

### `Convert.hmac(key: ArrayBuffer, value: ArrayBuffer, hash: string): ArrayBuffer`

计算 ArrayBuffer 的 HMAC 哈希值。

### `Convert.hmacString(key: ArrayBuffer, value: ArrayBuffer, hash: string): string`

计算 ArrayBuffer 的 HMAC 哈希值并返回字符串。

### `Convert.decryptAesEcb(value: ArrayBuffer, key: ArrayBuffer): ArrayBuffer`

使用 AES ECB 模式解密 ArrayBuffer。

### `Convert.decryptAesCbc(value: ArrayBuffer, key: ArrayBuffer, iv: ArrayBuffer): ArrayBuffer`

使用 AES CBC 模式解密 ArrayBuffer。

### `Convert.decryptAesCfb(value: ArrayBuffer, key: ArrayBuffer, iv: ArrayBuffer): ArrayBuffer`

使用 AES CFB 模式解密 ArrayBuffer。

### `Convert.decryptAesOfb(value: ArrayBuffer, key: ArrayBuffer, iv: ArrayBuffer): ArrayBuffer`

使用 AES OFB 模式解密 ArrayBuffer。

### `Convert.decryptRsa(value: ArrayBuffer, key: ArrayBuffer): ArrayBuffer`

使用 RSA 解密 ArrayBuffer。

### `Convert.hexEncode(value: ArrayBuffer): string`

将 ArrayBuffer 转换为十六进制字符串。

## Network

Network 是一组用于发送网络请求和管理网络资源的函数。

### `Network.fetchBytes(method: string, url: string, headers: object, data: ArrayBuffer): Promise<{status: number, headers: object, body: ArrayBuffer}>`

发送网络请求并将响应作为 ArrayBuffer 返回。

### `Network.sendRequest(method: string, url: string, headers: object, data: ArrayBuffer): Promise<{status: number, headers: object, body: string}>`

发送网络请求并将响应作为字符串返回。

### `Network.get(url: string, headers: object): Promise<{status: number, headers: object, body: string}>`

发送 GET 请求并将响应作为字符串返回。

### `Network.post(url: string, headers: object, data: ArrayBuffer): Promise<{status: number, headers: object, body: string}>`

发送 POST 请求并将响应作为字符串返回。

### `Network.put(url: string, headers: object, data: ArrayBuffer): Promise<{status: number, headers: object, body: string}>`

发送 PUT 请求并将响应作为字符串返回。

### `Network.delete(url: string, headers: object): Promise<{status: number, headers: object, body: string}>`

发送 DELETE 请求并将响应作为字符串返回。

### `Network.patch(url: string, headers: object, data: ArrayBuffer): Promise<{status: number, headers: object, body: string}>`

发送 PATCH 请求并将响应作为字符串返回。

### `Network.setCookies(url: string, cookies: Cookie[]): void`

为指定 URL 设置 Cookies。

### `Network.getCookies(url: string): Cookie[]`

获取指定 URL 的 Cookies。

### `Network.deleteCookies(url: string): void`

删除指定 URL 的 Cookies。

### `fetch`

`fetch` 函数是对 `Network.fetchBytes` 的封装，用法与浏览器中的 `fetch` 函数一致。

## Html

用于解析 HTML 的 API。

### `new HtmlDocument(html: string): HtmlDocument`

从 HTML 字符串创建 HtmlDocument 对象。

### `HtmlDocument.querySelector(selector: string): HtmlElement`

查找匹配选择器的第一个元素。

### `HtmlDocument.querySelectorAll(selector: string): HtmlElement[]`

查找匹配选择器的所有元素。

### `HtmlDocument.getElementById(id: string): HtmlElement`

通过 ID 查找元素。

### `HtmlDocument.dispose(): void`

销毁 HtmlDocument 对象。

### `HtmlElement.querySelector(selector: string): HtmlElement`

查找匹配选择器的第一个元素。

### `HtmlElement.querySelectorAll(selector: string): HtmlElement[]`

查找匹配选择器的所有元素。

### `HtmlElement.getElementById(id: string): HtmlElement`

通过 ID 查找元素。

### `get HtmlElement.text(): string`

获取元素的文本内容。

### `get HtmlElement.attributes(): object`

获取元素的属性。

### `get HtmlElement.children(): HtmlElement[]`

获取子元素。

### `get HtmlElement.nodes(): HtmlNode[]`

获取子节点。

### `get HtmlElement.parent(): HtmlElement | null`

获取父元素。

### `get HtmlElement.innerHtml(): string`

获取内部 HTML。

### `get HtmlElement.classNames(): string[]`

获取类名。

### `get HtmlElement.id(): string | null`

获取 ID。

### `get HtmlElement.localName(): string`

获取本地名称。

### `get HtmlElement.previousSibling(): HtmlElement | null`

获取前一个兄弟元素。

### `get HtmlElement.nextSibling(): HtmlElement | null`

获取后一个兄弟元素。

### `get HtmlNode.type(): string`

获取节点类型（"text"、"element"、"comment"、"document"、"unknown"）。

### `HtmlNode.toElement(): HtmlElement | null`

将节点转换为元素。

### `get HtmlNode.text(): string`

获取节点的文本内容。

## UI

### `UI.showMessage(message: string): void`

显示一条消息。

### `UI.showDialog(title: string, content: string, actions: {text: string, callback: () => void | Promise<void>, style: "text"|"filled"|"danger"}[]): void`

显示一个对话框。任一操作都会关闭对话框。

### `UI.launchUrl(url: string): void`

在外部浏览器中打开一个 URL。

### `UI.showLoading(onCancel: () => void | null | undefined): number`

显示加载对话框。

### `UI.cancelLoading(id: number): void`

取消加载对话框。

### `UI.showInputDialog(title: string, validator: (string) => string | null | undefined): string | null`

显示输入对话框。

### `UI.showSelectDialog(title: string, options: string[], initialIndex?: number): number | null`

显示选择对话框。

## Utils

### `createUuid(): string`

创建一个基于时间的 UUID。

### `randomInt(min: number, max: number): number`

生成指定范围内的随机整数。

### `randomDouble(min: number, max: number): number`

生成指定范围内的随机浮点数。

### console

向应用控制台发送日志，API 与浏览器中的 `console` 一致。

## Types

### `Cookie`

```javascript
/**
 * Create a cookie object.
 * @param name {string}
 * @param value {string}
 * @param domain {string}
 * @constructor
 */
function Cookie({name, value, domain}) {
    this.name = name;
    this.value = value;
    this.domain = domain;
}
```

### `Comic`

```javascript
/**
 * Create a comic object
 * @param id {string}
 * @param title {string}
 * @param subtitle {string}
 * @param subTitle {string} - equal to subtitle
 * @param cover {string}
 * @param tags {string[]}
 * @param description {string}
 * @param maxPage {number?}
 * @param language {string?}
 * @param favoriteId {string?} - Only set this field if the comic is from favorites page
 * @param stars {number?} - 0-5, double
 * @constructor
 */
function Comic({id, title, subtitle, subTitle, cover, tags, description, maxPage, language, favoriteId, stars}) {
    this.id = id;
    this.title = title;
    this.subtitle = subtitle;
    this.subTitle = subTitle;
    this.cover = cover;
    this.tags = tags;
    this.description = description;
    this.maxPage = maxPage;
    this.language = language;
    this.favoriteId = favoriteId;
    this.stars = stars;
}
```

### `ComicDetails`
```javascript
/**
 * Create a comic details object
 * @param title {string}
 * @param subtitle {string}
 * @param subTitle {string} - equal to subtitle
 * @param cover {string}
 * @param description {string?}
 * @param tags {Map<string, string[]> | {} | null | undefined}
 * @param chapters {Map<string, string> | {} | null | undefined} - key: chapter id, value: chapter title
 * @param isFavorite {boolean | null | undefined} - favorite status. If the comic source supports multiple folders, this field should be null
 * @param subId {string?} - a param which is passed to comments api
 * @param thumbnails {string[]?} - for multiple page thumbnails, set this to null, and use `loadThumbnails` api to load thumbnails
 * @param recommend {Comic[]?} - related comics
 * @param commentCount {number?}
 * @param likesCount {number?}
 * @param isLiked {boolean?}
 * @param uploader {string?}
 * @param updateTime {string?}
 * @param uploadTime {string?}
 * @param url {string?}
 * @param stars {number?} - 0-5, double
 * @param maxPage {number?}
 * @param comments {Comment[]?}- `since 1.0.7` App will display comments in the details page.
 * @constructor
 */
function ComicDetails({title, subtitle, subTitle, cover, description, tags, chapters, isFavorite, subId, thumbnails, recommend, commentCount, likesCount, isLiked, uploader, updateTime, uploadTime, url, stars, maxPage, comments}) {
    this.title = title;
    this.subtitle = subtitle ?? subTitle;
    this.cover = cover;
    this.description = description;
    this.tags = tags;
    this.chapters = chapters;
    this.isFavorite = isFavorite;
    this.subId = subId;
    this.thumbnails = thumbnails;
    this.recommend = recommend;
    this.commentCount = commentCount;
    this.likesCount = likesCount;
    this.isLiked = isLiked;
    this.uploader = uploader;
    this.updateTime = updateTime;
    this.uploadTime = uploadTime;
    this.url = url;
    this.stars = stars;
    this.maxPage = maxPage;
    this.comments = comments;
}
```

### `Comment`
```javascript
/**
 * Create a comment object
 * @param userName {string}
 * @param avatar {string?}
 * @param content {string}
 * @param time {string?}
 * @param replyCount {number?}
 * @param id {string?}
 * @param isLiked {boolean?}
 * @param score {number?}
 * @param voteStatus {number?} - 1: upvote, -1: downvote, 0: none
 * @constructor
 */
function Comment({userName, avatar, content, time, replyCount, id, isLiked, score, voteStatus}) {
    this.userName = userName;
    this.avatar = avatar;
    this.content = content;
    this.time = time;
    this.replyCount = replyCount;
    this.id = id;
    this.isLiked = isLiked;
    this.score = score;
    this.voteStatus = voteStatus;
}
```

### `ImageLoadingConfig`
```javascript
/**
 * Create image loading config
 * @param url {string?}
 * @param method {string?} - http method, uppercase
 * @param data {any} - request data, may be null
 * @param headers {Object?} - request headers
 * @param onResponse {((ArrayBuffer) => ArrayBuffer)?} - modify response data
 * @param modifyImage {string?}
 *  A js script string.
 *  The script will be executed in a new Isolate.
 *  A function named `modifyImage` should be defined in the script, which receives an [Image] as the only argument, and returns an [Image]..
 * @param onLoadFailed {(() => ImageLoadingConfig)?} - called when the image loading failed
 * @constructor
 * @since 1.0.5
 *
 * To keep the compatibility with the old version, do not use the constructor. Consider creating a new object with the properties directly.
 */
function ImageLoadingConfig({url, method, data, headers, onResponse, modifyImage, onLoadFailed}) {
    this.url = url;
    this.method = method;
    this.data = data;
    this.headers = headers;
    this.onResponse = onResponse;
    this.modifyImage = modifyImage;
    this.onLoadFailed = onLoadFailed;
}
```

### `ComicSource`
```javascript
class ComicSource {
    name = ""

    key = ""

    version = ""

    minAppVersion = ""

    url = ""

    /**
     * load data with its key
     * @param {string} dataKey
     * @returns {any}
     */
    loadData(dataKey) {
        return sendMessage({
            method: 'load_data',
            key: this.key,
            data_key: dataKey
        })
    }

    /**
     * load a setting with its key
     * @param key {string}
     * @returns {any}
     */
    loadSetting(key) {
        return sendMessage({
            method: 'load_setting',
            key: this.key,
            setting_key: key
        })
    }

    /**
     * save data
     * @param {string} dataKey
     * @param data
     */
    saveData(dataKey, data) {
        return sendMessage({
            method: 'save_data',
            key: this.key,
            data_key: dataKey,
            data: data
        })
    }

    /**
     * delete data
     * @param {string} dataKey
     */
    deleteData(dataKey) {
        return sendMessage({
            method: 'delete_data',
            key: this.key,
            data_key: dataKey,
        })
    }

    /**
     *
     * @returns {boolean}
     */
    get isLogged() {
        return sendMessage({
            method: 'isLogged',
            key: this.key,
        });
    }

    init() { }

    static sources = {}
}
```
