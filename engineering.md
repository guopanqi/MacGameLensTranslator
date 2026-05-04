
# Mac Game Lens Translator Engineering Architecture

## 1. 项目概述

**Mac Game Lens Translator** 是一个 macOS 原生屏幕翻译工具，目标是在 Mac 上实现类似游戏 Lens Mode 的体验：

> 用户按下快捷键后，应用捕获当前屏幕或目标窗口，使用 OCR 识别画面中的文字，将文字批量发送给大模型翻译 API，例如 DeepSeek API，然后把译文覆盖显示在原文字附近。

第一阶段目标不是连续实时翻译，而是实现稳定的 **Snapshot Lens Translation**：

```text
按快捷键
→ 截取当前屏幕
→ OCR 识别文字与坐标
→ 文本块合并与过滤
→ 批量调用 DeepSeek API 翻译
→ 在原文附近显示透明覆盖层
→ 再按快捷键清除
```

---

# 2. 设计目标

## 2.1 核心目标

1. **无需手动框选区域**

   * 默认对主屏幕或目标窗口执行 OCR。
   * 后续版本再支持框选区域。

2. **译文原位附近覆盖**

   * 不是显示在固定翻译窗口。
   * 译文根据 OCR 返回的 bounding box 放置在原文附近。

3. **适合 Mac + CrossOver 游戏场景**

   * 优先支持窗口化 / 无边框窗口化游戏。
   * 暂不承诺独占全屏游戏。

4. **使用大模型 API 翻译**

   * 第一版优先接 DeepSeek API。
   * API 层设计为可替换，后续可支持 OpenAI、Claude、Gemini、本地模型等。

5. **Mac 原生体验**

   * 菜单栏 App。
   * 全局快捷键。
   * 屏幕录制权限检查。
   * 透明置顶覆盖层。
   * 鼠标穿透，不影响游戏操作。

---

# 3. 非目标

第一版不做以下内容：

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
```

这些功能会显著增加开发成本，应该放到后续版本。

---

# 4. 推荐技术栈

| 模块      | 技术选择                                            |
| ------- | ----------------------------------------------- |
| App 语言  | Swift                                           |
| App 框架  | AppKit + 少量 SwiftUI                             |
| App 形态  | 菜单栏 App                                         |
| 屏幕捕获    | ScreenCaptureKit / SCScreenshotManager          |
| OCR     | Apple Vision / VNRecognizeTextRequest           |
| 翻译 API  | DeepSeek OpenAI-compatible API                  |
| Overlay | AppKit NSWindow / NSPanel                       |
| 设置页     | SwiftUI                                         |
| 快捷键     | KeyboardShortcuts Swift Package 或 Carbon HotKey |
| 数据持久化   | UserDefaults，后续可升级 SwiftData                    |
| 网络请求    | URLSession                                      |
| JSON 解析 | Codable                                         |

---

# 5. 总体架构

```text
MacGameLensTranslator
├─ App
│  ├─ AppDelegate
│  ├─ MenuBarController
│  ├─ PermissionController
│  └─ HotkeyManager
│
├─ Capture
│  ├─ CaptureService
│  ├─ DisplayCaptureProvider
│  └─ ScreenshotResult
│
├─ OCR
│  ├─ OCRService
│  ├─ VisionOCRProvider
│  └─ OCRTextObservation
│
├─ TextProcessing
│  ├─ TextBlock
│  ├─ TextBlockMerger
│  ├─ TextBlockFilter
│  └─ TextNormalizer
│
├─ Translation
│  ├─ TranslationService
│  ├─ DeepSeekTranslationProvider
│  ├─ TranslationPromptBuilder
│  ├─ TranslationResultParser
│  └─ TranslationCache
│
├─ Overlay
│  ├─ OverlayWindowController
│  ├─ OverlayView
│  ├─ OverlayTextBlockView
│  └─ OverlayLayoutEngine
│
├─ Settings
│  ├─ SettingsStore
│  ├─ SettingsView
│  └─ APIKeyStore
│
└─ Debug
   ├─ OCRDebugView
   ├─ BoundingBoxDebugOverlay
   └─ Logging
```

---

# 6. 核心数据流

## 6.1 Snapshot Translation Flow

```text
User presses hotkey
        │
        ▼
