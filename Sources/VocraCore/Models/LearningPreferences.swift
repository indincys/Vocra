import Foundation

public struct LearningPreferences: Codable, Equatable, Sendable {
  public enum ExplanationDepth: String, Codable, CaseIterable, Sendable {
    case standard
    case detailed
  }

  public enum ChineseStyle: String, Codable, CaseIterable, Sendable {
    case concise
    case teacherLike
  }

  public enum DiagramDensity: String, Codable, CaseIterable, Sendable {
    case simple
    case full
  }

  public var explanationDepth: ExplanationDepth
  public var exampleCount: Int
  public var chineseStyle: ChineseStyle
  public var diagramDensity: DiagramDensity

  public init(
    explanationDepth: ExplanationDepth,
    exampleCount: Int,
    chineseStyle: ChineseStyle,
    diagramDensity: DiagramDensity
  ) {
    self.explanationDepth = explanationDepth
    self.exampleCount = exampleCount
    self.chineseStyle = chineseStyle
    self.diagramDensity = diagramDensity
  }

  public static let `default` = LearningPreferences(
    explanationDepth: .detailed,
    exampleCount: 2,
    chineseStyle: .teacherLike,
    diagramDensity: .full
  )
}
