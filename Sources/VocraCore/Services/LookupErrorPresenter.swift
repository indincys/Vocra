import Foundation

/// A suggested recovery action to surface next to an error message.
public enum LookupErrorRecovery: Equatable, Sendable {
  /// Open the app's settings (e.g. to enter a missing API key).
  case openSettings
  /// Open the system Accessibility privacy pane.
  case openAccessibilitySettings

  public var label: String {
    switch self {
    case .openSettings: "打开设置"
    case .openAccessibilitySettings: "打开辅助功能设置"
    }
  }
}

public struct LookupErrorPresentation: Equatable, Sendable {
  public let message: String
  public let recovery: LookupErrorRecovery?

  public init(message: String, recovery: LookupErrorRecovery?) {
    self.message = message
    self.recovery = recovery
  }
}

/// Maps the technical errors from the lookup pipeline to a plain-Chinese message and, where
/// useful, a one-tap recovery action — instead of dumping `String(describing:)` on screen.
public enum LookupErrorPresenter {
  public static func present(_ error: Error) -> LookupErrorPresentation {
    if let aiError = error as? AIClientError {
      return present(aiError)
    }
    if let selectionError = error as? SelectionReaderError {
      return present(selectionError)
    }
    if error is CancellationError {
      return LookupErrorPresentation(message: "已取消。", recovery: nil)
    }
    if let urlError = error as? URLError {
      return present(urlError)
    }
    return LookupErrorPresentation(message: "出错了：\(String(describing: error))", recovery: nil)
  }

  private static func present(_ error: AIClientError) -> LookupErrorPresentation {
    switch error {
    case .missingAPIKey:
      return LookupErrorPresentation(message: "尚未配置 API Key，请在设置中填写后再试。", recovery: .openSettings)
    case .httpStatus(let code):
      switch code {
      case 401, 403:
        return LookupErrorPresentation(message: "API Key 无效或没有权限（HTTP \(code)），请在设置中检查。", recovery: .openSettings)
      case 429:
        return LookupErrorPresentation(message: "请求过于频繁（HTTP 429），请稍后再试。", recovery: nil)
      case 500...599:
        return LookupErrorPresentation(message: "模型服务暂时不可用（HTTP \(code)），请稍后再试。", recovery: nil)
      default:
        return LookupErrorPresentation(message: "请求失败（HTTP \(code)），请检查设置或稍后再试。", recovery: .openSettings)
      }
    case .emptyContent:
      return LookupErrorPresentation(message: "模型没有返回内容，请重试。", recovery: nil)
    case .invalidResponse:
      return LookupErrorPresentation(message: "模型返回的内容无法解析，请重试。", recovery: nil)
    }
  }

  private static func present(_ error: SelectionReaderError) -> LookupErrorPresentation {
    switch error {
    case .accessibilityPermissionMissing:
      return LookupErrorPresentation(
        message: "Vocra 需要“辅助功能”权限才能读取选中的文本。请在系统设置中授权后重试。",
        recovery: .openAccessibilitySettings
      )
    case .emptySelection:
      return LookupErrorPresentation(message: "没有检测到选中的文本，请先选中内容再触发。", recovery: nil)
    }
  }

  private static func present(_ error: URLError) -> LookupErrorPresentation {
    switch error.code {
    case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost:
      return LookupErrorPresentation(message: "网络未连接，请检查网络后重试。", recovery: nil)
    case .timedOut:
      return LookupErrorPresentation(message: "请求超时，请稍后重试。", recovery: nil)
    default:
      return LookupErrorPresentation(message: "网络请求出错，请稍后重试。", recovery: nil)
    }
  }
}