HotkeyManager receives event
        │
        ▼
LensTranslationCoordinator.start()
        │
        ▼
CaptureService.captureMainDisplay()
        │
        ▼
OCRService.recognizeText(image)
        │
        ▼
TextBlockFilter.filter()
        │
        ▼
TextBlockMerger.merge()
        │
        ▼
TranslationService.translate(blocks)
        │
        ▼
OverlayLayoutEngine.layout(translatedBlocks)
        │
        ▼
OverlayWindowController.show(blocks)
```

---

# 7. 主要模块设计

## 7.1 AppDelegate

负责应用生命周期。

职责：

* 初始化菜单栏图标。
* 初始化快捷键。
* 检查屏幕录制权限。
* 加载用户设置。
* 管理主协调器。

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = LensTranslationCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkeys()
        checkPermissions()
    }
}
```

---

## 7.2 MenuBarController

菜单栏 App 控制器。

菜单项建议：

```text
Translate Screen
Clear Overlay
Settings...
Check Permissions
Quit
```

第一版不需要主窗口，菜单栏即可。

---

## 7.3 PermissionController

macOS 需要屏幕录制权限。

职责：

* 检查 Screen Recording 权限。
* 引导用户打开系统设置。
* 可选检查 Accessibility 权限。

第一版必要权限：

```text
Screen Recording
```

可选权限：

```text
Accessibility
```

Accessibility 第一版可以先不强依赖，除非需要更可靠地获取前台窗口信息。

---

## 7.4 HotkeyManager

负责全局快捷键。

默认快捷键：

```text
Command + Shift + T
```

行为：

| 当前状态        | 快捷键行为         |
| ----------- | ------------- |
| 无 overlay   | 开始翻译当前屏幕      |
| overlay 已显示 | 清除 overlay    |
| 正在翻译        | 取消当前任务或忽略重复触发 |

推荐状态机：

```text
idle
translating
showingOverlay
error
```

---

# 8. 屏幕捕获模块

## 8.1 CaptureService

第一版只支持主显示器截图。

```swift
protocol CaptureService {
    func captureMainDisplay() async throws -> ScreenshotResult
}
```

## 8.2 ScreenshotResult

```swift
struct ScreenshotResult {
    let image: CGImage
    let displayFrame: CGRect
    let scaleFactor: CGFloat
    let capturedAt: Date
}
```

字段说明：

| 字段           | 说明                       |
| ------------ | ------------------------ |
| image        | 捕获到的屏幕图像                 |
| displayFrame | 显示器在 macOS 屏幕坐标系中的 frame |
| scaleFactor  | Retina 缩放比例              |
| capturedAt   | 截图时间                     |

---

# 9. OCR 模块

## 9.1 OCRService

使用 Apple Vision。

```swift
protocol OCRService {
    func recognizeText(in image: CGImage) async throws -> [OCRTextObservation]
}
```

## 9.2 OCRTextObservation

```swift
struct OCRTextObservation: Identifiable {
    let id: UUID
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}
```

注意：

Apple Vision 的 `boundingBox` 通常是标准化坐标：

```text
x: 0.0 - 1.0
y: 0.0 - 1.0
width: 0.0 - 1.0
height: 0.0 - 1.0
```

并且坐标原点通常在左下角。Overlay 绘制时需要转换成屏幕坐标。

---

# 10. 文本块处理模块

OCR 原始结果通常不能直接翻译，需要处理。

## 10.1 TextBlock

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

## 10.2 TextBlockFilter

过滤规则：

```text
confidence < 0.5 的文本丢弃
空白文本丢弃
过短的无意义文本丢弃
纯符号文本丢弃
重复文本去重
```

保留：

```text
对白
菜单项
任务提示
物品说明
UI 按钮文字
```

暂时不强行过滤 UI，因为游戏翻译场景中 UI 也可能需要翻译。

---

## 10.3 TextBlockMerger

OCR 可能把一句话拆成多行。需要合并相近文本块。

基础合并规则：

```text
两个文本块垂直距离较近
字体高度相似
x 轴重叠明显
属于同一段落区域
则合并
```

伪逻辑：

