import Foundation
import Observation
import OSLog
import VocraCore

enum ArticleAnalysisError: Error {
  case undecodableDocument
}

private let articleLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "com.indincys.Vocra",
  category: "ArticleLibrary"
)

/// Owns the reading library: collected articles, their sentence-by-sentence analyses, the
/// background prefetch that fills those in, and the retention sweep that clears them out.
///
/// Analyses are written straight into SQLite next to the sentence, so reopening an article is
/// a single local read — no model call, no spinner.
@MainActor
@Observable
final class ArticleLibraryModel {
  typealias AnalysisProvider = (String) async throws -> LearningExplanationDocument

  private(set) var articles: [Article] = []
  /// Sentences of `selectedArticleID`, in reading order.
  private(set) var sentences: [ArticleSentence] = []
  private(set) var selectedArticleID: UUID?
  private(set) var analyzingSentenceIDs: Set<UUID> = []
  private(set) var errorMessage: String?
  private(set) var retention: ArticleRetention

  private let repository: any ArticleRepository
  private let segmenter: ArticleSegmenter
  private let serviceFactory: ExplanationServiceFactory
  private let promptStore: UserDefaultsPromptStore
  private let settingsStore: UserDefaultsSettingsStore
  private let explanationCache: any ExplanationCaching
  private let analysisProvider: AnalysisProvider?
  @ObservationIgnored private var prefetchTask: Task<Void, Never>?
  /// Bumped on every cancel/start so a finishing prefetch can tell whether it's still the
  /// current one before clearing `prefetchTask`.
  @ObservationIgnored private var prefetchGeneration = 0
  /// Sentences whose analysis failed. Kept out of the background queue so one bad request
  /// (offline, bad key, rate limit) can't spin the whole article in a retry loop; expanding
  /// the sentence retries it explicitly.
  @ObservationIgnored private var failedSentenceIDs: Set<UUID> = []
  @ObservationIgnored nonisolated(unsafe) private var retentionObserver: NSObjectProtocol?

  /// How many sentences are analyzed at once. Two keeps the reader filling in quickly
  /// without hammering a rate-limited endpoint.
  private static let prefetchConcurrency = 2

  init(
    repository: any ArticleRepository,
    segmenter: ArticleSegmenter = ArticleSegmenter(),
    settingsStore: UserDefaultsSettingsStore = UserDefaultsSettingsStore(),
    promptStore: UserDefaultsPromptStore = UserDefaultsPromptStore(),
    explanationCache: any ExplanationCaching = NoExplanationCache(),
    analysisProvider: AnalysisProvider? = nil
  ) {
    self.repository = repository
    self.segmenter = segmenter
    self.settingsStore = settingsStore
    self.promptStore = promptStore
    self.explanationCache = explanationCache
    self.analysisProvider = analysisProvider
    self.serviceFactory = ExplanationServiceFactory(settingsStore: settingsStore)
    self.retention = settingsStore.loadArticleRetention()
  }

  deinit {
    if let retentionObserver {
      NotificationCenter.default.removeObserver(retentionObserver)
    }
  }

  // MARK: Lifecycle

