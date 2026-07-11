import CryptoKit
import Foundation
import Observation
import OSLog
import VocraCore

private let shortcutFlowLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "com.indincys.Vocra",
  category: "ShortcutFlow"
)

@MainActor
@Observable
final class AppModel {
  typealias ExplanationProvider = (CapturedText) async throws -> LearningExplanationDocument
  typealias VocabularyCardProvider = (CapturedText) async throws -> LearningExplanationDocument

  var latestCapturedText: CapturedText?
  var latestDocument: LearningExplanationDocument?
  var latestErrorMessage: String?
  var latestErrorRecovery: LookupErrorRecovery?
  var latestValidationErrorMessage: String?
  var isShortcutPaused = false
  var currentShortcut: KeyboardShortcut
  var shortcutRegistrationErrorMessage: String?
  let appUpdater = AppUpdater()
  var vocabularyRevision = 0

  private let classifier: TextClassifier
  private let promptStore: UserDefaultsPromptStore
  private let settingsStore: UserDefaultsSettingsStore
  private let apiKeyStore: KeychainAPIKeyStore
  private let selectionReader: any SelectionReader
  private let vocabularyRepository: SQLiteVocabularyRepository
  private let reviewScheduler: ReviewScheduler
  private let shortcutService: any ShortcutRegistering
  private let panelPresenter: any ExplanationPanelPresenting
  private let explanationCache: any ExplanationCaching
  private let explanationProvider: ExplanationProvider?
  private let vocabularyCardProvider: VocabularyCardProvider?
  @ObservationIgnored nonisolated(unsafe) private var shortcutChangeObserver: NSObjectProtocol?
  @ObservationIgnored private var activeExplanationRequestID = 0
  @ObservationIgnored private var activeRequestTask: Task<Void, Never>?
  /// Highest partial-content score rendered for the current request; reset per request so
  /// progressive updates only fire when new sections/segments stream in.
  @ObservationIgnored private var lastPartialSignature = 0
  // Memoized SQLite reads, invalidated by `vocabularyRevision`, so a SwiftUI body
  // re-evaluation doesn't re-query the database and recompute metrics every time.
  @ObservationIgnored private var cachedCards: [VocabularyCard]?
  @ObservationIgnored private var cachedCardsRevision = -1
  @ObservationIgnored private var cachedMetrics: DashboardMetrics?
  @ObservationIgnored private var cachedMetricsRevision = -1
  /// Set when the on-disk database couldn't be opened and an in-memory fallback is in use.
  var databaseErrorMessage: String?

  convenience init() {
    let repository: SQLiteVocabularyRepository
    var databaseError: String?
    do {
      repository = try SQLiteVocabularyRepository(path: AppModel.databasePath())
    } catch {
      // Disk full / corrupt DB file: degrade to an in-memory store instead of crashing at
      // launch. Review progress won't persist this run — surfaced in the menu bar.
      databaseError = "无法打开本地词库，本次运行改用临时内存词库，复习进度不会被保存。"
      // Opening an in-memory SQLite DB doesn't touch disk, so this can't fail from the same
      // cause; the crash surface shrinks from "any disk problem" to essentially never.
      repository = try! SQLiteVocabularyRepository.inMemory()
    }
    self.init(
      vocabularyRepository: repository,
      explanationCache: DiskExplanationCache(directory: AppModel.explanationCacheDirectory())
    )
    self.databaseErrorMessage = databaseError
  }

