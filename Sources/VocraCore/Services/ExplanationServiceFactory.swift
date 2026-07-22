import Foundation

/// Assembles a `StructuredExplanationService` for the currently-active API profile.
///
/// Resolving the profile, its per-profile key account, and the learning preferences has to
/// happen per call (the user can switch providers mid-session), so this exists as a small
/// factory shared by every caller that needs the model — the lookup flow and the article
/// reader alike — instead of being duplicated in each.
public struct ExplanationServiceFactory: Sendable {
  private let settingsStore: any SettingsStore
  private let fallbackKeyStore: any APIKeyStore

  public init(
    settingsStore: any SettingsStore = UserDefaultsSettingsStore(),
    fallbackKeyStore: any APIKeyStore = FileAPIKeyStore()
  ) {
    self.settingsStore = settingsStore
    self.fallbackKeyStore = fallbackKeyStore
  }

  public func make() -> (service: StructuredExplanationService, configuration: APIConfiguration) {
    let activeProfile = settingsStore.loadAPIProviderSettings().activeProfile
    let configuration = activeProfile?.configuration ?? settingsStore.loadAPIConfiguration()
    let apiKeyStore: any APIKeyStore = activeProfile
      .map { FileAPIKeyStore(account: $0.secretAccount) } ?? fallbackKeyStore
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
}
