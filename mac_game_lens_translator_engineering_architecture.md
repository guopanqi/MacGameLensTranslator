# Mac Game Lens Translator Engineering Architecture

## 1. 项目概述

**Mac Game Lens Translator** 是一个 macOS 原生屏幕翻译工具，目标是在 Mac 上实现类似游戏 Lens Mode / Hyper Overlay 的体验。

用户按下全局快捷键后，应用会捕获当前主屏幕或后续版本中的目标窗口，使用 OCR 识别画面中的文字及其位置，将文字批量发送给大模型翻译 API，例如 DeepSeek API，然后把译文以透明 Overlay 的形式显示在原文字附近。

第一阶段目标不是连续实时翻译，而是实现稳定的 **Snapshot Lens Translation**：

```text
按快捷键
→ 截取当前主屏幕
→ OCR 识别文字与坐标
→ 文本块过滤与合并
→ 批量调用 DeepSeek API 翻译
→ 在原文附近显示透明覆盖层
→ 再按快捷键清除覆盖层
```

---

## 2. 产品目标

### 2.1 V0.1 核心目标

1. **无须手动框选区域**

   * 默认对主显示器执行一次 OCR。
   * 后续版本再支持目标窗口和手动区域。

2. **译文显示在原文附近**

   * 不是固定翻译窗口。
   * 译文根据 OCR bounding box 放置在原文字附近。
   * 第一版不强行擦除英文，只显示可读的中文浮层。

3. **适合 Mac + CrossOver 游戏场景**

   * 优先支持窗口化 / 无边框窗口化游戏。
   * 不承诺支持独占全屏游戏。
   * 早期必须进行 CrossOver 兼容性实测。

4. **使用大模型 API 翻译**

   * 第一版优先接 DeepSeek API。
   * 翻译层设计为可替换 Provider，后续可支持 OpenAI、Claude、Gemini、本地模型或其他 OpenAI-compatible API。

5. **Mac 原生体验**

   * 菜单栏 App。
   * 全局快捷键。
   * 屏幕录制权限检查。
   * 透明、置顶、鼠标穿透的 Overlay。
   * 不抢游戏焦点。

---

## 3. 非目标

V0.1 不做以下内容：

```text
连续实时翻译
文本 hook
真正内嵌修改游戏文本
独占全屏支持
多显示器完整支持
复杂术语表系统
翻译历史管理
OCR 引擎切换
Windows 跨平台
自动识别所有游戏窗口
复杂背景擦除
自动场景变化检测
```

这些功能会显著增加开发成本，应放到 V0.2 或更后续版本。

---

## 4. 推荐技术栈

| 模块         | 技术选择                                                                         |
| ---------- | ---------------------------------------------------------------------------- |
| App 语言     | Swift                                                                        |
| App 框架     | AppKit + 少量 SwiftUI                                                          |
| App 形态     | 菜单栏 App                                                                      |
| 屏幕捕获       | ScreenCaptureKit / SCScreenshotManager；V0.1 deployment target 采用 macOS 14.0+ |
| OCR        | Apple Vision / VNRecognizeTextRequest                                        |
| 翻译 API     | DeepSeek OpenAI-compatible API                                               |
| Overlay    | AppKit NSWindow / NSPanel + AppKit NSView 原生绘制                               |
| 设置页        | SwiftUI                                                                      |
| 快捷键        | KeyboardShortcuts Swift Package 或 Carbon HotKey                              |
| 数据持久化      | UserDefaults                                                                 |
| API Key 存储 | Keychain                                                                     |
| 网络请求       | URLSession                                                                   |
| JSON 解析    | Codable + fallback parser                                                    |
| 日志         | os.Logger                                                                    |
| 测试         | XCTest                                                                       |

### 4.1 macOS 最低部署目标

V0.1 明确指定：

```text
macOS Deployment Target: macOS 14.0+
```

原因：

```text
ScreenCaptureKit 框架本身从 macOS 12.3 起可用
但 V0.1 计划使用的 SCScreenshotManager 当前要求 macOS 14.0+
Vision OCR、Keychain、AppKit Overlay、os.Logger 均可满足该目标
```

工程原则：

```text
如果坚持支持 macOS 13.x，则不能把 SCScreenshotManager 作为唯一截图路径，必须增加 SCStream 单帧捕获或其他 fallback。
V0.1 为了开发速度和稳定性，不做 macOS 13 fallback。
```

Xcode 配置要求：

```text
PROJECT → Deployment Target → macOS 14.0
TARGET → Deployment Target → macOS 14.0
```

所有使用 ScreenCaptureKit / Vision API 的实现文件仍应保留必要的 `@available` 检查，避免未来引入更高版本 API 时产生隐性兼容问题。

### 4.2 关键技术决策

#### Overlay 不使用 SwiftUI 绘制

