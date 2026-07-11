import SwiftUI
import VocraCore

struct TodayView: View {
  let metrics: DashboardMetrics
  let recent: [VocabularyCard]
  let onStartReview: () -> Void
  let onOpen: (VocabularyCard) -> Void

  private var greeting: String {
    switch Calendar.current.component(.hour, from: Date()) {
    case ..<6: "凌晨好"
    case ..<12: "早上好"
    case ..<18: "下午好"
    default: "晚上好"
    }
  }

  private var dateText: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "M月d日 EEEE"
    return formatter.string(from: Date())
  }

  private var estimatedMinutes: Int {
    max(1, Int(ceil(Double(metrics.dueToday) * 0.75)))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text(dateText)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(VocraTheme.ink400)
          Text("\(greeting)，继续学习")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(VocraTheme.ink900)
        }
        .padding(.bottom, 6)

        heroCard
        statTiles

        VStack(alignment: .leading, spacing: 10) {
          HStack(spacing: 7) {
            Image(systemName: "clock")
              .font(.system(size: 13))
              .foregroundStyle(VocraTheme.ink400)
            Text("最近查词")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(VocraTheme.ink700)
          }
          .padding(.top, 10)

          if recent.isEmpty {
            emptyRecent
          } else {
            VStack(spacing: 2) {
              ForEach(recent) { card in
                RecentLookupRow(card: card) { onOpen(card) }
              }
            }
          }
        }
      }
      .padding(.horizontal, 34)
      .padding(.vertical, 30)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .scrollContentBackground(.hidden)
  }

  private var heroCard: some View {
    HStack(spacing: 20) {
      VStack(alignment: .leading, spacing: 0) {
        Text("今日待复习")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(VocraTheme.accentInk)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text("\(metrics.dueToday)")
            .font(.system(size: 44, weight: .bold))
            .foregroundStyle(VocraTheme.ink900)
          Text(metrics.dueToday > 0 ? "张卡片 · 约 \(estimatedMinutes) 分钟" : "今天都复习完啦 🎉")
            .font(.system(size: 15))
            .foregroundStyle(VocraTheme.ink500)
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
        if metrics.newToday > 0 {
          Text("另有 \(metrics.newToday) 个今日新词等待首次记忆")
            .font(.system(size: 13.5))
            .foregroundStyle(VocraTheme.ink500)
        }
      }
      Spacer(minLength: 0)
      Button(action: onStartReview) {
        Label("开始复习", systemImage: "rectangle.stack")
          .font(.system(size: 15, weight: .semibold))
      }
      .buttonStyle(VocraAccentButtonStyle())
      .disabled(metrics.dueToday == 0)
      .opacity(metrics.dueToday == 0 ? 0.5 : 1)
    }
    .padding(22)
    .background {
      let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
      ZStack {
        shape.fill(.regularMaterial)
        shape.fill(LinearGradient(
          colors: [Color(oklch: 0.62, 0.17, 255, opacity: 0.20), Color(oklch: 0.62, 0.15, 305, opacity: 0.15)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ))
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(VocraTheme.glassStroke, lineWidth: 1)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(VocraTheme.hairline, lineWidth: 1)
    }
  }

  private var statTiles: some View {
    HStack(spacing: 14) {
      StatTile(icon: "flame", label: "连续学习") {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
          Text("\(metrics.streak)").font(.system(size: 30, weight: .bold)).foregroundStyle(VocraTheme.ink900)
          Text("天").font(.system(size: 14)).foregroundStyle(VocraTheme.ink500)
        }
      }
      StatTile(icon: "magnifyingglass", label: "本周查词") {
        HStack(alignment: .bottom) {
          Text("\(metrics.weekLookupTotal)").font(.system(size: 30, weight: .bold)).foregroundStyle(VocraTheme.ink900)
          Spacer(minLength: 6)
          Sparkline(data: metrics.weekLookups.map(Double.init))
        }
      }
      StatTile(icon: "square.3.layers.3d", label: "已掌握 / 总量") {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
          Text("\(metrics.mastered)").font(.system(size: 30, weight: .bold)).foregroundStyle(VocraTheme.ink900)
          Text("/ \(metrics.totalWords)").font(.system(size: 14)).foregroundStyle(VocraTheme.ink500)
        }
      }
    }
  }

  private var emptyRecent: some View {
    HStack(spacing: 12) {
      Image(systemName: "sparkles")
        .font(.system(size: 18))
        .foregroundStyle(VocraTheme.accent)
      VStack(alignment: .leading, spacing: 3) {
        Text("还没有查词记录")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(VocraTheme.ink900)
        Text("在任意 App 中选中英文，按下全局快捷键即可查词与解析。")
          .font(.system(size: 12.5))
          .foregroundStyle(VocraTheme.ink500)
      }
      Spacer(minLength: 0)
    }
    .padding(16)
    .vocraCard(cornerRadius: 14, padding: nil)
  }
}

private struct StatTile<Content: View>: View {
  let icon: String
  let label: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 12))
          .foregroundStyle(VocraTheme.accent)
        Text(label)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(VocraTheme.ink500)
      }
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .vocraCard(cornerRadius: 14, padding: nil)
  }
}

private struct RecentLookupRow: View {
  let card: VocabularyCard
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Text(card.text)
          .font(.system(size: 15.5, weight: .semibold))
          .foregroundStyle(VocraTheme.ink900)
          .lineLimit(1)
          .frame(minWidth: 110, alignment: .leading)
        Text(card.displayGloss)
          .font(.system(size: 14))
          .foregroundStyle(VocraTheme.ink500)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
        VocraChip(text: card.displaySource)
        Text(vocraRelativeTime(from: card.createdAt))
          .font(.system(size: 12))
          .foregroundStyle(VocraTheme.ink400)
          .frame(minWidth: 64, alignment: .trailing)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(hovering ? VocraTheme.fill : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

/// Accent pill button matching `.btn-accent` (gradient fill, white label).
struct VocraAccentButtonStyle: ButtonStyle {
  var horizontalPadding: CGFloat = 22
  var verticalPadding: CGFloat = 11

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.white)
      .padding(.horizontal, horizontalPadding)
      .padding(.vertical, verticalPadding)
      .background(
        LinearGradient(colors: [VocraTheme.accent, VocraTheme.accentStrong], startPoint: .top, endPoint: .bottom),
        in: Capsule(style: .continuous)
      )
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
