import Foundation
import VocraCore

/// View-layer presentation helpers that decode a stored card's structured JSON
/// into the small strings the redesigned lists, cards, and dashboard show.
extension VocabularyCard {
  var decodedDocument: LearningExplanationDocument? {
    guard let data = cardJSON.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(LearningExplanationDocument.self, from: data)
  }

  /// Short Chinese gloss for list rows / recent lookups.
  var displayGloss: String {
    guard let document = decodedDocument else { return "" }
    if let meaning = document.wordExplanation?.coreMeaning, !meaning.isEmpty { return meaning }
    if let meaning = document.vocabularyCard?.back.coreMeaning, !meaning.isEmpty { return meaning }
    if let meaning = document.sentenceAnalysis?.translation.text, !meaning.isEmpty { return meaning }
    return ""
  }

  var displayPronunciation: String? {
    let value = decodedDocument?.wordExplanation?.pronunciation
    return (value?.isEmpty == false) ? value : nil
  }

  var displayPartOfSpeech: String {
    if let pos = decodedDocument?.wordExplanation?.partOfSpeech, !pos.isEmpty { return pos }
    return type == .word ? "词" : "词组"
  }

  /// 0…1 mastery used by the progress bar, derived from review status.
  var displayMastery: Double {
    switch status {
    case .mastered: 1.0
    case .familiar: 0.78
    case .learning: 0.45
    case .new: max(0.12, Double(familiarityLevel) * 0.1)
    }
  }

  var isDue: Bool {
    guard status != .mastered, let next = nextReviewAt else { return false }
    return next <= Date()
  }

  /// Source label such as a host app, falling back to a neutral tag.
  var displaySource: String {
    let trimmed = sourceApp?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? "Vocra" : trimmed
  }
}

/// Compact Chinese relative timestamp: 今天 · 14:32 / 昨天 · 19:41 / 3 天前.
func vocraRelativeTime(from date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "zh_CN")
  formatter.dateFormat = "HH:mm"

  if calendar.isDate(date, inSameDayAs: now) {
    return "今天 · \(formatter.string(from: date))"
  }
  if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
     calendar.isDate(date, inSameDayAs: yesterday) {
    return "昨天 · \(formatter.string(from: date))"
  }

  let startToday = calendar.startOfDay(for: now)
  let startDate = calendar.startOfDay(for: date)
  let days = calendar.dateComponents([.day], from: startDate, to: startToday).day ?? 0
  if days > 0, days < 30 { return "\(days) 天前" }

  formatter.dateFormat = "M月d日"
  return formatter.string(from: date)
}