V0.1 的 Overlay 层必须使用 **AppKit 原生 NSView 绘制**，不要使用 SwiftUI `View` + `NSHostingView` 绘制透明覆盖层。

原因：

* SwiftUI 在透明窗口中的背景行为不够可控。
* Overlay 需要稳定处理透明、置顶、鼠标穿透、不抢焦点、坐标精确绘制。
* AppKit 的 `NSWindow` + `NSView.draw(_:)` 更适合这种系统级浮层。

SwiftUI 只用于：

```text
SettingsView
AboutView
简单配置界面
```

---

## 5. 总体架构

```text
MacGameLensTranslator
├─ App
│  ├─ AppDelegate
│  ├─ MenuBarController
│  ├─ PermissionController
│  └─ HotkeyManager
│
├─ Coordinator
│  └─ LensTranslationCoordinator
│
├─ Capture
│  ├─ CaptureService
│  ├─ ScreenCaptureKitCaptureService
│  └─ ScreenshotResult
│
├─ OCR
│  ├─ OCRService
│  ├─ VisionOCRService
│  └─ OCRTextObservation
│
├─ TextProcessing
│  ├─ TextBlock
│  ├─ TextBlockFilter
│  ├─ TextBlockMerger
│  └─ TextNormalizer
│
├─ Translation
│  ├─ TranslationService
│  ├─ DeepSeekTranslationService
│  ├─ TranslationPromptBuilder
│  ├─ TranslationResultParser
│  ├─ TranslationBatcher
│  └─ TranslationCache
│
├─ Overlay
│  ├─ OverlayWindowController
│  ├─ OverlayPanel
│  ├─ OverlayCanvasView
│  ├─ OverlayTextBlock
│  └─ OverlayLayoutEngine
│
├─ Settings
│  ├─ SettingsStore
│  ├─ SettingsView
│  ├─ APIKeyStore
│  └─ KeychainAPIKeyStore
│
├─ Diagnostics
│  ├─ AppLogger
│  ├─ PerformanceMetrics
│  └─ DebugModeStore
│
└─ Debug
   ├─ OCRDebugOverlay
   ├─ BoundingBoxDebugRenderer
   └─ CoordinateDebugDumper
```

---

## 6. 核心数据流

### 6.1 Snapshot Translation Flow

```text
User presses hotkey
        │
        ▼
HotkeyManager receives event
        │
        ▼
LensTranslationCoordinator.toggleTranslation()
        │
        ▼
CaptureService.captureMainDisplay()
        │
        ▼
OCRService.recognizeText(image)
        │
        ▼
TextBlockFilter.filter(observations)
        │
        ▼
TextBlockMerger.merge(filteredObservations)
        │
        ▼
TranslationService.translate(blocks)
        │
        ▼
OverlayLayoutEngine.layout(translatedBlocks)
        │
        ▼
OverlayWindowController.show(overlayBlocks)
```

### 6.2 Toggle 行为

| 当前状态           | 快捷键行为                     |
| -------------- | ------------------------- |
| idle           | 开始一次 Snapshot Translation |
| translating    | 取消当前任务，清理中间状态             |
| showingOverlay | 清除 overlay                |
| failed         | 清除错误，回到 idle              |

---

## 7. App 模块

### 7.1 AppDelegate

职责：

* 设置应用为菜单栏 / accessory app。
* 初始化菜单栏图标。
* 初始化快捷键。
* 初始化设置存储。
* 检查屏幕录制权限。
* 创建 `LensTranslationCoordinator`。

V0.1 必须在启动时设置：

```swift
NSApp.setActivationPolicy(.accessory)
```

