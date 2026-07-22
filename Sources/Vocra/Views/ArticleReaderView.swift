import SwiftUI
import VocraCore

/// The reading area: collected articles on the left, the selected one rendered sentence by
/// sentence on the right.
///
/// Every sentence carries its grammar colors inline while reading; clicking one expands the
/// full breakdown *directly beneath it* rather than pushing the reader into a separate
/// detail view, so the surrounding context never leaves the screen.
struct ArticleReaderView: View {
  let library: ArticleLibraryModel
  let collectShortcutDisplay: String
  var onSaveVocabulary: VocabularySaveAction? = nil

  var body: some View {
    HStack(spacing: 0) {
      articleList
        .frame(width: 248)
        .overlay(alignment: .trailing) {
          Rectangle().fill(VocraTheme.hairline).frame(width: 1)
        }

      if library.selectedArticle == nil {
        placeholder
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        reader
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  // MARK: Article list

  private var articleList: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Text("阅读")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(VocraTheme.ink900)
        Text("\(library.articles.count)")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(VocraTheme.ink400)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .padding(.top, 24)
      .padding(.bottom, 12)

      if library.articles.isEmpty {
        Text("按 \(collectShortcutDisplay) 收录选中的段落")
          .font(.system(size: 12))
          .foregroundStyle(VocraTheme.ink400)
          .padding(.horizontal, 16)
        Spacer()
      } else {
        ScrollView {
          LazyVStack(spacing: 4) {
            ForEach(library.articles) { article in
              ArticleListRow(
                article: article,
                isSelected: article.id == library.selectedArticleID,
                onOpen: { library.select(articleID: article.id) },
                onDelete: { library.delete(articleID: article.id) }
              )
            }
          }
          .padding(.horizontal, 10)
          .padding(.bottom, 18)
        }
        .scrollContentBackground(.hidden)
      }

      retentionFooter
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }

  private var retentionFooter: some View {
    HStack(spacing: 6) {
      Image(systemName: "clock.arrow.circlepath")
        .font(.system(size: 11))
        .foregroundStyle(VocraTheme.ink400)
      Text(library.retention.keepsForever ? "收录内容永久保留" : "\(library.retention.days) 天未打开自动清除")
        .font(.system(size: 11))
        .foregroundStyle(VocraTheme.ink400)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 11)
    .overlay(alignment: .top) { Rectangle().fill(VocraTheme.hairline).frame(height: 1) }
  }

  // MARK: Placeholder

  private var placeholder: some View {
    VStack(spacing: 12) {
      Image(systemName: "text.book.closed")
        .font(.system(size: 34))
        .foregroundStyle(VocraTheme.ink300)
      Text("还没有打开的文章")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(VocraTheme.ink700)
      Text("在任意 App 中选中一段文字，按 \(collectShortcutDisplay) 收录进来，\n之后可以逐句查看结构、语法和重点词汇。")
        .font(.system(size: 12.5))
        .multilineTextAlignment(.center)
        .foregroundStyle(VocraTheme.ink400)
        .lineSpacing(3)
    }
    .padding(30)
  }

  // MARK: Reader

  @ViewBuilder
  private var reader: some View {
    if let article = library.selectedArticle {
      VStack(spacing: 0) {
        readerHeader(article: article)
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(paragraphs, id: \.index) { paragraph in
              VStack(alignment: .leading, spacing: 6) {
                ForEach(paragraph.sentences) { sentence in
                  ArticleSentenceRow(
                    sentence: sentence,
                    isAnalyzing: library.analyzingSentenceIDs.contains(sentence.id),
                    onRequestAnalysis: { library.analyzeNow(sentenceID: sentence.id) },
                    onSaveVocabulary: onSaveVocabulary
                  )
                }
              }
            }
          }
          .padding(.horizontal, 28)
          .padding(.vertical, 20)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
      }
    }
  }

  private func readerHeader(article: Article) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(article.title)
          .font(.system(size: 19, weight: .bold))
          .foregroundStyle(VocraTheme.ink900)
          .lineLimit(2)
        Spacer(minLength: 8)
        analysisStatus(article: article)
      }
      HStack(spacing: 10) {
        metaChip(systemImage: "text.alignleft", text: "\(article.sentenceCount) 句")
        metaChip(systemImage: "character.book.closed", text: "\(article.wordCount) 词")
        if let sourceApp = article.sourceApp {
          metaChip(systemImage: "app", text: sourceApp)
        }
        metaChip(systemImage: "calendar", text: article.createdAt.formatted(date: .abbreviated, time: .shortened))
        Spacer(minLength: 0)
      }
      RoleLegend()
    }
    .padding(.horizontal, 28)
    .padding(.top, 24)
    .padding(.bottom, 14)
    .overlay(alignment: .bottom) { Rectangle().fill(VocraTheme.hairline).frame(height: 1) }
  }

  @ViewBuilder
  private func analysisStatus(article: Article) -> some View {
    HStack(spacing: 9) {
      if library.isAnalyzing {
        ProgressView().controlSize(.small)
      }
      Text("已解析 \(article.analyzedCount)/\(article.sentenceCount)")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(VocraTheme.ink500)
      if library.hasFailedSentences {
        Button("重试") { library.retryFailedSentences() }
          .buttonStyle(VocraGhostButtonStyle(tint: VocraTheme.rolePredicateInk))
      } else if library.pendingSentenceCount > 0, !library.isAnalyzing {
        Button("继续解析") { library.startPrefetch() }
          .buttonStyle(VocraGhostButtonStyle())
      }
    }
  }

  private func metaChip(systemImage: String, text: String) -> some View {
    HStack(spacing: 4) {
      Image(systemName: systemImage).font(.system(size: 10))
      Text(text).font(.system(size: 11.5))
    }
    .foregroundStyle(VocraTheme.ink400)
  }

  /// Regroups the flat sentence list back into the paragraphs it was captured in.
  private var paragraphs: [(index: Int, sentences: [ArticleSentence])] {
    var grouped: [(index: Int, sentences: [ArticleSentence])] = []
    for sentence in library.sentences {
      if grouped.last?.index == sentence.paragraphIndex {
        grouped[grouped.count - 1].sentences.append(sentence)
      } else {
        grouped.append((sentence.paragraphIndex, [sentence]))
      }
    }
    return grouped
  }
}

