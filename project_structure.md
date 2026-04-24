# 项目代码结构与架构说明

本项目基于 Flutter 构建，后端和部分核心逻辑使用 Rust 实现（通过 `flutter_rust_bridge` 进行交互）。项目的整体架构采用了类似于领域驱动设计（DDD）和 Clean Architecture 的分层模式，将职责解耦，便于维护和扩展。

以下为整个项目的目录及文件结构详细说明。

## 目录结构概览

```text
/workspace
├── android/            # Android 平台原生代码
├── ios/                # iOS 平台原生代码
├── macos/              # macOS 平台原生代码
├── windows/            # Windows 平台原生代码
├── linux/              # Linux 平台原生代码
├── web/                # Web 平台相关文件
├── rust/               # Rust 后端/底层核心逻辑实现
├── lib/                # Flutter 应用的 Dart 源代码
│   ├── core/           # 核心基础设施（主题、通用工具、常量等）
│   ├── data/           # 数据层（数据库、网络请求、系统代理等）
│   ├── domain/         # 领域层（数据模型、业务服务逻辑）
│   ├── presentation/   # 表现层（UI 页面、组件、状态管理）
│   ├── re_editor/      # (勿动) 定制化的代码编辑器组件
│   ├── re_highlight/   # (勿动) 语法高亮功能实现
│   ├── src/            # Rust 生成的交互桥接代码
│   └── utils/          # 通用工具类
└── pubspec.yaml        # Flutter 依赖配置文件
```

## `lib/` 核心目录详情

### 1. `lib/core/` (核心层)
存放与业务无关的全局配置和工具。
- `app_theme.dart`：应用的全局主题配置。
- `intents.dart`：应用内快捷键或动作意图（Intent）的定义。
- `utils/toast_utils.dart`：轻提示（Toast）弹窗的全局封装。

### 2. `lib/data/` (数据层)
负责数据的获取、存储以及与底层系统（如代理、证书）的交互。
- **`local/`**：本地存储
  - `database_helper.dart`：SQLite 或其他本地数据库的封装，负责数据的持久化读写。
  - `import_export_service.dart`：数据的导入与导出服务。
- **`network/`**：网络与抓包相关
  - `dio_client.dart`：基于 Dio 的网络请求客户端封装。
  - `certificate_manager.dart`：SSL/TLS 证书管理器（生成、安装、信任等）。
  - `https_mitm_server.dart`：HTTPS 中间人攻击（MITM）服务器的实现，用于解密 HTTPS 流量。
  - `traffic_capture_proxy.dart`：流量抓包代理服务器逻辑。
- **`system/`**：系统级别操作
  - `system_proxy_service.dart`：管理操作系统的代理设置（自动配置代理等）。

### 3. `lib/domain/` (领域层)
包含业务的实体模型（Models）和纯业务逻辑服务（Services）。
- **`models/`**：各种数据结构定义
  - `capture_session_model.dart`：单次抓包会话的数据模型。
  - `http_request_model.dart` / `http_response_model.dart`：HTTP 请求和响应模型。
  - `environment_model.dart` / `workspace_model.dart` / `collection_model.dart`：环境变量、工作区、请求集合的模型。
  - `mock_server_model.dart`：Mock 服务器模型。
- **`services/`**：独立业务逻辑
  - `js_engine_service.dart`：JavaScript 引擎服务，用于执行请求前后的脚本。
  - `collection_variables_service.dart`：集合变量处理逻辑。

### 4. `lib/presentation/` (表现层)
包含所有的 UI 组件和状态管理。这是项目中代码量最大的部分。
- **`pages/`**：整页级别的 UI
  - `home_page.dart`：应用的主页面，包含整体布局框架。
  - `home_page_widgets.dart`：从 `home_page.dart` 拆分出的子组件（如顶部快捷栏、环境选择下拉框等）。
- **`providers/`**：基于 Riverpod 的状态管理
  - `request_provider.dart`：管理当前正在编辑和发送的请求状态。
  - `capture_provider.dart`：管理抓包流量的数据和状态。
  - `settings_provider.dart`：应用全局设置状态。
  - 其他诸如 `collection_provider.dart`, `environment_provider.dart` 等。
- **`widgets/`**：可复用的 UI 局部组件
  - **核心面板 (Panes)**：
    - `request_pane.dart`：请求构建面板（URL、Method、Headers、Body）。
    - `response_pane.dart`：请求响应面板（展示返回的数据、Headers、耗时等）。
    - `capture_pane.dart`：抓包流量展示面板。
    - `capture_pane_widgets.dart`：抓包面板中拆分出的表格、Tab 栏等子组件。
    - `sidebar.dart`：左侧边栏（展示工作区、集合、历史记录等目录树）。
    - `mqtt_pane.dart` / `websocket_pane.dart` / `socket_pane.dart` / `tcp_pane.dart` / `udp_pane.dart`：不同协议的调试面板。
  - **辅助组件与弹窗**：
    - `code_editor.dart` / `app_code_editor.dart`：集成了代码高亮和自动补全的代码编辑器组件。
    - `settings_dialog.dart` / `certificate_management_dialog.dart`：各种弹窗。
    - `table_cell_text_field.dart`：支持键值对输入的表格文本框组件。
  - **`tools/`**：各种实用小工具的 UI（如颜色转换、Base64 编解码等）。

### 5. 其他目录
- **`lib/re_editor/` 和 `lib/re_highlight/`**：
  - 这两个是深度定制化的代码编辑器与语法高亮库。**无需修改此部分代码**。
- **`lib/src/rust/`**：
  - 通过 `flutter_rust_bridge` 自动生成的代码，用于 Dart 与 Rust 后端通信。
- **`lib/utils/`**：
  - `format_utils.dart`：从大型组件中拆分出来的纯函数工具类（如 JSON、XML 代码格式化、字节大小格式化等）。
  - `import_helper.dart`：导入导出的辅助工具。
  - `process_helper.dart`：处理外部进程的工具类。

## 优化与拆分说明
本项目经过重构优化，对原本过于臃肿的核心 UI 文件进行了组件与逻辑的拆离：
1. **纯逻辑工具类抽离**：将 `request_pane.dart` 中的大量代码格式化函数（`_formatCode`, `_formatXml`, `_formatJs` 等）抽取到了 `lib/utils/format_utils.dart`，降低了视图文件的代码量，并增强了复用性。
2. **臃肿 Widget 拆分**：将 `home_page.dart` 和 `capture_pane.dart` 中数百行内部私有类（如 `_CollapsibleSection`, `_SessionListTable`, `_HoverActionSurface` 等）抽离到了同级的 `_widgets.dart` 文件中，使得主控逻辑更清晰，方便 AI 或人类开发者快速阅读与维护。