否则菜单栏 App 会出现在 Dock 中，不符合工具形态。

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = LensTranslationCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()
        setupHotkeys()
        checkPermissions()
    }
}
```

### 7.2 MenuBarController

菜单项：

```text
Translate Screen
Clear Overlay
Settings...
Check Permissions
Debug Mode
Quit
```

V0.1 不需要复杂主窗口，菜单栏 App 足够。

### 7.3 PermissionController

必需权限：

```text
Screen Recording
```

可选权限：

```text
Accessibility
```

V0.1 可以不强依赖 Accessibility。只有当后续需要更可靠地获取前台窗口、窗口标题或窗口边界时，再要求 Accessibility 权限。

PermissionController 职责：

* 检查 Screen Recording 权限。
* 权限缺失时显示轻量提示。
* 提供按钮打开 System Settings。
* 不在用户未授权时反复弹窗打扰。

---

## 8. HotkeyManager

默认快捷键：

```text
Command + Shift + T
```

职责：

* 注册全局快捷键。
* 将快捷键事件转发给 `LensTranslationCoordinator`。
* 支持设置页修改快捷键。
* 正在翻译时支持取消或忽略重复触发。

推荐状态机：

```swift
enum LensState {
    case idle
    case translating(Task<Void, Never>)
    case showingOverlay
    case failed(Error)
}
```

---

## 9. Capture 模块

### 9.1 CaptureService

V0.1 只支持主显示器截图。

```swift
protocol CaptureService {
    func captureMainDisplay() async throws -> ScreenshotResult
}
```

### 9.2 ScreenshotResult

```swift
struct ScreenshotResult {
    let image: CGImage
    let displayFrame: CGRect
    let scaleFactor: CGFloat
    let pixelSize: CGSize
    let capturedAt: Date
}
```

| 字段           | 说明                        |
| ------------ | ------------------------- |
| image        | 捕获到的屏幕图像                  |
| displayFrame | 主显示器在 macOS 屏幕坐标系中的 frame |
| scaleFactor  | Retina 缩放比例               |
| pixelSize    | 截图像素尺寸                    |
| capturedAt   | 截图时间                      |

### 9.3 V0.1 限制

第一版固定：

```text
只捕获主显示器
只处理主显示器 overlay
不处理多显示器 global origin
不处理目标窗口裁剪
```

这能显著降低坐标转换复杂度。

---

## 10. OCR 模块

### 10.1 OCRService

```swift
protocol OCRService {
    func recognizeText(in image: CGImage) async throws -> [OCRTextObservation]
}
```

### 10.2 VisionOCRService

使用 Apple Vision `VNRecognizeTextRequest`。

推荐配置：

```text
recognitionLevel: accurate
usesLanguageCorrection: true
minimumTextHeight: 可配置，V0.1 先不强设
recognitionLanguages: 根据 sourceLanguage 设置，Auto 时可留空或使用英文优先
```

`OCRService` 对外暴露 `async throws`，但 Vision 的文本识别实现需要明确桥接方式。V0.1 推荐不要在主线程直接执行 OCR，而是在后台任务中执行 `VNImageRequestHandler.perform(_:)`，并用 `withCheckedThrowingContinuation` 或 `Task.detached` 桥接到 async 接口。

实现原则：

```text
OCRService API: async throws
Vision 内部: VNRecognizeTextRequest + VNImageRequestHandler.perform
线程: 后台执行，不阻塞主线程
结果: 从 VNRecognizedTextObservation 中提取 text、confidence、boundingBox
```

伪代码：

```swift
func recognizeText(in image: CGImage) async throws -> [OCRTextObservation] {
    try await Task.detached(priority: .userInitiated) {
        var output: [OCRTextObservation] = []

        let request = VNRecognizeTextRequest { request, error in
            if let error {
                // 将 error 传出，实际实现中需要保存到外部变量或 Result
                return
            }

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            output = observations.compactMap { observation in
                guard let candidate = observation.topCandidates(1).first else {
                    return nil
                }

                return OCRTextObservation(
                    id: UUID(),
                    text: candidate.string,
                    confidence: candidate.confidence,
                    boundingBox: observation.boundingBox
                )
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        return output
    }.value
}
```

实际代码应避免在 completion handler 中吞掉错误，建议使用 `Result<[OCRTextObservation], Error>` 封装请求结果。

### 10.3 OCRTextObservation

```swift
struct OCRTextObservation: Identifiable {
    let id: UUID
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}
```

`boundingBox` 是 Vision 返回的标准化坐标：

```text
x: 0.0 - 1.0
y: 0.0 - 1.0
width: 0.0 - 1.0
height: 0.0 - 1.0
```

注意：Vision 坐标通常以左下角为原点，Overlay 绘制通常按左上布局理解，因此必须做 y 轴转换。

---

## 11. TextProcessing 模块

### 11.1 TextBlock

```swift
struct TextBlock: Identifiable, Codable {
    let id: Int
    var sourceText: String
    var translatedText: String?
    var boundingBox: CGRect
    var confidence: Float
    var lines: [String]
}
```

### 11.2 TextBlockFilter

过滤规则：

```text
confidence < 0.5 的文本丢弃
空白文本丢弃
纯符号文本丢弃
明显重复文本去重
过长的异常文本截断或丢弃
```

不建议 V0.1 过度过滤 UI 文本，因为游戏菜单、任务提示、物品说明也可能需要翻译。

### 11.3 TextBlockMerger

OCR 可能把一句对白拆成多行，需要合并相近文本块。

基础规则：

```text
垂直距离较近
字体高度相似
x 轴重叠明显
属于同一段落区域
则合并
```

伪逻辑：

```text
sort OCR observations by visual order:
    y ascending in overlay coordinates
    then x ascending

for each observation:
    find existing block where:
        verticalDistance < threshold
        horizontalOverlapRatio > threshold
        heightSimilarity < threshold

    if found:
        merge into block
    else:
        create new block
```

V0.1 的合并策略应保守，避免把不同 UI 区域误合并成一段话。

---

## 12. 坐标系统设计

坐标转换是项目最高风险点之一，必须单独测试。

### 12.1 坐标系统

| 坐标系统               | 原点               | 单位           |
| ------------------ | ---------------- | ------------ |
| Vision boundingBox | 左下               | 0-1 标准化      |
| CGImage pixel      | 图像空间             | pixel        |
| NSScreen frame     | 左下               | point        |
| OverlayCanvasView  | 左上布局更直观          | point        |
| Retina display     | pixel / point 不等 | scale factor |

### 12.2 目标

把 Vision OCR 的 bounding box 转成 Overlay 可绘制 frame。

```swift
struct OverlayTextBlock {
    let id: Int
    let sourceText: String
    let translatedText: String
    let sourceFrame: CGRect
    let overlayFrame: CGRect
}
```

### 12.3 转换公式

假设：

```text
bbox = Vision normalized rect
imageWidth = screenshot pixel width
imageHeight = screenshot pixel height
scaleFactor = screen backing scale factor
```

转换：

```text
pixelX = bbox.minX * imageWidth
pixelYFromBottom = bbox.minY * imageHeight
pixelW = bbox.width * imageWidth
pixelH = bbox.height * imageHeight

pixelYFromTop = imageHeight - pixelYFromBottom - pixelH

pointX = pixelX / scaleFactor
pointY = pixelYFromTop / scaleFactor
pointW = pixelW / scaleFactor
pointH = pixelH / scaleFactor
```

V0.1 建议 Overlay window 覆盖主显示器，内部坐标从 `(0, 0)` 开始，不处理多显示器全局 origin。

### 12.4 必测场景

```text
1x scale
2x Retina scale
左上角 bbox
右下角 bbox
屏幕中央 bbox
极窄文本框
极高文本框
y 轴翻转
```

---

## 13. Translation 模块

### 13.1 TranslationService

```swift
protocol TranslationService {
    func translate(_ blocks: [TextBlock], targetLanguage: String) async throws -> [TextBlock]
}
```

### 13.2 DeepSeekTranslationService

策略：

* 不要一个文本块调用一次 API。
* 所有文本块带 `id` 批量发送。
* 要求模型返回严格 JSON。
* 根据 `id` 映射回原来的 `TextBlock`。

### 13.3 PromptBuilder

System Prompt：

```text
You are a game localization translator.
Translate the provided OCR text blocks into Simplified Chinese.
Preserve meaning, tone, UI brevity, and game context.
Return only valid JSON.
Do not add explanations.
```

User Payload：

```json
{
  "target_language": "Simplified Chinese",
  "items": [
    {
      "id": 1,
      "text": "This door is locked."
    },
    {
      "id": 2,
      "text": "I need to find another way."
    }
  ]
}
```

Expected Response：

```json
{
  "items": [
    {
      "id": 1,
      "translation": "这扇门锁住了。"
    },
    {
      "id": 2,
      "translation": "我得找另一条路。"
    }
  ]
}
```

### 13.4 TranslationBatcher

V0.1 不做精确 token 计算，但必须做简单预算控制。

建议限制：

```text
最多 50 个 TextBlock
单个 TextBlock 最多 500 字符
单次请求总字符数最多 8000-12000 字符
```

批次策略：

```text
<= 20 blocks: 一次请求
21-50 blocks: 每 10 个一批
> 50 blocks: 只处理前 50 个，并提示文本过多
```

### 13.5 TranslationResultParser

解析策略：

1. 尝试直接解析 JSON。
2. 如果返回 markdown code block，剥离 `json 和 `。
3. 尝试提取第一个 JSON object。
4. 尝试修正常见尾逗号。
5. 校验每个 item 是否包含 `id` 和 `translation`。
6. 允许部分 item 成功。
7. 无法解析时进入 fallback。

### 13.6 Fallback 策略

单次批量请求失败时，不应导致全部译文失败。

Fallback pipeline：

```text
Primary:
- 按正常批次请求
- 解析 JSON

If parse failed:
- 清理 markdown code block
- 提取 JSON object
- 修正常见尾逗号
- 重试解析

If still failed:
- 拆成每 5 个 TextBlock 一批重新请求

If small batch still failed:
- 降级为逐条翻译

Final:
- 部分成功也显示
- 失败项不显示或显示原文
```

### 13.7 TranslationCache

缓存减少延迟和 API 成本。

```swift
struct TranslationCacheKey: Hashable {
    let normalizedSourceText: String
    let targetLanguage: String
    let provider: String
}
```

Normalization：

```text
trim spaces
collapse whitespace
English 可 lowercase
去除重复换行
```

V0.1 可以使用内存缓存。后续可持久化到 SwiftData 或 SQLite。

---

## 14. Overlay 模块

### 14.1 设计原则

V0.1 Overlay 全部使用 AppKit。

不要使用 SwiftUI 绘制 Overlay。

原因：

```text
透明背景更稳定
坐标绘制更精确
不容易被 NSHostingView 默认背景影响
更容易控制鼠标穿透
更容易调试 draw rect
```

### 14.2 OverlayWindowController

职责：

* 创建透明 Overlay window。
* 管理 window level。
* 显示 / 更新 / 清除 overlay。
* 不抢焦点。
* 鼠标穿透。

窗口特性：

```text
borderless
transparent background
non-activating
click-through
covers main display
can join all spaces if needed
```

### 14.3 Window Level 策略

不要默认使用 `.screenSaver`。

定义：

```swift
enum OverlayLevelMode: String, Codable {
    case normal
    case strong
    case emergency
}
```

映射：

| Mode      | NSWindow.Level     | 用途             |
| --------- | ------------------ | -------------- |
| normal    | `.floating`        | 默认模式           |
| strong    | `.statusBar` 或接近层级 | 盖不住游戏时尝试       |
| emergency | `.screenSaver`     | 兜底模式，可能盖住系统 UI |

V0.1 默认：

```text
normal / floating
```

设置页允许切换到 Strong / Emergency，但需要提示风险。

### 14.4 OverlayPanel

建议使用 `NSPanel` 或特殊配置的 `NSWindow`。

关键配置方向：

```swift
panel.styleMask = [.borderless, .nonactivatingPanel]
panel.backgroundColor = .clear
panel.isOpaque = false
panel.hasShadow = false
panel.ignoresMouseEvents = true
panel.level = selectedWindowLevel
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
```

注意：`fullScreenAuxiliary` 不等于一定能覆盖独占全屏游戏，只是提高兼容性。

### 14.5 OverlayCanvasView

使用 AppKit 原生绘制。

```swift
final class OverlayCanvasView: NSView {
    var blocks: [OverlayTextBlock] = []

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        for block in blocks {
            drawBackground(for: block)
            drawText(for: block)
        }
    }
}
```

绘制样式：

```text
黑色半透明背景
白色中文文字
圆角背景
适度 padding
轻微阴影
自动换行
最大宽度限制
```

### 14.6 OverlayLayoutEngine

职责：

* 将 OCR source frame 转成译文 frame。
* 决定译文显示在原文上方还是下方。
* 避免译文超出屏幕。
* 控制最大宽度和最小宽度。
* 后续处理碰撞。

V0.1 简单布局：

```text
translationX = sourceFrame.minX
translationY = sourceFrame.maxY + 4
translationWidth = max(sourceFrame.width * 1.5, 160)
translationWidth = min(translationWidth, 420)
translationHeight = text measured height + padding
```

如果下方空间不够，则放到原文上方。

---

## 15. Settings 模块

### 15.1 AppSettings

```swift
struct AppSettings: Codable {
    var targetLanguage: String
    var sourceLanguage: String
    var hotkey: String
    var fontSizeScale: Double
    var overlayOpacity: Double
    var overlayLevelMode: OverlayLevelMode
    var autoClearSeconds: Double?
    var maxTextBlocks: Int
    var maxTotalCharacters: Int
    var debugModeEnabled: Bool
}
```

默认值：

| 设置                   | 默认值                 |
| -------------------- | ------------------- |
| Target Language      | Simplified Chinese  |
| Source Language      | Auto                |
| Hotkey               | Command + Shift + T |
| Font Size Scale      | 1.0                 |
| Overlay Opacity      | 0.75                |
| Overlay Level Mode   | normal / floating   |
| Auto Clear           | Off                 |
| Max Text Blocks      | 50                  |
| Max Total Characters | 10000               |
| Debug Mode           | Off                 |

### 15.2 APIKeyStore

V0.1 直接使用 Keychain。

不要把 API Key 存在 UserDefaults。

```swift
protocol APIKeyStore {
    func saveAPIKey(_ key: String) throws
    func loadAPIKey() throws -> String?
    func deleteAPIKey() throws
}
```

`UserDefaults` 只保存非敏感配置。

---

## 16. Coordinator 设计

### 16.1 LensTranslationCoordinator

职责：

* 连接 Capture、OCR、TextProcessing、Translation、Overlay。
* 管理状态机。
* 处理取消。
* 记录性能数据。
* 处理错误展示。

```swift
final class LensTranslationCoordinator {
    enum State {
        case idle
        case translating
        case showingOverlay
        case failed(Error)
    }

    private(set) var state: State = .idle

    func toggleTranslation() async {
        switch state {
        case .idle:
            await startSnapshotTranslation()
        case .translating:
            cancelCurrentTask()
        case .showingOverlay:
            clearOverlay()
        case .failed:
            clearError()
        }
    }
}
```

### 16.2 startSnapshotTranslation

流程：

```text
check API key
check screen recording permission
capture screenshot
run OCR
filter OCR observations
merge text blocks
apply cache
batch translate uncached blocks
parse results with fallback
layout overlay blocks
show overlay
record metrics
```

---

## 17. 错误处理

| 错误                     | 处理                          |
| ---------------------- | --------------------------- |
| 没有 Screen Recording 权限 | 显示说明，引导打开 System Settings   |
| API Key 缺失             | 打开 SettingsView             |
| OCR 没识别到文字             | 显示轻量提示，自动回到 idle            |
| API 请求失败               | 显示错误提示，可重试                  |
| JSON 解析失败              | 启动 fallback 分批 / 逐条翻译       |
| 部分翻译失败                 | 显示成功项，失败项忽略或显示原文            |
| Overlay 盖不住游戏          | 提示切换 Overlay Level 或使用窗口化游戏 |
| 坐标明显异常                 | Debug mode 输出坐标信息           |

---

## 18. Diagnostics 与日志

### 18.1 os.Logger

使用 `os.Logger`，不要引入复杂 logging 框架。

日志类别：

```text
capture
ocr
textProcessing
translation
overlay
coordinate
permission
settings
```

### 18.2 PerformanceMetrics

每次翻译记录：

```text
capture duration
ocr duration
raw OCR observation count
filtered block count
merged block count
translation batch count
translation duration
JSON parse status
overlay layout duration
overlay render duration
total duration
```

### 18.3 隐私原则

默认不要记录：

```text
完整 API Key
完整游戏文本
完整 API response
```

Debug Mode 可以选择性记录 OCR 文本，但必须在设置中明确开启。

---

## 19. 测试策略

V0.1 必须包含单元测试。尤其是坐标转换、文本合并、JSON 解析。

测试目录：

```text
MacGameLensTranslatorTests/
├─ CoordinateTransformTests.swift
├─ TextBlockMergerTests.swift
├─ TranslationResultParserTests.swift
├─ TranslationBatcherTests.swift
├─ PromptBuilderTests.swift
└─ OverlayLayoutEngineTests.swift
```

### 19.1 CoordinateTransformTests

测试：

```text
Vision normalized bbox → overlay frame
1x scale
2x Retina scale
y 轴翻转
左上角 bbox
右下角 bbox
中央 bbox
边缘 bbox
```

### 19.2 TextBlockMergerTests

测试：

```text
同一段多行合并
不同 UI 区块不误合并
横向菜单项不误合并成长句
低置信度文本过滤
重复文本去重
```

### 19.3 TranslationResultParserTests

测试：

```text
正常 JSON
带 markdown code block 的 JSON
多余解释文字 + JSON
尾逗号 JSON
缺少 items
缺少 id
缺少 translation
部分 item 成功
完全不可解析
```

### 19.4 TranslationBatcherTests

测试：

```text
小于 20 blocks 一批
21-50 blocks 分批
超过 50 blocks 截断
超过字符数限制截断
单 block 超长截断
```

### 19.5 OverlayLayoutEngineTests

测试：

```text
译文放在原文下方
下方空间不足时放上方
右侧超出屏幕时向左修正
宽度小于最小值时扩展
宽度超过最大值时限制
```

---

## 20. Debug Mode

Debug Mode 是开发期必须功能。

显示内容：

```text
OCR bounding boxes
OCR confidence
source text
converted overlay frame
merged block boundary
translation block id
timing metrics
```

Debug Overlay 模式：

| 模式              | 用途             |
| --------------- | -------------- |
| bbox only       | 只画 OCR 框，验证坐标  |
| source text     | 显示 OCR 原文      |
| translated text | 显示译文           |
| metrics         | 显示耗时和 block 数量 |

开发顺序必须先跑通 bbox debug overlay，再做译文 overlay。

---

## 21. 性能目标

### 21.1 V0.1 性能目标

```text
从按下快捷键到 overlay 显示：2-5 秒内
```

预期耗时：

| 阶段         |           预期耗时 |
| ---------- | -------------: |
| 截图         |        < 300ms |
| OCR        | 300ms - 1500ms |
| 文本处理       |        < 100ms |
| API 翻译     | 800ms - 4000ms |
| Overlay 绘制 |        < 100ms |

瓶颈通常是 OCR 和 API。

### 21.2 优化策略

```text
批量翻译
翻译缓存
限制文本块数量
限制总字符数
过滤低置信度文本
后续支持区域模式
```

---

## 22. CrossOver 兼容性测试

这是项目早期必须测试的场景。

### 22.1 测试内容

```text
ScreenCaptureKit 能否截到 CrossOver 游戏画面
Overlay 能否盖在 CrossOver 游戏窗口上
窗口化模式是否正常
无边框窗口化是否正常
独占全屏是否失败
鼠标穿透是否不影响游戏点击
快捷键是否被游戏或 CrossOver 拦截
```

### 22.2 测试矩阵

| 场景                 |              必测 |
| ------------------ | --------------: |
| 普通 macOS App 窗口    |               是 |
| Safari / Chrome 页面 |               是 |
| CrossOver 普通窗口化游戏  |               是 |
| CrossOver 无边框窗口化游戏 |               是 |
| CrossOver 独占全屏游戏   |      记录结果，不保证支持 |
| 外接显示器              | V0.1 记录结果，不保证支持 |

### 22.3 失败时建议

如果 Overlay 盖不住：

```text
切换游戏为窗口化
切换 Overlay Level 为 Strong
关闭独占全屏
降低游戏分辨率
使用主显示器
```

---

## 23. V0.1 开发计划

### Milestone 1：App 骨架

目标：

```text
菜单栏 App
NSApp.setActivationPolicy(.accessory)
SettingsView
快捷键触发
权限检查
Keychain API Key 存储
os.Logger 基础日志
macOS 14.0+ deployment target 配置
```

产出：

```text
能按快捷键触发日志输出
能保存 / 读取 DeepSeek API Key
```

### Milestone 2：截图 + OCR

目标：

```text
按快捷键捕获主屏幕
Vision OCR 识别文字
打印 text + confidence + bbox
```

产出：

```text
控制台能看到 OCR 结果
```

### Milestone 3：BBox Debug Overlay

目标：

```text
把 OCR 识别到的 bounding box 画在屏幕上
```

产出：

```text
验证坐标转换正确
```

这是关键里程碑。不要跳过。

### Milestone 4：文本处理

目标：

```text
过滤低置信度文本
合并相近 OCR 行
生成稳定 TextBlock
```

产出：

```text
Debug Overlay 能显示合并后的文本块
```

### Milestone 5：DeepSeek 翻译

目标：

```text
OCR 文本批量发送给 DeepSeek
解析 JSON 翻译结果
支持 parser fallback
支持 batch fallback
支持缓存
```

产出：

```text
控制台能显示 id → translation 映射
```

### Milestone 6：译文 Overlay

目标：

```text
把译文显示在原文附近
黑色半透明背景
鼠标穿透
不抢焦点
再次快捷键清除
```

产出：

```text
可用的 Snapshot Lens Translation
```

### Milestone 7：CrossOver 测试与打磨

目标：

```text
测试 CrossOver 窗口化游戏
测试 overlay level
修复坐标偏移
修复快捷键冲突
完善错误提示
```

产出：

```text
V0.1 自用版本
```

---

## 24. 后续版本路线

### V0.2：目标窗口与区域模式

新增：

```text
捕获当前前台窗口
手动选择区域
区域记忆
当前游戏窗口模式
自动清除计时器
简单场景变化检测
```

### V0.3：Continuous Lens

新增：

```text
每 0.5-1 秒检测区域变化
图片差异判断
OCR 文本变化判断
翻译缓存
防闪烁
自动更新 overlay
```

### V0.4：翻译质量增强

新增：

```text
术语表
游戏名上下文
人物名固定翻译
UI 短语压缩
翻译风格设置
自定义 Provider
```

### V1.0：产品化

新增：

```text
多显示器支持
更完整的权限引导
自动更新
崩溃日志
更好的视觉样式
持久化缓存
导入 / 导出配置
```

---

## 25. 主要风险与规避

### 25.1 Overlay 盖不住部分游戏

高风险场景：

```text
独占全屏
特殊渲染层
CrossOver 异常窗口
```

规避：

```text
V0.1 明确只支持窗口化 / 无边框窗口化
提供 Overlay Level 设置
早期实测 CrossOver
```

### 25.2 OCR 对游戏字体识别差

高风险场景：

```text
像素字体
花体字体
动态背景
低对比度 UI
小字号文本
```

规避：

```text
优先支持普通英文 UI 和对白
后续加入图像预处理
允许区域模式减少干扰
```

### 25.3 坐标转换错位

原因：

```text
Retina scaling
Vision y 轴方向
NSScreen 坐标
多显示器 origin
```

规避：

```text
V0.1 只支持主显示器
必须先做 bbox debug overlay
必须写 CoordinateTransformTests
```

### 25.4 大模型返回非 JSON

规避：

```text
强 prompt
低 temperature
剥离 code block
提取 JSON object
修正常见尾逗号
分批 fallback
逐条 fallback
部分成功也显示
```

### 25.5 API Key 泄露

规避：

```text
V0.1 直接用 Keychain
日志不记录 API Key
错误提示不包含请求 header
```

---

## 26. 推荐目录结构

```text
MacGameLensTranslator/
├─ MacGameLensTranslatorApp.swift
├─ AppDelegate.swift
│
├─ App/
│  ├─ MenuBarController.swift
│  ├─ PermissionController.swift
│  └─ HotkeyManager.swift
│
├─ Coordinator/
│  └─ LensTranslationCoordinator.swift
│
├─ Capture/
│  ├─ CaptureService.swift
│  ├─ ScreenCaptureKitCaptureService.swift
│  └─ ScreenshotResult.swift
│
├─ OCR/
│  ├─ OCRService.swift
│  ├─ VisionOCRService.swift
│  └─ OCRTextObservation.swift
│
├─ TextProcessing/
│  ├─ TextBlock.swift
│  ├─ TextBlockFilter.swift
│  ├─ TextBlockMerger.swift
│  └─ TextNormalizer.swift
│
├─ Translation/
│  ├─ TranslationService.swift
│  ├─ DeepSeekTranslationService.swift
│  ├─ TranslationPromptBuilder.swift
│  ├─ TranslationResultParser.swift
│  ├─ TranslationBatcher.swift
│  └─ TranslationCache.swift
│
├─ Overlay/
│  ├─ OverlayWindowController.swift
│  ├─ OverlayPanel.swift
│  ├─ OverlayCanvasView.swift
│  ├─ OverlayTextBlock.swift
│  └─ OverlayLayoutEngine.swift
│
├─ Settings/
│  ├─ SettingsStore.swift
│  ├─ SettingsView.swift
│  ├─ APIKeyStore.swift
│  └─ KeychainAPIKeyStore.swift
│
├─ Diagnostics/
│  ├─ AppLogger.swift
│  ├─ PerformanceMetrics.swift
│  └─ DebugModeStore.swift
│
├─ Debug/
│  ├─ OCRDebugOverlay.swift
│  ├─ BoundingBoxDebugRenderer.swift
│  └─ CoordinateDebugDumper.swift
│
└─ Tests/
   ├─ CoordinateTransformTests.swift
   ├─ TextBlockMergerTests.swift
   ├─ TranslationResultParserTests.swift
   ├─ TranslationBatcherTests.swift
   ├─ PromptBuilderTests.swift
   └─ OverlayLayoutEngineTests.swift
```

---

## 27. V0.1 完成标准

V0.1 被认为可用，当满足：

```text
1. 用户可以在设置页保存 DeepSeek API Key，且 API Key 存入 Keychain
2. 用户按 Command + Shift + T 后，App 捕获主显示器截图
3. App 使用 Apple Vision OCR 识别屏幕文字
4. App 能正确显示 bbox debug overlay
5. App 能过滤、合并 OCR 文本块
6. App 能批量调用 DeepSeek API 翻译
7. App 能处理 JSON 解析失败并进行 fallback
8. App 能把中文译文显示在原文附近
9. Overlay 不影响鼠标点击游戏
10. 用户再次按快捷键可以清除 Overlay
11. 坐标转换、文本合并、JSON parser 有基础单元测试
12. CrossOver 窗口化游戏完成基本兼容性测试
```

---

## 28. 工程原则

### 28.1 优先跑通核心体验

第一版目标是：

```text
能用
位置大致对
翻译质量可接受
快捷键体验顺畅
CrossOver 窗口化可用
```

不是：

```text
实时连续翻译
支持所有游戏
支持所有全屏模式
商业软件级 UI
```

### 28.2 先做坐标正确，再做翻译漂亮

开发顺序必须是：

```text
截图
→ OCR
→ bbox debug overlay
→ 坐标正确
→ 文本合并
→ 翻译
→ 译文 overlay
```

不要跳过 bbox debug overlay。

### 28.3 功能范围小，但底层稳定

V0.1 不扩大功能范围，但以下底层能力必须做稳：

```text
AppKit 原生 Overlay
Keychain API Key 存储
Parser fallback
Batch fallback
坐标转换测试
CrossOver 实测
os.Logger 基础日志
```

### 28.4 平台专注

当前项目不做跨平台。所有设计优先服务 macOS：

```text
ScreenCaptureKit
Apple Vision
AppKit NSWindow / NSPanel
AppKit NSView drawing
SwiftUI Settings
Keychain
os.Logger
```

---

## 29. 最终结论

Mac Game Lens Translator 的最快、最稳路线是：

```text
Swift 原生菜单栏 App
+ ScreenCaptureKit 单帧截图
+ Apple Vision OCR
+ DeepSeek 批量翻译
+ AppKit 原生透明置顶 Overlay
+ Keychain API Key 存储
+ Parser / Batch fallback
+ 坐标转换单元测试
```

第一版只做 **按快捷键进行一次主屏幕 Snapshot Lens Translation**。

这能最快验证核心体验，并避开实时翻译、窗口识别、多显示器、独占全屏等高复杂度问题，同时保留后续演进到目标窗口模式、区域模式和 Continuous Lens 的架构空间。