  init(
    classifier: TextClassifier = TextClassifier(),
    promptStore: UserDefaultsPromptStore = UserDefaultsPromptStore(),
    settingsStore: UserDefaultsSettingsStore = UserDefaultsSettingsStore(),
    apiKeyStore: KeychainAPIKeyStore = KeychainAPIKeyStore(),
    selectionReader: any SelectionReader = MacSelectionReader(),
    vocabularyRepository: SQLiteVocabularyRepository,
    reviewScheduler: ReviewScheduler = ReviewScheduler(),
    shortcutService: any ShortcutRegistering = ShortcutService(),
    panelPresenter: any ExplanationPanelPresenting = FloatingPanelController(),
    explanationCache: any ExplanationCaching = NoExplanationCache(),
    explanationProvider: ExplanationProvider? = nil,
    vocabularyCardProvider: VocabularyCardProvider? = nil
  ) {
    self.classifier = classifier
    self.promptStore = promptStore
    self.settingsStore = settingsStore
    self.apiKeyStore = apiKeyStore
    self.selectionReader = selectionReader
    self.vocabularyRepository = vocabularyRepository
    self.reviewScheduler = reviewScheduler
    self.shortcutService = shortcutService
    self.panelPresenter = panelPresenter
    self.explanationCache = explanationCache
    self.explanationProvider = explanationProvider
    self.vocabularyCardProvider = vocabularyCardProvider
    self.currentShortcut = settingsStore.loadKeyboardShortcut()
    self.shortcutChangeObserver = NotificationCenter.default.addObserver(
      forName: .vocraKeyboardShortcutDidChange,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let shortcut = notification.userInfo?[VocraNotificationUserInfoKey.keyboardShortcut] as? KeyboardShortcut else {
        return
      }
      Task { @MainActor in
        self?.registerShortcut(shortcut)
      }
    }
  }

  deinit {
    if let shortcutChangeObserver {
      NotificationCenter.default.removeObserver(shortcutChangeObserver)
    }
  }

  func start() {
    registerShortcut(settingsStore.loadKeyboardShortcut())
  }

  private func registerShortcut(_ shortcut: KeyboardShortcut) {
    currentShortcut = shortcut
    let result = shortcutService.register(shortcut: shortcut) { [weak self] in
      Task { @MainActor in
        self?.launchShortcutFlow()
      }
    }
    switch result {
    case .registered:
      shortcutRegistrationErrorMessage = nil
      shortcutFlowLogger.info("Registered global shortcut: \(shortcut.displayString, privacy: .public).")
    case .failed(let error):
      shortcutRegistrationErrorMessage = error.description
      shortcutFlowLogger.error("Global shortcut registration failed: \(error.description, privacy: .public)")
    }
  }

  func pauseShortcutListening(_ paused: Bool) {
    isShortcutPaused = paused
  }

  /// Cancels any in-flight lookup and starts a fresh shortcut-triggered one. Cancelling
  /// tears down the streaming URLSession request so an abandoned lookup stops using the
  /// network instead of running to completion in the background.
  private func launchShortcutFlow() {
    activeRequestTask?.cancel()
    activeRequestTask = Task { @MainActor [weak self] in
      await self?.handleShortcut()
    }
  }

  private func launchModeSwitch(_ mode: ExplanationMode) {
    activeRequestTask?.cancel()
    activeRequestTask = Task { @MainActor [weak self] in
      await self?.explainWithMode(mode)
    }
  }

  private func cancelActiveRequest() {
    activeRequestTask?.cancel()
    activeRequestTask = nil
  }