```text
sort OCR observations by y descending, then x ascending

for each observation:
    find existing block where:
        vertical distance < threshold
        horizontal overlap > threshold
        height similarity < threshold

    if found:
        merge into block
    else:
        create new block
```

第一版不追求完美，只要比原始 OCR 更稳定即可。

---

# 11. 坐标系统设计

这是整个项目最容易出错的部分。

## 11.1 坐标来源

| 坐标系统               | 原点               | 单位           |
| ------------------ | ---------------- | ------------ |
| Vision boundingBox | 左下               | 0-1 标准化      |
| CGImage pixel      | 左上或图像空间          | pixel        |
| NSScreen frame     | 左下               | point        |
| SwiftUI overlay    | 通常按左上布局理解        | point        |
| Retina display     | pixel / point 不等 | scale factor |

---

## 11.2 转换目标

将 Vision OCR 的 bounding box 转换为 Overlay 中可绘制的位置。

目标结构：

```swift
struct OverlayTextBlock {
    let id: Int
    let text: String
    let frame: CGRect
}
```

---

## 11.3 转换步骤

假设：

```text
Vision bbox = normalized rect
imageWidth = screenshot pixel width
imageHeight = screenshot pixel height
displayFrame = NSScreen frame in points
scaleFactor = screen backing scale factor
```

转换逻辑：

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

最终 overlay frame：

```text
overlayX = pointX
overlayY = pointY
overlayW = pointW
overlayH = pointH
```

第一版建议 overlay window 直接覆盖主屏幕，内部坐标从 `(0, 0)` 开始，这样不必处理复杂的全局 screen origin。

---

# 12. 翻译模块

## 12.1 TranslationService

```swift
protocol TranslationService {
    func translate(_ blocks: [TextBlock], targetLanguage: String) async throws -> [TextBlock]
}
```

## 12.2 DeepSeekTranslationProvider

DeepSeek API 可以按 OpenAI-compatible chat completion 方式接入。

请求策略：

```text
把所有 OCR 文本块批量发送
每个文本块带 id
要求模型返回严格 JSON
根据 id 映射回 TextBlock
```

不要一个文本块调用一次 API。

---

## 12.3 Prompt 格式

System Prompt：

```text
You are a game localization translator.
Translate the provided OCR text blocks into Simplified Chinese.
Preserve meaning, tone, UI brevity, and game context.
Return only valid JSON.
Do not add explanations.
```

User Prompt：

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

---

## 12.4 TranslationResultParser

解析策略：

1. 尝试直接解析 JSON。
2. 如果模型返回 markdown code block，剥离 ```json。
3. 校验每个 item 是否包含 id 和 translation。
4. 对缺失项保留原文或不显示。
5. 对无法解析的返回结果显示错误提示。

---

## 12.5 TranslationCache

缓存非常重要，可以减少费用和延迟。

```swift
struct TranslationCacheKey: Hashable {
    let sourceText: String
    let targetLanguage: String
    let provider: String
}
```

缓存策略：

```text
normalize(sourceText)
lowercase if source language is English
trim spaces
collapse whitespace
```

第一版可以使用内存缓存。
后续可持久化到 SQLite / SwiftData。

---

# 13. Overlay 模块

## 13.1 OverlayWindowController

负责创建透明置顶窗口。

窗口特性：

```text
borderless
transparent background
non-activating
always on top
mouse click-through
full screen frame
does not steal focus
```

AppKit 设置方向：

```swift
window.styleMask = [.borderless, .nonactivatingPanel]
window.backgroundColor = .clear
window.isOpaque = false
window.level = .screenSaver
window.ignoresMouseEvents = true
window.collectionBehavior = [
    .canJoinAllSpaces,
    .fullScreenAuxiliary
]
```

注意：`screenSaver` level 很强，后续可以根据实际测试调整为 `.floating` 或 `.statusBar`。

---

## 13.2 OverlayView

SwiftUI 负责绘制译文块。

每个译文块样式：

```text
黑色半透明背景
白色或浅色文字
圆角
适度 padding
自动换行
最大宽度限制
轻微阴影
```

第一版建议：

```text
译文显示在原文下方
如果下方空间不够，显示在原文上方
```

---

## 13.3 OverlayLayoutEngine

职责：

* 将 OCR bounding box 转为 overlay frame。
* 决定译文显示在原文上方还是下方。
* 控制最大宽度。
* 避免译文块超出屏幕边界。
* 后续可处理多个译文块碰撞。

第一版简单策略：

```text
translationX = sourceBox.minX
translationY = sourceBox.maxY + 4
translationWidth = max(sourceBox.width * 1.5, 160)
translationHeight = auto
```

如果超过屏幕底部，则放到原文上方。

---

# 14. Settings 模块

## 14.1 SettingsStore

配置项：

```swift
struct AppSettings: Codable {
    var deepSeekAPIKey: String
    var targetLanguage: String
    var sourceLanguage: String
    var hotkey: String
    var fontSizeScale: Double
    var overlayOpacity: Double
    var autoClearSeconds: Double?
}
```

第一版设置项：

| 设置              | 默认值                 |
| --------------- | ------------------- |
| Target Language | Simplified Chinese  |
| Source Language | Auto                |
| Hotkey          | Command + Shift + T |
| Overlay Opacity | 0.75                |
| Font Size Scale | 1.0                 |
| Auto Clear      | Off                 |

---

## 14.2 APIKeyStore

API Key 不建议明文存在 UserDefaults。

推荐：

```text
Keychain
```

第一版如果为了开发速度，可以先用 UserDefaults，但正式版本应改成 Keychain。

---

# 15. Coordinator 设计

## 15.1 LensTranslationCoordinator

核心业务协调器。

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
        case .showingOverlay:
            clearOverlay()
        case .translating:
            cancelCurrentTask()
        case .failed:
            clearError()
        }
    }
}
```

