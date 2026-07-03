# 漫画源

## 简介

Venera 是一款支持从多种来源阅读漫画的阅读器。

所有漫画源均使用 JavaScript 编写。
Venera 使用 [flutter_qjs](https://github.com/wgh136/flutter_qjs) 作为 JS 引擎，该引擎 fork 自 [ekibun](https://github.com/ekibun/flutter_qjs)。

本文档将介绍如何为 Venera 编写漫画源。

## 漫画源列表

Venera 可以在应用内显示漫画源列表。

你可以使用以下仓库 URL：
```
https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/index.json
```
该仓库由 Venera 团队维护。

> 该链接是原始仓库的镜像。如需贡献漫画源，请访问 [原始仓库](https://github.com/venera-app/venera-configs)

你需要提供一个仓库 URL 让应用加载漫画源列表。URL 应指向一个包含漫画源列表的 JSON 文件。

JSON 文件格式如下：

```json
[
  {
    "name": "Source Name",
    "url": "https://example.com/source.js",
    "filename": "Relative path to the source file",
    "version": "1.0.0",
    "description": "A brief description of the source"
  }
]
```

`url` 和 `filename` 只需提供其中一个。`description` 字段为可选项。

## 创建漫画源

### 准备工作

- 安装 Venera。建议使用 Flutter 运行项目，便于调试。
- 一款支持 JavaScript 的编辑器。
- 从 [这里](https://github.com/venera-app/venera-configs) 下载模板和 Venera JavaScript API。

### 开始编写

模板中包含详细的注释和示例，编写漫画源时可以参考。

以下是模板的简要介绍：

> 注意：JavaScript API 文档见 [这里](js_api.md)。

#### 编写基本信息

```javascript
class NewComicSource extends ComicSource {
    // 注意：标记为 [Optional] 的字段如不使用应移除

    // 源名称
    name = ""

    // 源的唯一 ID
    key = ""

    version = "1.0.0"

    minAppVersion = "1.0.0"

    // 更新地址
    url = ""
// ...
}
```

在这一部分，你需要：
- 将类名改为你的源名称。
- 填写 `name`、`key`、`version`、`minAppVersion` 和 `url` 字段。

#### init 函数

```javascript
    /**
     * [Optional] init function
     */
    init() {

    }
```

该函数在源初始化时调用，可在此做一些初始化工作。如不使用可移除。

#### 账号

```javascript
// [Optional] account related
    account = {
        /**
         * [Optional] login with account and password, return any value to indicate success
         * @param account {string}
         * @param pwd {string}
         * @returns {Promise<any>}
         */
        login: async (account, pwd) => {

        },

        /**
         * [Optional] login with webview
         */
        loginWithWebview: {
            url: "",
            /**
             * check login status
             * @param url {string} - current url
             * @param title {string} - current title
             * @returns {boolean} - return true if login success
             */
            checkStatus: (url, title) => {

            },
            /**
             * [Optional] Callback when login success
             */
            onLoginSuccess: () => {

            },
        },

        /**
         * [Optional] login with cookies
         * Note: If `this.account.login` is implemented, this will be ignored
         */
        loginWithCookies: {
            fields: [
                "ipb_member_id",
                "ipb_pass_hash",
                "igneous",
                "star",
            ],
            /**
             * Validate cookies, return false if cookies are invalid.
             *
             * Use `Network.setCookies` to set cookies before validate.
             * @param values {string[]} - same order as `fields`
             * @returns {Promise<boolean>}
             */
            validate: async (values) => {

            },
        },

        /**
         * logout function, clear account related data
         */
        logout: () => {

        },

        // {string?} - register url
        registerWebsite: null
    }
```

在这一部分，可以实现登录、登出和注册功能。如不使用可移除。

#### 发现页

```javascript
    // explore page list
    explore = [
        {
            // title of the page.
            // title is used to identify the page, it should be unique
            title: "",

            /// multiPartPage or multiPageComicList or mixed
            type: "multiPartPage",

            /**
             * load function
             * @param page {number | null} - page number, null for `singlePageWithMultiPart` type
             * @returns {{}}
             * - for `multiPartPage` type, return {title: string, comics: Comic[], viewMore: string?}[]
             * - for `multiPageComicList` type, for each page(1-based), return {comics: Comic[], maxPage: number}
             * - for `mixed` type, use param `page` as index. for each index(0-based), return {data: [], maxPage: number?}, data is an array contains Comic[] or {title: string, comics: Comic[], viewMore: string?}
             */
            load: async (page) => {

            },

            /**
             * Only use for `multiPageComicList` type.
             * `loadNext` would be ignored if `load` function is implemented.
             * @param next {string | null} - next page token, null if first page
             * @returns {Promise<{comics: Comic[], next: string?}>} - next is null if no next page.
             */
            loadNext(next) {},
        }
    ]
```

在这一部分，可以实现发现页。一个漫画源可以有多个发现页。

发现页有三种类型：
- `multiPartPage`：发现页包含多个分区，每个分区包含多部漫画。
- `multiPageComicList`：发现页包含多部漫画，逐页加载。
- `mixed`：发现页包含多个分区，每个分区可以是漫画列表，也可以是带有标题和"查看更多"按钮的漫画块。

#### 分类页

```javascript
    // categories
    category = {
        /// title of the category page, used to identify the page, it should be unique
        title: "",
        parts: [
            {
                // title of the part
                name: "Theme",

                // fixed or random
                // if random, need to provide `randomNumber` field, which indicates the number of comics to display at the same time
                type: "fixed",

                // number of comics to display at the same time
                // randomNumber: 5,

                categories: ["All", "Adventure", "School"],

                // category or search
                // if `category`, use categoryComics.load to load comics
                // if `search`, use search.load to load comics
                itemType: "category",

                // [Optional] {string[]?} must have same length as categories, used to provide loading param for each category
                categoryParams: ["all", "adventure", "school"],

                // [Optional] {string} cannot be used with `categoryParams`, set all category params to this value
                groupParam: null,
            }
        ],
        // enable ranking page
        enableRankingPage: false,
    }
```

分类页是一个静态页面，包含多个分区，每个分区包含多个分类。一个漫画源只能有一个分类页。

#### 分类漫画页

```javascript
    /// category comic loading related
    categoryComics = {
        /**
         * load comics of a category
         * @param category {string} - category name
         * @param param {string?} - category param
         * @param options {string[]} - options from optionList
         * @param page {number} - page number
         * @returns {Promise<{comics: Comic[], maxPage: number}>}
         */
        load: async (category, param, options, page) => {

        },
        // provide options for category comic loading
        optionList: [
            {
                // For a single option, use `-` to separate the value and text, left for value, right for text
                options: [
                    "newToOld-New to Old",
                    "oldToNew-Old to New"
                ],
                // [Optional] {string[]} - show this option only when the value not in the list
                notShowWhen: null,
                // [Optional] {string[]} - show this option only when the value in the list
                showWhen: null
            }
        ],
        ranking: {
            // For a single option, use `-` to separate the value and text, left for value, right for text
            options: [
                "day-Day",
                "week-Week"
            ],
            /**
             * load ranking comics
             * @param option {string} - option from optionList
             * @param page {number} - page number
             * @returns {Promise<{comics: Comic[], maxPage: number}>}
             */
            load: async (option, page) => {

            }
        }
    }
```

当用户点击一个分类时，将显示分类漫画页。此部分用于加载某个分类下的漫画。

#### 搜索

```javascript
    /// search related
    search = {
        /**
         * load search result
         * @param keyword {string}
         * @param options {(string | null)[]} - options from optionList
         * @param page {number}
         * @returns {Promise<{comics: Comic[], maxPage: number}>}
         */
        load: async (keyword, options, page) => {

        },

        /**
         * load search result with next page token.
         * The field will be ignored if `load` function is implemented.
         * @param keyword {string}
         * @param options {(string)[]} - options from optionList
         * @param next {string | null}
         * @returns {Promise<{comics: Comic[], maxPage: number}>}
         */
        loadNext: async (keyword, options, next) => {

        },

        // provide options for search
        optionList: [
            {
                // [Optional] default is `select`
                // type: select, multi-select, dropdown
                // For select, there is only one selected value
                // For multi-select, there are multiple selected values or none. The `load` function will receive a json string which is an array of selected values
                // For dropdown, there is one selected value at most. If no selected value, the `load` function will receive a null
                type: "select",
                // For a single option, use `-` to separate the value and text, left for value, right for text
                options: [
                    "0-time",
                    "1-popular"
                ],
                // option label
                label: "sort",
                // default selected options
                default: null,
            }
        ],

        // enable tags suggestions
        enableTagsSuggestions: false,
        // [Optional] handle tag suggestion click
        onTagSuggestionSelected: (namespace, tag) => {
            // return the text to insert into search box
            return `${namespace}:${tag}`
        },
    }
```

此部分用于加载搜索结果。`load` 和 `loadNext` 函数用于加载搜索结果。如果实现了 `load` 函数，`loadNext` 将被忽略。

#### 收藏

```javascript
    // favorite related
    favorites = {
        // whether support multi folders
        multiFolder: false,
        /**
         * add or delete favorite.
         * throw `Login expired` to indicate login expired, App will automatically re-login and re-add/delete favorite
         * @param comicId {string}
         * @param folderId {string}
         * @param isAdding {boolean} - true for add, false for delete
         * @param favoriteId {string?} - [Comic.favoriteId]
         * @returns {Promise<any>} - return any value to indicate success
         */
        addOrDelFavorite: async (comicId, folderId, isAdding, favoriteId) => {
            
        },
        /**
         * load favorite folders.
         * throw `Login expired` to indicate login expired, App will automatically re-login retry.
         * if comicId is not null, return favorite folders which contains the comic.
         * @param comicId {string?}
         * @returns {Promise<{folders: {[p: string]: string}, favorited: string[]}>} - `folders` is a map of folder id to folder name, `favorited` is a list of folder id which contains the comic
         */
        loadFolders: async (comicId) => {

        },
        /**
         * add a folder
         * @param name {string}
         * @returns {Promise<any>} - return any value to indicate success
         */
        addFolder: async (name) => {

        },
        /**
         * delete a folder
         * @param folderId {string}
         * @returns {Promise<void>} - return any value to indicate success
         */
        deleteFolder: async (folderId) => {

        },
        /**
         * load comics in a folder
         * throw `Login expired` to indicate login expired, App will automatically re-login retry.
         * @param page {number}
         * @param folder {string?} - folder id, null for non-multi-folder
         * @returns {Promise<{comics: Comic[], maxPage: number}>}
         */
        loadComics: async (page, folder) => {

        },
        /**
         * load comics with next page token
         * @param next {string | null} - next page token, null for first page
         * @param folder {string}
         * @returns {Promise<{comics: Comic[], next: string?}>}
         */
        loadNext: async (next, folder) => {

        },
    }
```

此部分用于管理源的网络收藏。`load` 和 `loadNext` 函数用于加载搜索结果。如果实现了 `load` 函数，`loadNext` 将被忽略。

#### 漫画详情

```javascript
    /// single comic related
    comic = {
        /**
         * load comic info
         * @param id {string}
         * @returns {Promise<ComicDetails>}
         */
        loadInfo: async (id) => {

        },
        /**
         * [Optional] load thumbnails of a comic
         *
         * To render a part of an image as thumbnail, return `${url}@x=${start}-${end}&y=${start}-${end}`
         * - If width is not provided, use full width
         * - If height is not provided, use full height
         * @param id {string}
         * @param next {string?} - next page token, null for first page
         * @returns {Promise<{thumbnails: string[], next: string?}>} - `next` is next page token, null for no more
         */
        loadThumbnails: async (id, next) => {

        },

        /**
         * rate a comic
         * @param id
         * @param rating {number} - [0-10] app use 5 stars, 1 rating = 0.5 stars,
         * @returns {Promise<any>} - return any value to indicate success
         */
        starRating: async (id, rating) => {

        },

        /**
         * load images of a chapter
         * @param comicId {string}
         * @param epId {string?}
         * @returns {Promise<{images: string[]}>}
         */
        loadEp: async (comicId, epId) => {

        },
        /**
         * [Optional] provide configs for an image loading
         * @param url
         * @param comicId
         * @param epId
         * @returns {ImageLoadingConfig | Promise<ImageLoadingConfig>}
         */
        onImageLoad: (url, comicId, epId) => {
            return {}
        },
        /**
         * [Optional] provide configs for a thumbnail loading
         * @param url {string}
         * @returns {ImageLoadingConfig | Promise<ImageLoadingConfig>}
         *
         * `ImageLoadingConfig.modifyImage` and `ImageLoadingConfig.onLoadFailed` will be ignored.
         * They are not supported for thumbnails.
         */
        onThumbnailLoad: (url) => {
            return {}
        },
        /**
         * [Optional] like or unlike a comic
         * @param id {string}
         * @param isLike {boolean} - true for like, false for unlike
         * @returns {Promise<void>}
         */
        likeComic: async (id, isLike) =>  {

        },
        /**
         * [Optional] load comments
         *
         * Since app version 1.0.6, rich text is supported in comments.
         * Following html tags are supported: ['a', 'b', 'i', 'u', 's', 'br', 'span', 'img'].
         * span tag supports style attribute, but only support font-weight, font-style, text-decoration.
         * All images will be placed at the end of the comment.
         * Auto link detection is enabled, but only http/https links are supported.
         * @param comicId {string}
         * @param subId {string?} - ComicDetails.subId
         * @param page {number}
         * @param replyTo {string?} - commentId to reply, not null when reply to a comment
         * @returns {Promise<{comments: Comment[], maxPage: number?}>}
         */
        loadComments: async (comicId, subId, page, replyTo) => {

        },
        /**
         * [Optional] send a comment, return any value to indicate success
         * @param comicId {string}
         * @param subId {string?} - ComicDetails.subId
         * @param content {string}
         * @param replyTo {string?} - commentId to reply, not null when reply to a comment
         * @returns {Promise<any>}
         */
        sendComment: async (comicId, subId, content, replyTo) => {

        },
        /**
         * [Optional] load chapter comments
         * 
         * Chapter comments are displayed in the reader.
         * Same rich text support as loadComments.
         * 
         * Note: To control reply functionality:
         * - If a comment does not support replies, set its `id` to null/undefined
         * - Or set its `replyCount` to null/undefined
         * - The reply button will only show when both `id` and `replyCount` are present
         * 
         * @param comicId {string}
         * @param epId {string} - chapter id
         * @param page {number}
         * @param replyTo {string?} - commentId to reply, not null when reply to a comment
         * @returns {Promise<{comments: Comment[], maxPage: number?}>}
         * 
         * @example
         * // Example for comments without reply support:
         * return {
         *   comments: data.list.map(e => ({
         *     userName: e.user_name,
         *     avatar: e.user_avatar,
         *     content: e.comment,
         *     time: e.create_at,
         *     replyCount: null,  // or undefined - no reply support
         *     id: null,          // or undefined - no reply support
         *   })),
         *   maxPage: Math.ceil(total / 20)
         * }
         */
        loadChapterComments: async (comicId, epId, page, replyTo) => {

        },
        /**
         * [Optional] send a chapter comment, return any value to indicate success
         * @param comicId {string}
         * @param epId {string} - chapter id
         * @param content {string}
         * @param replyTo {string?} - commentId to reply, not null when reply to a comment
         * @returns {Promise<any>}
         */
        sendChapterComment: async (comicId, epId, content, replyTo) => {

        },
        /**
         * [Optional] like or unlike a comment
         * @param comicId {string}
         * @param subId {string?} - ComicDetails.subId
         * @param commentId {string}
         * @param isLike {boolean} - true for like, false for unlike
         * @returns {Promise<void>}
         */
        likeComment: async (comicId, subId, commentId, isLike) => {

        },
        /**
         * [Optional] vote a comment
         * @param id {string} - comicId
         * @param subId {string?} - ComicDetails.subId
         * @param commentId {string} - commentId
         * @param isUp {boolean} - true for up, false for down
         * @param isCancel {boolean} - true for cancel, false for vote
         * @returns {Promise<number>} - new score
         */
        voteComment: async (id, subId, commentId, isUp, isCancel) => {

        },
        // {string?} - regex string, used to identify comic id from user input
        idMatch: null,
        /**
         * [Optional] Handle tag click event
         * @param namespace {string}
         * @param tag {string}
         * @returns {{action: string, keyword: string, param: string?}}
         */
        onClickTag: (namespace, tag) => {

        },
        /**
         * [Optional] Handle links
         */
        link: {
            /**
             * set accepted domains
             */
            domains: [
                'example.com'
            ],
            /**
             * parse url to comic id
             * @param url {string}
             * @returns {string | null}
             */
            linkToId: (url) => {

            }
        },
        // enable tags translate
        enableTagsTranslate: false,
    }

```

此部分用于加载漫画详情。

#### 设置

```javascript
    /*
    [Optional] settings related
    Use this.loadSetting to load setting
    ```
    let setting1Value = this.loadSetting('setting1')
    console.log(setting1Value)
    ```
     */
    settings = {
        setting1: {
            // title
            title: "Setting1",
            // type: input, select, switch
            type: "select",
            // options
            options: [
                {
                    // value
                    value: 'o1',
                    // [Optional] text, if not set, use value as text
                    text: 'Option 1',
                },
            ],
            default: 'o1',
        },
        setting2: {
            title: "Setting2",
            type: "switch",
            default: true,
        },
        setting3: {
            title: "Setting3",
            type: "input",
            validator: null, // string | null, regex string
            default: '',
        },
        setting4: {
            title: "Setting4",
            type: "callback",
            buttonText: "Click me",
            /**
             * callback function
             *
             * If the callback function returns a Promise, the button will show a loading indicator until the promise is resolved.
             * @returns {void | Promise<any>}
             */
            callback: () => {
                // do something
            }
        }
    }
```

此部分用于为源提供设置项。

#### 翻译

```javascript
    // [Optional] translations for the strings in this config
    translation = {
        'zh_CN': {
            'Setting1': '设置1',
            'Setting2': '设置2',
            'Setting3': '设置3',
        },
        'zh_TW': {},
        'en': {}
    }
```

此部分用于为源提供多语言翻译。

> 注意：UI API 中的字符串不会自动翻译，需要手动翻译。
