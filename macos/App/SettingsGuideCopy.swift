import Foundation

enum SettingsGuideCopy {
    static var dropInTitle: String { Copy.t("拖进去", "Adding Files") }
    static var dropIn: String {
        Copy.t(
            "菜单栏图标、鼠标旁的轮盘、左侧列表：加入架子（复制进写入区域，原件不动）。右侧 AI：发给当前终端。轮盘六瓣是加入架子、发给终端、总结、抽取、翻译、转 MD；拖出外圈即消失，不开关面板。可在外观里关掉轮盘。",
            "Menu bar icon, the drop wheel beside the pointer, and the left list add to the shelf (a copy in the incoming folder; originals stay put). The right AI pane sends to the current terminal. The wheel has six slices: shelf, send, summarize, extract, translate, to Markdown. Leaving the ring dismisses it; it does not open or close the panel. Turn the wheel off in Appearance."
        )
    }

    static var filesTitle: String { Copy.t("选中的文件", "Selected Files") }
    static var files: String {
        Copy.t(
            "「加入选中的文件」：Finder / 桌面读选中项（可多选）。VSCode 等先模拟 ⌘C，只收文件，剪贴板会还原；没有文件再读当前打开的本地文件。浏览器最前请用抓页。原件不动。",
            "Add Selected Files: Finder and Desktop use the current selection (multiple files allowed). VS Code and similar apps simulate ⌘C and keep only files, then restore the clipboard; if none, the open local file is used. In a browser, use page capture. Originals are not modified."
        )
    }

    static var acceptsTitle: String { Copy.t("能接什么", "Supported Types") }
    static var accepts: String {
        Copy.t(
            "文件、文件夹、PDF、图片（PNG / JPG / GIF / WebP / HEIC）、文本 / Markdown、链接。+ 选文件，或搜索桌面 / 文稿 / 下载。剪贴板可粘贴。",
            "Files, folders, PDFs, images (PNG / JPG / GIF / WebP / HEIC), text / Markdown, and links. Use + to pick files, or search Desktop / Documents / Downloads. Paste from the clipboard."
        )
    }

    static var browserTitle: String { Copy.t("浏览器", "Browser") }
    static var browser: String {
        Copy.t(
            "拖到菜单栏图标、鼠标旁的轮盘（加入架子那瓣）、左侧列表，或粘贴整段网址：架子上先出现网站条，后台抓正文和截图（按该地址取页，不截你眼前的窗口；登录墙往往只留下链接）。拖到右侧 AI 区或轮盘「发给」只把链接送进终端，不抓页。当前窗口整页（含窗口截图）仍用「抓取当前页」快捷键，Safari / Chrome / Edge 要在最前。Safari 标签若系统不交 URL，仍进不来。",
            "Drop on the menu bar icon, the drop wheel’s shelf slice, left list, or paste a URL: the shelf gets a website item and fetches the body and a page snapshot in the background (from that URL, not the front window; logged-in pages often keep only the link). Drop on the right AI pane or the wheel’s Send slice sends the link to the terminal and does not fetch. A full front-window page still uses the capture shortcut while Safari / Chrome / Edge is frontmost. Safari tabs still cannot be dropped if the system gives no URL."
        )
    }

    static var readsTitle: String { Copy.t("读什么", "What It Reads") }
    static var reads: String {
        Copy.t(
            "抓页会读前台浏览器的地址、标题、正文和窗口截图，需要辅助功能和自动化授权。Recipe 只读任务副本，Prompt 里不写原件路径，也不加载你的全局 MCP / Hooks。",
            "Capture reads the front browser’s URL, title, body, and a window screenshot. Accessibility and Automation permission are required. Recipes read the job copy only; prompts never include original paths, and your global MCP / Hooks are not loaded."
        )
    }

    static var writesTitle: String { Copy.t("写什么", "What It Writes") }
    static var writes: String {
        Copy.t(
            "拖入的副本写在「写入区域」（默认 Inbox）。Recipe 结果写在「输出结果」下的任务编号 / output。不覆盖原文件。终端发送走那个 Agent 自己的权限，不是副本沙箱。",
            "Dropped copies go to Incoming files (Inbox by default). Recipe results go under Results / job-id / output. Originals are never overwritten. Sending to a terminal uses that agent’s own permissions, not the copy sandbox."
        )
    }

    static var dropOutTitle: String { Copy.t("拖出去", "Dragging Out") }
    static var dropOut: String {
        Copy.t(
            "一次拖一条，复制不是挪走。Finder / 桌面、上传框、多数聊天和编辑器能接文件或文字。网站抓取拖出是文件夹：链接、正文 md、截图。接不住就弹回架子。",
            "One item at a time; DropAgent copies the file and does not move it. Finder, Desktop, upload fields, and most chats or editors can accept a file or text. A captured page drags out as a folder: link, markdown, and screenshot. If the destination cannot accept it, the item returns to the shelf."
        )
    }
}