---

# 16. 错误处理

## 16.1 常见错误

| 错误                     | 处理               |
| ---------------------- | ---------------- |
| 没有 Screen Recording 权限 | 弹出说明，引导用户打开系统设置  |
| OCR 没识别到文字             | 显示轻量提示，不弹大窗口     |
| API Key 缺失             | 打开设置页            |
| DeepSeek API 请求失败      | 显示错误状态           |
| JSON 解析失败              | 显示原文或提示解析失败      |
| Overlay 无法显示           | 记录日志，提示用户切换窗口化模式 |

---

# 17. 性能策略

## 17.1 第一版性能目标

```text
从按下快捷键到 overlay 显示：2-5 秒内
```

主要耗时：

| 阶段         |           预期耗时 |
| ---------- | -------------: |
| 截图         |        < 300ms |
| OCR        | 300ms - 1500ms |
| API 翻译     | 800ms - 4000ms |
| Overlay 绘制 |        < 100ms |

瓶颈通常是 OCR 和 API。

---

## 17.2 优化策略

1. **批量翻译**

   * 一次请求所有文本块。

2. **缓存翻译**

   * 同一句不重复发 API。

3. **限制 OCR 文本块数量**

   * 第一版可以限制最多 30-50 个文本块。

4. **过滤低置信度文本**

   * 减少无意义翻译。

5. **后续支持区域模式**

   * 对固定对白区域 OCR 会更快。

---

# 18. V0.1 开发计划

## Milestone 1：App 骨架

目标：

```text
菜单栏 App
设置页
快捷键触发
权限检查
```

产出：

```text
能按快捷键触发日志输出
```

---

## Milestone 2：截图 + OCR

目标：

```text
按快捷键捕获主屏幕
Vision OCR 识别文字
打印 text + confidence + bbox
```

产出：

```text
控制台可看到 OCR 结果
```

---

## Milestone 3：BBox Debug Overlay

目标：

```text
把 OCR 识别到的 bounding box 画在屏幕上
```

产出：

```text
验证坐标转换正确
```

这是关键里程碑。
如果 bounding box 对不齐，后面的译文覆盖都会错。

---

## Milestone 4：DeepSeek 翻译

目标：

```text
OCR 文本批量发送给 DeepSeek
解析 JSON 翻译结果
```

产出：

```text
控制台显示 id → translation 映射
```

---

## Milestone 5：译文 Overlay

目标：

```text
把译文显示在原文附近
```

产出：

```text
可用的 Snapshot Lens Translation
```

---

## Milestone 6：打磨

目标：

```text
缓存
错误提示
设置页
样式调整
清除 overlay
```

