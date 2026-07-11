# Vocra 优化目标清单

> 本文档是一次全面代码审查的产出,按"批次"组织,每个批次可以独立交给一个会话完成。
> 批次内的任务有关联,建议一个批次一次做完;批次之间按编号顺序执行(前面的批次消除了后面批次的部分工作量,顺序不要颠倒)。
> 每个批次做完后运行 `swift build && swift test`,涉及 UI/面板的批次用 `./script/build_and_run.sh --verify` 真机验证。

## 背景:核心问题诊断

句子解析慢的根因:**要求模型生成的 JSON 太大(典型 1500–2500 输出 token),且其中约一半是浪费**(原句被回显 5~6 遍、UI 从不使用的字段、本地已知的常量),再乘上模型吐字速度就是几十秒。另有两个隐藏翻倍因素:校验失败触发的 repair 重试会再吐一整份文档;混合推理模型可能在输出前烧思考 token。本地链路(选区读取、分类、prompt 渲染、解码校验)合计不到 1 秒,不是瓶颈。

---

## 批次 1:诊断日志 + 消除 repair 重试(稳定性 & 最坏耗时)

目标:让"偶尔特别慢"(校验失败 → 整轮重试,耗时翻倍)基本消失,并能区分首字延迟和吐字时长。

1. **TTFT 诊断日志**
   - 文件:`Sources/VocraCore/Services/OpenAICompatibleClient.swift`(流式循环约 126 行处)。
   - 在收到第一个 delta 时记一条 os_log("首字耗时 X ms"),与现有的总耗时日志配合,把总时间拆成 TTFT 和吐字时长,用于判断后续优化方向(TTFT 大 → 换模型/关思考;吐字长 → 砍 token)。