  func handleShortcut() async {
    guard !isShortcutPaused else {
      shortcutFlowLogger.info("Shortcut ignored because listening is paused.")
      return
    }

    let requestID = beginExplanationRequest()
    let clock = ContinuousClock()
    let flowStart = clock.now
    var capturedForError: CapturedText?
    shortcutFlowLogger.info("Shortcut handling started.")
    do {
      latestErrorMessage = nil
      latestErrorRecovery = nil
      latestValidationErrorMessage = nil
      latestDocument = nil
      latestCapturedText = nil
      // Show the HUD the instant the shortcut fires, before reading the selection. The
      // clipboard fallback can take 200ms+, and without this the user sees nothing and
      // wonders whether the shortcut registered.
      refreshPanel()

      let selectionStart = clock.now
      let selection = try await selectionReader.readSelection()
      shortcutFlowLogger.info(
        "Selection read in \(elapsedMilliseconds(from: selectionStart, clock: clock), privacy: .public) ms; characters: \(selection.text.count, privacy: .public); source: \(selection.sourceApp ?? "Unknown App", privacy: .public)."
      )
      let captured = classifier.classify(
        selection.text,
        sourceApp: selection.sourceApp,
        surroundingContext: selection.surroundingContext
      )
      guard isCurrentExplanationRequest(requestID) else {
        shortcutFlowLogger.info("Ignoring stale shortcut selection result.")
        return
      }
      capturedForError = captured
      latestCapturedText = captured
      refreshPanel()

      let explanationStart = clock.now
      let document = try await explain(captured, onPartial: partialHandler(for: captured, requestID: requestID))
      shortcutFlowLogger.info(
        "Explanation completed in \(elapsedMilliseconds(from: explanationStart, clock: clock), privacy: .public) ms; mode: \(captured.mode.rawValue, privacy: .public); source characters: \(document.sourceText.count, privacy: .public)."
      )
      guard isCurrentExplanationRequest(requestID) else {
        shortcutFlowLogger.info("Ignoring stale shortcut explanation result.")
        return
      }

      latestCapturedText = captured
      latestDocument = document
      latestErrorMessage = nil
      latestErrorRecovery = nil
      latestValidationErrorMessage = nil
      refreshPanel()

      if captured.mode == .sentence {
        await loadSentenceSupplement(for: captured, requestID: requestID)
      }

      await persistVocabularyIfNeeded(for: captured, explanation: document, requestID: requestID)

      shortcutFlowLogger.info(
        "Shortcut handling finished in \(elapsedMilliseconds(from: flowStart, clock: clock), privacy: .public) ms."
      )
    } catch {
      guard isCurrentExplanationRequest(requestID) else {
        shortcutFlowLogger.info("Ignoring stale shortcut error result.")
        return
      }
      latestCapturedText = capturedForError
      latestDocument = nil
      applyError(error)
      refreshPanel()
      shortcutFlowLogger.error(
        "Shortcut handling failed after \(elapsedMilliseconds(from: flowStart, clock: clock), privacy: .public) ms: \(String(describing: error), privacy: .public)"
      )
    }
  }

  func explainWithMode(_ mode: ExplanationMode) async {
    guard let current = latestCapturedText else { return }
    let requestID = beginExplanationRequest()
    let adjusted = CapturedText(originalText: current.originalText, cleanedText: current.cleanedText, mode: mode, sourceApp: current.sourceApp)
    do {
      let document = try await explain(adjusted, onPartial: partialHandler(for: adjusted, requestID: requestID))
      guard isCurrentExplanationRequest(requestID) else { return }
      latestCapturedText = adjusted
      latestDocument = document
      latestErrorMessage = nil
      latestErrorRecovery = nil
      latestValidationErrorMessage = nil
      refreshPanel()
      if adjusted.mode == .sentence {
        await loadSentenceSupplement(for: adjusted, requestID: requestID)
      }
      // Manually switching to word/phrase mode now saves to the notebook too, matching the
      // shortcut flow (previously only the shortcut flow auto-saved).
      await persistVocabularyIfNeeded(for: adjusted, explanation: document, requestID: requestID)
    } catch {
      guard isCurrentExplanationRequest(requestID) else { return }
      latestCapturedText = adjusted
      latestDocument = nil
      applyError(error)
      refreshPanel()
    }
  }

  func dueCards() -> [VocabularyCard] {
    _ = vocabularyRevision
    return (try? vocabularyRepository.dueCards(now: Date())) ?? []
  }

  func applyReview(cardID: UUID, rating: ReviewRating) {
    try? vocabularyRepository.applyReview(cardID: cardID, rating: rating, now: Date(), scheduler: reviewScheduler)
    vocabularyRevision += 1
  }