  func start() {
    sweepExpired()
    reloadArticles()
    retentionObserver = NotificationCenter.default.addObserver(
      forName: .vocraArticleRetentionDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.applyStoredRetention() }
    }
  }

  var selectedArticle: Article? {
    articles.first { $0.id == selectedArticleID }
  }

  // MARK: Collecting

  /// Segments a selection into an article and stores it. Returns nil (with `errorMessage`
  /// set) when the selection is too short to be worth reading line by line.
  @discardableResult
  func collect(text: String, sourceApp: String?, now: Date = Date()) -> Article? {
    let draft = segmenter.segment(text)
    guard ArticleLengthPolicy.isCollectable(draft) else {
      errorMessage = "选中的内容太短，长文收录至少需要 \(ArticleLengthPolicy.minimumCharacters) 个字符。"
      articleLogger.info("Article collection skipped: selection too short (\(draft.text.count, privacy: .public) characters).")
      return nil
    }

    do {
      let article = try repository.insert(draft: draft, sourceApp: sourceApp, now: now)
      errorMessage = nil
      reloadArticles()
      articleLogger.info(
        "Collected article with \(draft.sentences.count, privacy: .public) sentences from \(sourceApp ?? "Unknown App", privacy: .public)."
      )
      return article
    } catch {
      errorMessage = "收录失败：\(error)"
      articleLogger.error("Article collection failed: \(String(describing: error), privacy: .public)")
      return nil
    }
  }

  // MARK: Selection

  func select(articleID: UUID?) {
    guard articleID != selectedArticleID else { return }
    prefetchTask?.cancel()
    prefetchTask = nil
    analyzingSentenceIDs = []
    selectedArticleID = articleID

    guard let articleID else {
      sentences = []
      return
    }

    try? repository.markOpened(articleID: articleID, now: Date())
    reloadSentences()
    startPrefetch()
  }

  func delete(articleID: UUID) {
    if articleID == selectedArticleID {
      select(articleID: nil)
    }
    do {
      try repository.delete(articleID: articleID)
      reloadArticles()
    } catch {
      errorMessage = "删除失败：\(error)"
    }
  }

  // MARK: Analysis

  /// Analyzes one sentence now, jumping ahead of the background queue — used when the reader
  /// expands a sentence the prefetch hasn't reached yet.
  func analyzeNow(sentenceID: UUID) {
    guard let sentence = sentences.first(where: { $0.id == sentenceID }), !sentence.isAnalyzed else { return }
    guard !analyzingSentenceIDs.contains(sentenceID) else { return }
    failedSentenceIDs.remove(sentenceID)
    Task { await analyze(sentence) }
  }

  /// Kicks off (or resumes) filling in every unanalyzed sentence of the open article.
  func startPrefetch() {
    guard prefetchTask == nil else { return }
    prefetchGeneration += 1
    let generation = prefetchGeneration
    prefetchTask = Task { @MainActor [weak self] in
      await self?.runPrefetch()
      guard let self, self.prefetchGeneration == generation else { return }
      self.prefetchTask = nil
    }
  }

  func cancelPrefetch() {
    prefetchGeneration += 1
    prefetchTask?.cancel()
    prefetchTask = nil
  }

  /// Clears the failure marks and resumes the background queue.
  func retryFailedSentences() {
    failedSentenceIDs.removeAll()
    errorMessage = nil
    startPrefetch()
  }

  var hasFailedSentences: Bool {
    !failedSentenceIDs.isEmpty
  }

  var pendingSentenceCount: Int {
    sentences.filter { !$0.isAnalyzed }.count
  }

  var isAnalyzing: Bool {
    !analyzingSentenceIDs.isEmpty
  }

  private func runPrefetch() async {
    let articleID = selectedArticleID
    while !Task.isCancelled {
      // Re-read the pending list each round: the user may have expanded a sentence that
      // completed out of band, and the selection may have changed under us.
      guard selectedArticleID == articleID else { return }
      let pending = sentences.filter {
        !$0.isAnalyzed && !analyzingSentenceIDs.contains($0.id) && !failedSentenceIDs.contains($0.id)
      }
      guard !pending.isEmpty else {
        // Nothing to claim, but a sentence the reader expanded may still be in flight — wait
        // for it rather than declaring the article finished and stopping early.
        guard sentences.contains(where: { !$0.isAnalyzed && analyzingSentenceIDs.contains($0.id) }) else { return }
        try? await Task.sleep(for: .milliseconds(150))
        continue
      }

      let batch = Array(pending.prefix(Self.prefetchConcurrency))
      await withTaskGroup(of: Void.self) { group in
        for sentence in batch {
          // Nonisolated child closures that hop back onto the main actor inside `analyze`:
          // the awaits overlap (that's the point), the mutations don't.
          group.addTask { [weak self] in
            await self?.analyze(sentence)
          }
        }
      }
    }
  }

  private func analyze(_ sentence: ArticleSentence) async {
    guard !analyzingSentenceIDs.contains(sentence.id) else { return }
    analyzingSentenceIDs.insert(sentence.id)
    defer { analyzingSentenceIDs.remove(sentence.id) }

    do {
      let document = try await explanation(for: sentence)
      // Cancellation is the one exit that leaves the sentence pending without marking it
      // failed — the loop that would retry it has been torn down too. Every other failure
      // path below marks it, or the prefetch would pick the same sentence again forever.
      guard !Task.isCancelled else { return }
      let encoded = try JSONEncoder().encode(document)
      guard let json = String(data: encoded, encoding: .utf8) else {
        throw ArticleAnalysisError.undecodableDocument
      }
      try repository.saveAnalysis(sentenceID: sentence.id, analysisJSON: json, analyzedAt: Date())
      applyAnalysis(json: json, to: sentence.id)
      failedSentenceIDs.remove(sentence.id)
      errorMessage = nil
    } catch is CancellationError {
      return
    } catch {
      failedSentenceIDs.insert(sentence.id)
      errorMessage = LookupErrorPresenter.present(error).message
      articleLogger.error("Sentence analysis failed: \(String(describing: error), privacy: .public)")
    }
  }

  private func explanation(for sentence: ArticleSentence) async throws -> LearningExplanationDocument {
    if let analysisProvider {
      return try await analysisProvider(sentence.text)
    }

    let captured = CapturedText(
      originalText: sentence.text,
      cleanedText: sentence.text,
      mode: .sentence,
      sourceApp: selectedArticle?.sourceApp
    )
    let template = resolvedSentenceTemplate()
    let resolved = serviceFactory.make()
    let variant = ExplanationCacheVariant.make(
      preferences: settingsStore.loadLearningPreferences(),
      templateBody: template.body
    )

    // A sentence the user already looked up through the floating panel is free.
    if let cached = explanationCache.cached(
      text: sentence.text,
      mode: .sentence,
      model: resolved.configuration.model,
      variant: variant
    ) {
      return cached
    }

    // Only the first-screen analysis is requested here — the relationship diagram and key
    // vocabulary supplement would double the request count for a whole article.
    let document = try await resolved.service.explain(captured: captured, template: template)
    explanationCache.store(
      document,
      text: sentence.text,
      mode: .sentence,
      model: resolved.configuration.model,
      variant: variant
    )
    return document
  }

  private func resolvedSentenceTemplate() -> PromptTemplate {
    promptStore.template(for: .sentenceAnalysisSchema)
      ?? InMemoryPromptStore.defaults().template(for: .sentenceAnalysisSchema)
      ?? PromptTemplate(kind: .sentenceAnalysisSchema, body: "Return a single JSON object for {{text}}.")
  }

  /// Updates the in-memory sentence and the open article's progress counter without a full
  /// reload, so the reader doesn't flicker while the prefetch streams results in.
  private func applyAnalysis(json: String, to sentenceID: UUID) {
    guard let index = sentences.firstIndex(where: { $0.id == sentenceID }) else { return }
    sentences[index].analysisJSON = json
    sentences[index].analyzedAt = Date()
    guard let articleIndex = articles.firstIndex(where: { $0.id == selectedArticleID }) else { return }
    articles[articleIndex].analyzedCount = sentences.filter(\.isAnalyzed).count
  }

  // MARK: Retention

  /// Re-reads the retention window after the user changed it in Settings and applies it
  /// straight away, so shortening the window doesn't wait for the next launch.
  func applyStoredRetention() {
    retention = settingsStore.loadArticleRetention()
    sweepExpired()
    reloadArticles()
  }

  /// Deletes articles untouched for longer than the retention window, and drops cached model
  /// output of the same age so the cache doesn't outlive the material.
  func sweepExpired(now: Date = Date()) {
    guard let expiry = retention.expiryDate(now: now) else { return }
    do {
      let removed = try repository.deleteArticles(lastOpenedBefore: expiry)
      if removed > 0 {
        articleLogger.info("Swept \(removed, privacy: .public) expired article(s).")
      }
    } catch {
      articleLogger.error("Article retention sweep failed: \(String(describing: error), privacy: .public)")
    }
    explanationCache.purge(unusedSince: expiry)
  }

  // MARK: Loading

  private func reloadArticles() {
    articles = (try? repository.allArticles()) ?? []
    if let selectedArticleID, !articles.contains(where: { $0.id == selectedArticleID }) {
      self.selectedArticleID = nil
      sentences = []
    }
  }

  private func reloadSentences() {
    guard let selectedArticleID else {
      sentences = []
      return
    }
    sentences = (try? repository.sentences(articleID: selectedArticleID)) ?? []
  }
}