2. **解码前本地提取 JSON**
   - 文件:`Sources/VocraCore/Services/StructuredExplanationService.swift`(`decodeAndValidate`,约 55 行)。
   - 当前只 trim 空白就解码,模型包一层 ```json 围栏或在 JSON 前后加一句话就触发完整 repair 重试。解码前:剥掉 Markdown 代码围栏;定位第一个 `{` 到配平的 `}` 提取子串再解码。
   - 测试:`StructuredExplanationServiceTests` 补围栏/前后缀 prose 的用例。

3. **sourceText / mode 不匹配时本地覆盖,不再 repair**
   - 文件:`Sources/VocraCore/Services/LearningExplanationValidator.swift`(约 46 行)、`StructuredExplanationService.swift`。
   - 这两个值本地已知(`captured.cleanedText` / `captured.mode`),模型稍改大小写或标点就 `sourceTextMismatch` → 白白重试几十秒。改为解码后直接用本地值覆盖 `document.sourceText` 和 `document.mode`,validator 里删除这两项检查;repair 只保留给真正的结构性问题(缺分支、空必填字段、悬空的 diagram 节点引用)。

4. **请求体加结构化输出参数**
   - 文件:`Sources/VocraCore/Services/OpenAICompatibleClient.swift`(`ChatCompletionRequest`)、`Sources/VocraCore/Models/APIConfiguration.swift`、设置界面 `Sources/Vocra/Views/SettingsView.swift`。
   - 加 `response_format: {"type":"json_object"}`、较低的 `temperature`、`max_tokens` 上限(防异常输出跑满 45s 超时)。
   - `response_format` 个别自建端点不支持:做成 `APIConfiguration`/profile 上的开关(默认开),或收到 4xx 时自动去掉该参数重发一次。

5. **请求可取消**
   - 文件:`Sources/Vocra/App/AppModel.swift`。
   - 现在 stale-request 守卫只"丢弃结果",旧的流式请求仍在后台跑完;Esc 关面板也不取消在途请求。`AppModel` 持有当前请求的 `Task`,新请求开始或面板关闭时 `cancel()`(`URLSession.bytes` 对取消响应良好,`AsyncThrowingStream` 的 `onTermination` 已接好)。

---

## 批次 2:削减输出 token(总耗时真实下降 40–60%)

目标:让模型只生成"需要思考的内容",本地可知的一律本地填。改动集中在 prompt 模板(`Sources/VocraCore/Stores/PromptStore.swift` 的 `BundledPromptTemplates`)、`LearningExplanationDocument` 解码默认值、validator、以及模板迁移逻辑。

> 注意:改了 bundled 模板后要同步更新 `PromptStore.swift` 里的 `isLegacyBundledDefault` / `isPreviousStructuredBundledDefault` 迁移判断,让未手动编辑过模板的老用户自动升级到新模板。

6. **去掉所有回显和常量字段**
   - 模板不再要求模型输出:`sourceText`、`sentence.text`(整句回显)、`headline`、`language`、`schemaVersion`、各处固定 `title`("句子主干"、"例句翻译"等)。这些全部在解码后本地填充。
   - `LearningExplanationDocument` 的自定义 `init(from:)` 已有大量 `decodeIfPresent` 默认值,把剩余字段也改成可缺省;validator 同步放宽。
   - 效果:原句从被回显 5~6 遍降为 0 遍,固定中文标题不再消耗 token。

7. **删掉 UI 不用的字段,约束 note 长度**
   - `labelEn` 在所有视图里零引用(已 grep 确认),`headline` 也未被 `SentenceLearningView` 使用:模板中删除,模型不再生成(解码保持可选,兼容旧缓存)。
   - 模板给每条 `note` 加长度约束(如"每条 note ≤ 40 字"),中文约 1 字 ≈ 1 token,这一条能省几百 token 且更适合面板阅读。

8. **relationshipDiagram 和 keyVocabulary 改为按需/并行**
   - 这两块合计约占输出 25–35%。二选一:
     - 首屏请求不生成,用户展开该区块时再发小请求补齐;
     - 或与主请求并行发第二个小请求,到达后再渲染该区块。
   - 涉及:模板拆分(`PromptKind` 可能加新 case)、`AppModel` 的请求编排、`SentenceLearningView` 的占位/加载态。

9. **(可选,工作量大)segments 改用词索引**
   - 让模型返回 `{"start": 3, "end": 7}`(词序号)代替回显文本 span,本地切原句得到下划线区间。
   - 额外收益:彻底解决"模型改写原文导致 `RoleUnderlinedSentence` 匹配失败"的问题(现有 fallback 在 `Sources/Vocra/Views/LearningPopoverKit.swift` 约 381 行)。
   - 若做,批次 2 其余项先落地验证后再动这项。

---

## 批次 3:单词查询砍掉第二次模型调用

10. **本地合成生词卡,替代 vocabularyCard 模型调用**
    - 文件:`Sources/Vocra/App/AppModel.swift`(`handleShortcut` 约 171 行、`generateVocabularyCard`)。
    - 现状:每次查单词/词组打两次完整模型调用,第二次生成的卡片内容(核心义、用法、例句)与 `wordExplanation` 高度重合 —— token 成本和卡片延迟直接翻倍。
    - 改为:从已返回的 `WordExplanation` 本地映射出 `StructuredVocabularyCard`(coreMeaning→coreMeaning,usageNotes→usage,examples→examples,contextualMeaning 可作 memoryNote 素材),零成本零延迟。`vocabularyCardSchema` 模板与 `PromptKind.vocabularyCardSchema` 可保留作为兜底或删除。
    - 顺带修复不一致:`explainWithMode` 手动切到"单词"模式后不会自动存生词本,而快捷键流会自动存 —— 统一两者行为。
    - 测试:`AppModelTests` 已有注入 `vocabularyCardProvider` 的用例,需同步调整。

---

## 批次 4:流式渐进渲染(体感收益最大,首屏 3–5 秒)

11. **接通 onPartial,按区块渐进渲染**
    - 管道已通:`AIClient.complete(onPartial:)` → `StructuredExplanationService.explain(onPartial:)`,只是 `AppModel.explain`(约 316 行)没传 `onPartial`。
    - 三步走:
      a. 模板里规定字段生成顺序:`translation` → `trunk/trunkZh` → `segments` → 其余(模型按 prompt 中 shape 的顺序生成,可控);
      b. 对流式片段做容错增量解析:补全未闭合括号后尝试解码,或按 key 提取已完整的子对象;某区块完整即先渲染 —— 用户几秒内先看到译文和主干,语法细节随后补齐;
      c. 最低成本兜底:把已接收字符数喂给 `LookupProgress`,HUD 从纯 indeterminate 动画变成真实进度感。
    - 涉及:`AppModel`、`FloatingPanelController`、`LookupHUDView`、`SentenceLearningView`(各区块支持缺省/加载态)。
    - 注意保持现有 stale-request 守卫模式(每个 await 后检查 `isCurrentExplanationRequest`)。

12. **面板复用 NSHostingView(渐进渲染的前置)**
    - 文件:`Sources/Vocra/Support/FloatingPanelController.swift`(约 65 行)。
    - 现在每次 `show` 都新建 `NSHostingView`:滚动位置、`wordSaved` 等 `@State` 全部重置,切模式有视觉闪断,渐进刷新会闪得更明显。改为持有一个 hosting view,更新其 `rootView`。

---

## 批次 5:缓存正确性

13. **缓存 key 补全维度 + 容量上限**
    - 文件:`Sources/VocraCore/Services/ExplanationCache.swift`(`key` 约 53 行)。
    - 现状:key 只有 `mode|model|text`。用户改学习偏好(解释深度/例句数/中文风格)或发版更新 prompt 模板后,旧缓存照样命中,看起来"设置不生效"。
    - key 加入 `schemaVersion + hash(模板体 + LearningPreferences)`;`AppModel.explain` 调用处传入这些参数。
    - 内存字典和磁盘目录当前无上限、永不过期:加简单容量上限(如磁盘 2000 条按 mtime 淘汰,内存条数上限)。
    - 注意:批次 2 改模板后 key 自然变化,旧缓存整体失效,是预期行为。

---

## 批次 6:UX 修缮

14. **错误信息中文化 + 恢复动作**
    - 文件:`Sources/Vocra/App/AppModel.swift`(错误路径约 210 行,`String(describing: error)` 直接上屏)、`ExplanationPanelView`。
    - 建一层错误映射:`AIClientError.missingAPIKey` → "尚未配置 API Key" + 打开设置按钮;`SelectionReaderError.accessibilityPermissionMissing` → 中文说明 + 按钮直达系统设置的辅助功能面板(`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`);401/429/超时/断网各给一句人话。

15. **快捷键按下立即出 HUD**
    - 文件:`Sources/Vocra/App/AppModel.swift`(`handleShortcut`,HUD 目前在选区读取+分类后约 150 行才显示)。
    - 剪贴板兜底时真空期 200ms+,用户会怀疑没按到。入口处先显示 HUD("正在读取选中内容…"),拿到文本后更新词条。

16. **剪贴板兜底提速 + 修饰键隐患**
    - 文件:`Sources/VocraCore/Services/SelectionReader.swift`(固定 `sleep 180ms`,约 96 行)。
    - 改为每 15–20ms 轮询 `changeCount`(上限 ~300ms):快的应用省 150ms,慢的应用更可靠。
    - 修饰键隐患:快捷键是 Option-Space,合成 Cmd-C 时用户可能还压着 Option,部分应用收到 Cmd-Opt-C。在 CGEvent flags 上显式清掉其他修饰键,或等修饰键释放后再发。

17. **词条边缘标点清理**
    - 文件:`Sources/VocraCore/Services/TextClassifier.swift`(`clean` 只去引号)。
    - 选中 "however," 时,面板标题、TTS 朗读、缓存 key、生词本去重全带逗号("however," 和 "however" 存成两张卡)。对判定为 word/phrase 的文本再 trim 边缘标点(注意:句子模式不能动标点,`hasSentencePunctuation` 依赖它)。
    - 测试:`TextClassifierTests` 补用例。

18. **深色模式**
    - 文件:`Sources/Vocra/Views/ExplanationPanelView.swift`(强制 `.environment(\.colorScheme, .light)`,约 39 行)、`FloatingPanelController`(`NSAppearance(named: .aqua)`)、`Sources/Vocra/Views/VocraTheme.swift`。
    - `VocraTheme` 已集中管理颜色,补一套暗色值,跟随系统外观。工作量主要在逐色适配和视觉验证。

19. **上下文喂给模型(内容质量,顺带做)**
    - 文件:`Sources/VocraCore/Services/SelectionReader.swift`、`Sources/VocraCore/Services/LearningPromptFactory.swift`(`surroundingContext` 恒为空字符串,约 20 行)。
    - Prompt 要求模型给"语境含义"(contextualMeaning),但从未提供语境。用 AX 的 `kAXValueAttribute` + `kAXSelectedTextRangeAttribute` 取选区前后各 100–200 字符,填入 `surroundingContext`,模板中引用 `{{surroundingContext}}`。
    - 注意与批次 2 的 token 预算平衡:上下文是输入 token(prefill 快、便宜),不影响输出耗时。

---

## 批次 7:代码质量

20. **启动即崩的 `try!`**
    - `Sources/Vocra/App/AppModel.swift` convenience init(约 44 行):DB 打开失败(磁盘满/文件损坏)直接 crash。降级到 `SQLiteVocabularyRepository.inMemory()` 并在菜单/面板提示。

21. **强解包与隐晦模式**
    - `promptStore.template(for:)!`(AppModel 约 298 行):`PromptKind` 加新 case 时是运行时炸点,改为 throw 或回退 bundled 默认。
    - `UserDefaultsPromptStore.loadAll` 读时写迁移的模式较隐晦,加注释或拆出显式 `migrateIfNeeded()`。

22. **SwiftUI 每次求值全表扫**
    - `AppModel.allVocabularyCards` / `dashboardMetrics` 是计算属性,body 每次求值都重新查 SQLite + 重算指标。按 `vocabularyRevision` 做记忆化(revision 不变直接返回缓存数组)。

23. **重复代码收敛**
    - `explain` 与 `generateVocabularyCard` 有 15 行重复的 profile/keychain/client/service 组装,抽 `makeExplanationService()`(批次 3 若删掉卡片调用则自然消解,注意合并)。
    - `elapsedMilliseconds` 辅助函数在 `AppModel.swift` / `OpenAICompatibleClient.swift` / `SelectionReader.swift` 三处各抄一份,收敛到 VocraCore 一处。

24. **杂项**
    - `VocraApp.mainWindowScene` 在 Scene 计算属性里做副作用赋值 `appDelegate.openMainWindow`,移到 `init` 或 `onAppear`。
    - `LearningExample.id { sentence }` / `VocabularyCardExample` 同:重复例句会产生重复 ForEach ID,改用枚举索引或 UUID。

---

## 执行顺序与依赖备注

- **批次 1 → 2 → 3 → 4** 是速度主线,严格按序:批次 1 的 #3(本地覆盖)让批次 2 删 `sourceText` 回显时 validator 改动更小;批次 4 依赖批次 2 的字段顺序约定和 #12 的面板复用。
- 批次 5(缓存)放在批次 2 之后做,避免 key 设计两次返工。
- 批次 6、7 与主线无依赖,可穿插;但 #12(NSHostingView 复用)必须在批次 4 之前完成,已归入批次 4。
- 每个批次的验收:`swift test` 全绿 + 对涉及面板/流式的批次用 `./script/build_and_run.sh --logs` 实测一次查词和一次长句解析,观察 os_log 里的耗时日志(批次 1 加的 TTFT 日志用来量化后续批次的收益)。

---

## 完成情况(2026-07-12)

全部批次已实现并提交到本地 `main`;`swift build` / `swift test` 全绿(117 个用例,0 失败),涉及面板/流式/暗色的批次用 `./script/build_and_run.sh --verify` 确认可正常启动。

- [x] **批次 1**:#1 TTFT 日志、#2 解码前本地提取 JSON(去围栏/前后 prose)、#3 sourceText/mode 本地覆盖并删除 validator 两项检查、#4 `response_format`/`temperature`/`max_tokens` + 4xx 自动去参重发 + 设置开关、#5 请求可取消(新请求/关面板/Esc/点外均取消在途流)。commit `perf: batch 1`
- [x] **批次 2**:#6 删除回显与常量字段(sourceText、sentence.text、headline、language、schemaVersion、固定标题、role/labelEn)本地填充、#7 删 UI 不用字段 + note ≤40 字、#8 relationshipDiagram + keyVocabulary 拆成并行的 `sentenceSupplementSchema` 补充请求。commit `perf: batch 2`
  - [ ] **#9(可选,工作量大)segments 改词索引**:暂缓。批次 2 已改为本地用捕获原文回填 `sentence.text`,下划线匹配的鲁棒性问题已大幅缓解;此项收益有限、改动面大,按文档"可选"标注保留。
- [x] **批次 3**:#10 本地由 `WordExplanation` 合成生词卡(`VocabularyCardSynthesizer`),去掉第二次模型调用,并统一手动切模式的存词行为。commit `perf: batch 3`
- [x] **批次 4**:#11 接通 `onPartial`,按区块渐进渲染句子(模板字段顺序 + `PartialJSONCompleter` + 单调内容签名 + HUD 真实进度)、#12 面板复用单个 `NSHostingView`。commit `feat: batch 4`
- [x] **批次 5**:#13 缓存 key 补 `variant`(schemaVersion + 偏好 + 模板体哈希),内存 FIFO 上限 + 磁盘按 mtime 淘汰上限。commit `fix: batch 5`
- [x] **批次 6**:#14 错误信息中文化 + 恢复动作(`LookupErrorPresenter` + 打开设置/辅助功能按钮)、#15 快捷键按下立即出 HUD、#16 剪贴板轮询 changeCount + 私有事件源清修饰键、#17 词/词组边缘标点清理、#18 暗色模式(动态色 token,跟随系统)、#19 AX 上下文喂给模型。commits `feat: batch 6 (part 1/2)`
- [x] **批次 7**:#20 DB 打开失败降级到内存库 + 菜单提示、#21 去强解包(`resolvedTemplate` 兜底)+ 迁移逻辑加注释、#22 `allVocabularyCards`/`dashboardMetrics` 按 revision 记忆化、#23 收敛 `makeExplanationService` 与 `elapsedMilliseconds`、#24 `mainWindowScene` 副作用移到菜单栏 label 的 onAppear(例句 ForEach 已用枚举索引,无重复 ID 隐患)。commit `refactor: batch 7`