// MARK: - Article list row

private struct ArticleListRow: View {
  let article: Article
  let isSelected: Bool
  let onOpen: () -> Void
  let onDelete: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: onOpen) {
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) {
          Text(article.title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : VocraTheme.ink900)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
          Spacer(minLength: 0)
          if hovering {
            Button(action: onDelete) {
              Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? Color.white.opacity(0.8) : VocraTheme.ink400)
            }
            .buttonStyle(.plain)
            .help("删除这篇文章")
          }
        }
        HStack(spacing: 6) {
          Text("\(article.analyzedCount)/\(article.sentenceCount) 句")
            .font(.system(size: 11))
            .foregroundStyle(isSelected ? Color.white.opacity(0.85) : VocraTheme.ink400)
          if article.isFullyAnalyzed {
            Image(systemName: "checkmark.seal.fill")
              .font(.system(size: 10))
              .foregroundStyle(isSelected ? Color.white.opacity(0.85) : VocraTheme.roleObjectInk)
          }
          Spacer(minLength: 0)
        }
      }
      .padding(.horizontal, 11)
      .padding(.vertical, 9)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        if isSelected {
          RoundedRectangle(cornerRadius: 9, style: .continuous).fill(VocraTheme.accent)
        } else if hovering {
          RoundedRectangle(cornerRadius: 9, style: .continuous).fill(VocraTheme.fill)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

// MARK: - Sentence row

/// One sentence in the reader. Collapsed it shows the color-coded text; expanded it grows a
/// full breakdown card immediately below itself.
private struct ArticleSentenceRow: View {
  let sentence: ArticleSentence
  let isAnalyzing: Bool
  let onRequestAnalysis: () -> Void
  var onSaveVocabulary: VocabularySaveAction?

  @State private var isExpanded = false
  @State private var hovering = false

  private var analysis: SentenceAnalysis? { sentence.analysis }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        isExpanded.toggle()
        if isExpanded, analysis == nil, !isAnalyzing {
          onRequestAnalysis()
        }
      } label: {
        HStack(alignment: .top, spacing: 10) {
          statusMark
          sentenceBody
          Spacer(minLength: 0)
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(VocraTheme.ink300)
            .opacity(hovering || isExpanded ? 1 : 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
          if isExpanded {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VocraTheme.accentSoft.opacity(0.55))
          } else if hovering {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VocraTheme.fill)
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .onHover { hovering = $0 }

      if isExpanded {
        expandedDetail
          .padding(.leading, 26)
          .padding(.top, 6)
          .padding(.bottom, 8)
      }
    }
  }

  /// A dot whose color tells the sentence's analysis state at a glance.
  private var statusMark: some View {
    Circle()
      .fill(analysis != nil ? VocraTheme.roleObject : (isAnalyzing ? VocraTheme.accent : VocraTheme.ink300))
      .frame(width: 6, height: 6)
      .padding(.top, 8)
      .opacity(isAnalyzing ? 0.6 : 1)
  }

  @ViewBuilder
  private var sentenceBody: some View {
    if let analysis, !analysis.sentence.segments.isEmpty {
      ColorCodedSentence(text: displayText(analysis), segments: analysis.sentence.segments)
    } else {
      Text(sentence.text)
        .font(.system(size: 15))
        .foregroundStyle(VocraTheme.ink900)
        .lineSpacing(5)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// The analysis echoes the sentence it was built from; fall back to the stored text when
  /// the model left it blank.
  private func displayText(_ analysis: SentenceAnalysis) -> String {
    let text = analysis.sentence.text.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? sentence.text : text
  }

  @ViewBuilder
  private var expandedDetail: some View {
    if let analysis {
      SentenceLearningView(analysis: analysis, onSaveVocabulary: onSaveVocabulary)
        .vocraCard(cornerRadius: 14, padding: nil)
    } else if isAnalyzing {
      HStack(spacing: 9) {
        ProgressView().controlSize(.small)
        Text("正在解析这句…")
          .font(.system(size: 12.5))
          .foregroundStyle(VocraTheme.ink500)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .vocraCard(cornerRadius: 14, padding: nil)
    } else {
      Button("解析这句") { onRequestAnalysis() }
        .buttonStyle(VocraGhostButtonStyle())
    }
  }
}

// MARK: - Color-coded sentence

/// The sentence at reading altitude: every labeled span keeps its role color as an underline,
/// but the role labels stay folded away (they live in the expanded breakdown) so a paragraph
/// still reads like a paragraph.
private struct ColorCodedSentence: View {
  let text: String
  let segments: [SentenceSegment]

  private var pieces: [SentenceDisplayPiece] {
    sentenceDisplayPieces(text: text, segments: segments)
  }

  var body: some View {
    FlowLayout(spacing: 4, rowSpacing: 6) {
      ForEach(pieces) { piece in
        switch piece.kind {
        case .plain:
          Text(piece.text)
            .font(.system(size: 15))
            .foregroundStyle(VocraTheme.ink900)
            .fixedSize()
        case let .role(segment):
          Text(piece.text)
            .font(.system(size: 15))
            .foregroundStyle(VocraTheme.ink900)
            .fixedSize()
            .padding(.bottom, 3)
            .overlay(alignment: .bottom) {
              RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(segment.color.vocraColor)
                .frame(height: 2.5)
            }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Maps the underline colors back to the grammatical roles they stand for.
private struct RoleLegend: View {
  private static let entries: [(LearningColorToken, String)] = [
    (.blue, "主语"),
    (.green, "谓语 / 宾语"),
    (.orange, "状语 / 连词"),
    (.purple, "从句"),
    (.pink, "转折")
  ]

  var body: some View {
    HStack(spacing: 12) {
      ForEach(Array(Self.entries.enumerated()), id: \.offset) { _, entry in
        HStack(spacing: 5) {
          RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(entry.0.vocraColor)
            .frame(width: 14, height: 2.5)
          Text(entry.1)
            .font(.system(size: 10.5))
            .foregroundStyle(VocraTheme.ink400)
        }
      }
      Spacer(minLength: 0)
    }
  }
}