产出：

```text
V0.1 自用版本
```

---

# 19. 后续版本路线

## V0.2：目标窗口与区域模式

新增：

```text
捕获当前前台窗口
手动选择区域
区域记忆
窗口化游戏优化
```

## V0.3：Continuous Lens

新增：

```text
每 0.5-1 秒检测区域变化
图片差异判断
OCR 变化判断
翻译缓存
防闪烁
```

## V0.4：翻译质量增强

新增：

```text
术语表
游戏名上下文
人物名固定翻译
UI 短语压缩
翻译风格设置
```

## V1.0：产品化

新增：

```text
多显示器支持
更完善权限引导
Keychain API Key 存储
自动更新
崩溃日志
更好的视觉样式
```

---

# 20. 主要风险

## 20.1 Overlay 无法盖住部分游戏

尤其是：

```text
独占全屏
特殊渲染层
CrossOver 异常窗口
```

规避：

```text
第一版明确只支持窗口化 / 无边框窗口化
```

---

## 20.2 OCR 对游戏字体识别差

可能发生在：

```text
像素字体
花体字体
动态背景
低对比度 UI
```

规避：

```text
优先支持英文普通字体游戏
后续加入图像预处理
例如灰度化、放大、对比度增强
```

---

## 20.3 坐标转换错位

常见原因：

```text
Retina scaling
Vision 坐标原点
NSScreen 坐标
多显示器 origin
```

规避：

```text
第一版只支持主显示器
先做 bbox debug overlay
```

---

## 20.4 大模型返回非 JSON

规避：

```text
强 prompt
低 temperature
解析前清理 markdown code block
失败时重试一次
```

---

# 21. Debug 工具

强烈建议内置 Debug Mode。

Debug Mode 显示：

```text
OCR bounding boxes
OCR confidence
原文 text
转换后的 overlay frame
翻译耗时
API 请求耗时
```

开发期没有 Debug Overlay 会非常难调。

---

# 22. 最小可用版本定义

V0.1 被认为可用，当满足：

```text
1. 用户设置 DeepSeek API Key
2. 用户按 Command + Shift + T
3. App 捕获主屏幕
4. App OCR 当前屏幕英文
5. App 批量翻译为中文
6. App 在原文附近显示中文 overlay
7. Overlay 不影响鼠标点击游戏
8. 用户再次按快捷键可清除 overlay
```

---

# 23. 推荐第一版目录结构

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
│  └─ TranslationCache.swift
│
├─ Overlay/
│  ├─ OverlayWindowController.swift
│  ├─ OverlayView.swift
│  ├─ OverlayTextBlockView.swift
│  └─ OverlayLayoutEngine.swift
│
├─ Settings/
│  ├─ SettingsStore.swift
│  ├─ SettingsView.swift
│  └─ APIKeyStore.swift
│
├─ Coordinator/
│  └─ LensTranslationCoordinator.swift
│
└─ Debug/
   ├─ DebugLogger.swift
   └─ OCRDebugOverlayView.swift
```

---

# 24. 工程原则

## 24.1 优先跑通，不优先完美

第一版目标是：

```text
能用
位置大致对
翻译质量可接受
快捷键体验顺畅
```

不是：

```text
像商业软件一样完美实时
覆盖每一种游戏
支持所有全屏模式
```

---

## 24.2 先做坐标正确，再做翻译漂亮

开发顺序必须是：

```text
截图
→ OCR
→ bbox debug overlay
→ 坐标正确
→ 翻译
→ 译文 overlay
```

不要跳过 bbox debug overlay。

---

## 24.3 平台专注

当前项目不做跨平台。
所有设计优先服务 macOS：

```text
ScreenCaptureKit
Apple Vision
AppKit NSWindow
SwiftUI Settings
Keychain
```

---

# 25. 一句话总结

**Mac Game Lens Translator 的最快最好路线是：Swift 原生菜单栏 App + ScreenCaptureKit 单帧截图 + Apple Vision OCR + DeepSeek 批量翻译 + AppKit 透明置顶 Overlay。**

第一版只做 **按快捷键进行一次全屏 Lens 翻译**，这能最快验证核心体验，并避开实时翻译、窗口识别、多显示器、独占全屏等高复杂度问题。