  /// Saves a term (the looked-up word, or a key term from a sentence parse) to
  /// the vocabulary book, deduplicating by normalized text.
  func addVocabularyEntry(text: String, type: VocabularyType, document: LearningExplanationDocument) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          let cardData = try? JSONEncoder().encode(document),
          let cardJSON = String(data: cardData, encoding: .utf8)
    else { return }
    do {
      _ = try vocabularyRepository.upsert(
        text: trimmed,
        type: type,
        cardJSON: cardJSON,
        sourceApp: latestCapturedText?.sourceApp,
        now: Date()
      )
      vocabularyRevision += 1
    } catch {
      shortcutFlowLogger.error("Manual vocabulary save failed: \(String(describing: error), privacy: .public)")
    }
  }

  var allVocabularyCards: [VocabularyCard] {
    _ = vocabularyRevision
    if cachedCardsRevision == vocabularyRevision, let cachedCards {
      return cachedCards
    }
    let cards = (try? vocabularyRepository.allCards()) ?? []
    cachedCards = cards
    cachedCardsRevision = vocabularyRevision
    return cards
  }

  var dashboardMetrics: DashboardMetrics {
    _ = vocabularyRevision
    if cachedMetricsRevision == vocabularyRevision, let cachedMetrics {
      return cachedMetrics
    }
    let metrics = DashboardMetrics(cards: allVocabularyCards)
    cachedMetrics = metrics
    cachedMetricsRevision = vocabularyRevision
    return metrics
  }

  private func explain(
    _ captured: CapturedText,
    onPartial: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> LearningExplanationDocument {
    if let explanationProvider {
      return try await explanationProvider(captured)
    }

    let kind: PromptKind = switch captured.mode {
    case .word, .phrase: .wordExplanationSchema
    case .sentence: .sentenceAnalysisSchema
    }
    let template = resolvedTemplate(for: kind)
    let resolved = makeExplanationService()
    let variant = cacheVariant(for: captured, templateBody: template.body)

    if let cached = explanationCache.cached(text: captured.cleanedText, mode: captured.mode, model: resolved.configuration.model, variant: variant) {
      shortcutFlowLogger.info("Explanation served from cache; mode: \(captured.mode.rawValue, privacy: .public).")
      return cached
    }

    let document = try await resolved.service.explain(captured: captured, template: template, onPartial: onPartial)
    explanationCache.store(document, text: captured.cleanedText, mode: captured.mode, model: resolved.configuration.model, variant: variant)
    return document
  }

  /// A stable fingerprint of everything besides text/mode/model that affects the result:
  /// schema version, learning preferences, and the prompt-template body. Changing any of
  /// these produces a different cache key so old entries don't shadow new settings.
  private func cacheVariant(for captured: CapturedText, templateBody: String) -> String {
    let prefs = settingsStore.loadLearningPreferences().normalized
    let material = [
      "v\(LearningExplanationDocument.currentSchemaVersion)",
      prefs.explanationDepth.rawValue,
      String(prefs.exampleCount),
      prefs.chineseStyle.rawValue,
      prefs.diagramDensity.rawValue,
      templateBody
    ].joined(separator: "|")
    let digest = SHA256.hash(data: Data(material.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  /// Builds the streaming callback that progressively renders a sentence as it arrives:
  /// feeds the HUD real progress, and — once whole sections (translation, trunk, segments)
  /// have streamed — promotes a partial document into the panel so the reader sees the
  /// meaning and skeleton within seconds. Hops to the main actor and re-checks staleness.
  private func partialHandler(for captured: CapturedText, requestID: Int) -> @Sendable (String) -> Void {
    { [weak self] partial in
      Task { @MainActor [weak self] in
        self?.handlePartial(partial, captured: captured, requestID: requestID)
      }
    }
  }

  private func handlePartial(_ partial: String, captured: CapturedText, requestID: Int) {
    guard isCurrentExplanationRequest(requestID) else { return }
    panelPresenter.updateProgress(receivedCharacters: partial.count)

    guard captured.mode == .sentence,
          let json = PartialJSONCompleter.completedObject(from: partial),
          let document = try? JSONDecoder().decode(LearningExplanationDocument.self, from: Data(json.utf8)),
          var analysis = document.sentenceAnalysis
    else { return }

    let signature = partialSentenceSignature(analysis)
    guard signature > lastPartialSignature else { return }
    lastPartialSignature = signature

    if analysis.sentence.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      analysis.sentence = AnalyzedSentence(text: captured.cleanedText, segments: analysis.sentence.segments)
    }
    var promoted = document
    promoted.mode = captured.mode
    promoted.sourceText = captured.cleanedText
    promoted.sentenceAnalysis = analysis

    latestCapturedText = captured
    latestDocument = promoted
    latestErrorMessage = nil
    latestErrorRecovery = nil
    latestValidationErrorMessage = nil
    refreshPanel()
  }

  /// A monotonically-growing score of how much renderable sentence content has arrived, so
  /// the panel only re-renders when a new section or segment appears.
  private func partialSentenceSignature(_ analysis: SentenceAnalysis) -> Int {
    var score = 0
    if !analysis.translation.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
    if !analysis.structureBreakdown.trunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
    if !analysis.logicSummary.coreMeaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
    score += analysis.structureBreakdown.items.count
    score += analysis.sentence.segments.count
    score += analysis.logicSummary.points.count
    return score
  }

  /// Fetches the relationship diagram + key vocabulary that were kept out of the
  /// first-screen sentence request and merges them into the shown document. Best-effort:
  /// a failure just leaves those sections empty. Skips work when the sections are already
  /// present (e.g. served from a previously-merged cache entry).
  private func loadSentenceSupplement(for captured: CapturedText, requestID: Int) async {
    guard explanationProvider == nil, captured.mode == .sentence else { return }
    guard let analysis = latestDocument?.sentenceAnalysis,
          analysis.relationshipDiagram.edges.isEmpty, analysis.keyVocabulary.isEmpty
    else { return }

    let template = resolvedTemplate(for: .sentenceSupplementSchema)
    let resolved = makeExplanationService()
    guard let supplement = try? await resolved.service.sentenceSupplement(captured: captured, template: template) else { return }
    guard isCurrentExplanationRequest(requestID),
          var document = latestDocument,
          var mergedAnalysis = document.sentenceAnalysis
    else { return }

    mergedAnalysis.relationshipDiagram = supplement.relationshipDiagram
    mergedAnalysis.keyVocabulary = supplement.keyVocabulary
    document.sentenceAnalysis = mergedAnalysis
    latestDocument = document
    refreshPanel()
    // Re-store the merged document under the same key the main lookup used, so a later
    // cache hit already includes the diagram + key vocabulary and skips this request.
    let variant = cacheVariant(for: captured, templateBody: resolvedTemplate(for: .sentenceAnalysisSchema).body)
    explanationCache.store(document, text: captured.cleanedText, mode: captured.mode, model: resolved.configuration.model, variant: variant)
  }

  /// Saves the looked-up word/phrase to the notebook. The card is synthesized locally from
  /// the already-returned `WordExplanation` (no second model call); tests can still inject a
  /// `vocabularyCardProvider` to exercise the async path. Guards against stale requests.
  private func persistVocabularyIfNeeded(
    for captured: CapturedText,
    explanation document: LearningExplanationDocument,
    requestID: Int
  ) async {
    guard captured.mode == .word || captured.mode == .phrase else { return }
    let vocabularyType: VocabularyType = captured.mode == .word ? .word : .phrase
    do {
      guard let cardDocument = try await vocabularyCardDocument(for: captured, explanation: document) else { return }
      guard isCurrentExplanationRequest(requestID) else {
        shortcutFlowLogger.info("Ignoring stale shortcut vocabulary card result.")
        return
      }
      let cardJSON = String(data: try JSONEncoder().encode(cardDocument), encoding: .utf8)!
      _ = try vocabularyRepository.upsert(
        text: captured.cleanedText,
        type: vocabularyType,
        cardJSON: cardJSON,
        sourceApp: captured.sourceApp,
        now: Date()
      )
      vocabularyRevision += 1
    } catch {
      guard isCurrentExplanationRequest(requestID) else {
        shortcutFlowLogger.info("Ignoring stale shortcut vocabulary card error result.")
        return
      }
      shortcutFlowLogger.error(
        "Vocabulary card save failed after primary explanation was shown: \(String(describing: error), privacy: .public)"
      )
    }
  }

  private func vocabularyCardDocument(
    for captured: CapturedText,
    explanation document: LearningExplanationDocument
  ) async throws -> LearningExplanationDocument? {
    if let vocabularyCardProvider {
      return try await vocabularyCardProvider(captured)
    }
    return VocabularyCardSynthesizer.card(from: document, captured: captured)
  }

  /// Builds a client + structured-explanation service for the active API profile,
  /// resolving its per-profile Keychain account. Shared by the main lookup, the sentence
  /// supplement, and the vocabulary card so the assembly lives in one place.
  private func makeExplanationService() -> (service: StructuredExplanationService, configuration: APIConfiguration) {
    let activeProfile = settingsStore.loadAPIProviderSettings().activeProfile
    let configuration = activeProfile?.configuration ?? settingsStore.loadAPIConfiguration()
    let apiKeyStore = activeProfile.map { KeychainAPIKeyStore(account: $0.keychainAccount) } ?? self.apiKeyStore
    let client = OpenAICompatibleClient(
      configuration: configuration,
      apiKeyProvider: { try apiKeyStore.readAPIKey() }
    )
    let service = StructuredExplanationService(
      aiClient: client,
      preferences: settingsStore.loadLearningPreferences()
    )
    return (service, configuration)
  }

  /// Resolves a prompt template, falling back to the bundled default if the store somehow
  /// has no entry for the kind (rather than force-unwrapping and crashing).
  private func resolvedTemplate(for kind: PromptKind) -> PromptTemplate {
    promptStore.template(for: kind)
      ?? InMemoryPromptStore.defaults().template(for: kind)
      ?? PromptTemplate(kind: kind, body: "Return a single JSON object for {{text}}.")
  }

  /// Stores an error for display: validation errors stay as-is (structural feedback),
  /// everything else is mapped to a plain-Chinese message plus an optional recovery action.
  private func applyError(_ error: Error) {
    if let validationError = error as? LearningExplanationValidationError {
      latestValidationErrorMessage = validationError.description
      latestErrorMessage = nil
      latestErrorRecovery = nil
    } else {
      let presentation = LookupErrorPresenter.present(error)
      latestErrorMessage = presentation.message
      latestErrorRecovery = presentation.recovery
      latestValidationErrorMessage = nil
    }
  }

  private func refreshPanel() {
    let content = ExplanationPanelContent(
      capturedText: latestCapturedText,
      document: latestDocument,
      errorMessage: latestErrorMessage,
      errorRecovery: latestErrorRecovery,
      validationErrorMessage: latestValidationErrorMessage
    )
    panelPresenter.show(
      content: content,
      onSwitchMode: { [weak self] mode in
        self?.launchModeSwitch(mode)
      },
      onSaveVocabulary: { [weak self] text, type, document in
        self?.addVocabularyEntry(text: text, type: type, document: document)
      },
      onClose: { [weak self] in
        self?.cancelActiveRequest()
        self?.panelPresenter.close()
      }
    )
  }

  private func beginExplanationRequest() -> Int {
    activeExplanationRequestID += 1
    lastPartialSignature = 0
    return activeExplanationRequestID
  }

  private func isCurrentExplanationRequest(_ requestID: Int) -> Bool {
    requestID == activeExplanationRequestID
  }

  private static func databasePath() -> String {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let folderName = Bundle.main.bundleIdentifier == "com.indincys.Vocra.dev" ? "Vocra Dev" : "Vocra"
    let folder = support.appending(path: folderName, directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder.appending(path: "vocra.sqlite").path
  }

  private static func explanationCacheDirectory() -> URL {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let folderName = Bundle.main.bundleIdentifier == "com.indincys.Vocra.dev" ? "Vocra Dev" : "Vocra"
    return support
      .appending(path: folderName, directoryHint: .isDirectory)
      .appending(path: "ExplanationCache", directoryHint: .isDirectory)
  }
}
