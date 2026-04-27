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
  private let explanationProvider: ExplanationProvider?
  private let vocabularyCardProvider: VocabularyCardProvider?
  @ObservationIgnored nonisolated(unsafe) private var shortcutChangeObserver: NSObjectProtocol?
  @ObservationIgnored private var activeExplanationRequestID = 0

  convenience init() {
    self.init(vocabularyRepository: try! SQLiteVocabularyRepository(path: AppModel.databasePath()))
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
        await self?.handleShortcut()
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
      latestValidationErrorMessage = nil
      latestDocument = nil
      latestCapturedText = nil

      let selectionStart = clock.now
      let selection = try await selectionReader.readSelection()
      shortcutFlowLogger.info(
        "Selection read in \(elapsedMilliseconds(from: selectionStart, clock: clock), privacy: .public) ms; characters: \(selection.text.count, privacy: .public); source: \(selection.sourceApp ?? "Unknown App", privacy: .public)."
      )
      let captured = classifier.classify(selection.text, sourceApp: selection.sourceApp)
      guard isCurrentExplanationRequest(requestID) else {
        shortcutFlowLogger.info("Ignoring stale shortcut selection result.")
        return
      }
      capturedForError = captured
      latestCapturedText = captured
      refreshPanel()

      let explanationStart = clock.now
      let document = try await explain(captured)
      shortcutFlowLogger.info(
        "Explanation completed in \(elapsedMilliseconds(from: explanationStart, clock: clock), privacy: .public) ms; mode: \(captured.mode.rawValue, privacy: .public); source characters: \(document.sourceText.count, privacy: .public)."
      )
      guard isCurrentExplanationRequest(requestID) else {
        shortcutFlowLogger.info("Ignoring stale shortcut explanation result.")
        return
      }

      if captured.mode == .word || captured.mode == .phrase {
        let vocabularyType: VocabularyType = captured.mode == .word ? .word : .phrase
        let cardDocument = try await generateVocabularyCard(for: captured)
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
      }

      latestCapturedText = captured
      latestDocument = document
      latestErrorMessage = nil
      latestValidationErrorMessage = nil
      refreshPanel()
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
      if let validationError = error as? LearningExplanationValidationError {
        latestValidationErrorMessage = validationError.description
        latestErrorMessage = nil
      } else {
        latestErrorMessage = String(describing: error)
        latestValidationErrorMessage = nil
      }
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
      let document = try await explain(adjusted)
      guard isCurrentExplanationRequest(requestID) else { return }
      latestCapturedText = adjusted
      latestDocument = document
      latestErrorMessage = nil
      latestValidationErrorMessage = nil
      refreshPanel()
    } catch {
      guard isCurrentExplanationRequest(requestID) else { return }
      latestCapturedText = adjusted
      latestDocument = nil
      if let validationError = error as? LearningExplanationValidationError {
        latestValidationErrorMessage = validationError.description
        latestErrorMessage = nil
      } else {
        latestErrorMessage = String(describing: error)
        latestValidationErrorMessage = nil
      }
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

  var allVocabularyCards: [VocabularyCard] {
    _ = vocabularyRevision
    return (try? vocabularyRepository.allCards()) ?? []
  }

  private func explain(_ captured: CapturedText) async throws -> LearningExplanationDocument {
    if let explanationProvider {
      return try await explanationProvider(captured)
    }

    let kind: PromptKind = switch captured.mode {
    case .word, .phrase: .wordExplanationSchema
    case .sentence: .sentenceAnalysisSchema
    }
    let template = promptStore.template(for: kind)!
    let activeProfile = settingsStore.loadAPIProviderSettings().activeProfile
    let apiKeyStore = activeProfile.map { KeychainAPIKeyStore(account: $0.keychainAccount) } ?? self.apiKeyStore
    let client = OpenAICompatibleClient(
      configuration: activeProfile?.configuration ?? settingsStore.loadAPIConfiguration(),
      apiKeyProvider: { try apiKeyStore.readAPIKey() }
    )
    let service = StructuredExplanationService(
      aiClient: client,
      preferences: settingsStore.loadLearningPreferences()
    )
    return try await service.explain(captured: captured, template: template)
  }

  private func generateVocabularyCard(for captured: CapturedText) async throws -> LearningExplanationDocument {
    if let vocabularyCardProvider {
      return try await vocabularyCardProvider(captured)
    }

    let template = promptStore.template(for: .vocabularyCardSchema)!
    let activeProfile = settingsStore.loadAPIProviderSettings().activeProfile
    let apiKeyStore = activeProfile.map { KeychainAPIKeyStore(account: $0.keychainAccount) } ?? self.apiKeyStore
    let client = OpenAICompatibleClient(
      configuration: activeProfile?.configuration ?? settingsStore.loadAPIConfiguration(),
      apiKeyProvider: { try apiKeyStore.readAPIKey() }
    )
    let service = StructuredExplanationService(
      aiClient: client,
      preferences: settingsStore.loadLearningPreferences()
    )
    return try await service.vocabularyCard(captured: captured, template: template)
  }

  private func refreshPanel() {
    let content = ExplanationPanelContent(
      capturedText: latestCapturedText,
      document: latestDocument,
      errorMessage: latestErrorMessage,
      validationErrorMessage: latestValidationErrorMessage
    )
    panelPresenter.show(
      content: content,
      onSwitchMode: { [weak self] mode in
        Task { @MainActor in
          await self?.explainWithMode(mode)
        }
      },
      onClose: { [weak self] in
        self?.panelPresenter.close()
      }
    )
  }

  private func beginExplanationRequest() -> Int {
    activeExplanationRequestID += 1
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
}

private func elapsedMilliseconds(from start: ContinuousClock.Instant, clock: ContinuousClock) -> Int64 {
  let components = start.duration(to: clock.now).components
  return components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000
}
