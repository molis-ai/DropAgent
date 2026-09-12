import Foundation

enum SettingsGuideCopy {
    static var dropInTitle: String { Copy.t("添加材料", "Add files") }
    static var dropIn: String {
        Copy.t(
            "拖到打开的面板任意处、菜单栏图标或轮盘的「加入材料」，即可添加副本。轮盘还可选择总结、提取信息、翻译和转为 Markdown。发给当前 Agent 请用轮盘的「发给终端」。",
            "Drop onto the open panel, the menu bar icon, or the wheel’s Add files option to add a copy. The wheel also offers summaries, data extraction, translation, and Markdown conversion. To send to the current agent, use the wheel’s Send to terminal option."
        )
    }

    static var filesTitle: String { Copy.t("从其他应用添加", "Add from another app") }
    static var files: String {
        Copy.t(
            "「加入选中的文件」可读取 Finder 或桌面的选中项，支持多选。在 VS Code 等编辑器中，会尝试获取选中文件或当前本地文件，并还原剪贴板。在别处复制本地文件也会直接加入材料。浏览器页面请用「抓取当前页」。",
            "Add Selected Files imports the selection from Finder or Desktop, including multiple files. In editors such as VS Code, it tries the selected files or current local file and restores the clipboard. Copying local files also adds them as materials. For browser pages, use Capture Current Page."
        )
    }

    static var acceptsTitle: String { Copy.t("支持的内容", "Supported content") }
    static var accepts: String {
        Copy.t(
            "支持文件、文件夹、PDF、图片、文本、Markdown 和链接。点击「添加文件」或搜索框。复制本地文件会直接加入材料。剪贴板点选只预览；加入材料是明确操作。⌘V 粘贴当前剪贴板，不是选中的历史。",
            "Files, folders, PDFs, images, text, Markdown, and links are supported. Choose Add files or use search. Copying local files adds them as materials. Clicking clipboard history only previews; Add to materials is explicit. ⌘V pastes the current clipboard, not the selected history row."
        )
    }

    static var browserTitle: String { Copy.t("抓取网页", "Capture a page") }
    static var browser: String {
        Copy.t(
            "拖入或粘贴网址，会按地址获取正文和页面截图；需要登录的页面可能只保留链接。要抓取当前窗口，请将 Safari、Chrome 或 Edge 置于最前，再使用「抓取当前页」。浏览器标签无法拖入时，可复制网址。发送到「对话」只传递链接。",
            "Drop or paste a URL to fetch its text and a page snapshot. Pages requiring sign-in may retain only the link. To capture the current window, bring Safari, Chrome, or Edge to the front and use Capture Current Page. If a tab cannot be dropped, copy its URL. Sending to Chat passes only the link."
        )
    }

    static var readsTitle: String { Copy.t("读取范围", "What gets read") }
    static var reads: String {
        Copy.t(
            "网页抓取读取前台浏览器的地址、标题、正文和窗口截图，按需申请辅助功能与自动化权限。动作使用任务副本，提示词不含原件路径，也不加载全局 MCP 或 Hooks。PDF 与图片文字提取在本机完成。",
            "Page capture reads the front browser’s URL, title, text, and window snapshot, requesting Accessibility and Automation access as needed. Actions use job copies; prompts exclude original paths, and global MCP or Hooks are not loaded. PDF and image text extraction runs on your Mac."
        )
    }

    static var writesTitle: String { Copy.t("存储与权限", "Storage and permissions") }
    static var writes: String {
        Copy.t(
            "材料副本保存在「写入区域」，生成的文件保存在「输出结果」，可在设置中更改位置。快捷动作不覆盖原文件。「对话」使用 Agent 自身权限，不受副本沙箱限制。",
            "Copies are saved in Incoming files and generated files in Results. Change these locations in Settings. Actions do not overwrite originals. Chat uses the agent’s own permissions and is not restricted to the copy sandbox."
        )
    }

    static var dropOutTitle: String { Copy.t("导出结果", "Export results") }
    static var dropOut: String {
        Copy.t(
            "点击「复制文件」，或拖到 Finder、桌面、上传框及支持文件的应用。材料多选时可一起拖出，DropAgent 中的副本会保留。网页结果导出为包含链接、正文和截图的文件夹。",
            "Choose Copy file or drag to Finder, Desktop, an upload field, or an app that accepts files. Selected materials can be dragged together; copies remain in DropAgent. Captured pages export as folders containing the link, text, and snapshot."
        )
    }
}
