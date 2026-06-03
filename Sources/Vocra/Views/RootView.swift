import SwiftUI
import VocraCore

struct RootView: View {
  let appModel: AppModel
  @State private var section: VocraSection = .today
  @State private var inspectedCard: VocabularyCard?

  var body: some View {
    let cards = appModel.allVocabularyCards
    let metrics = appModel.dashboardMetrics

    HStack(spacing: 0) {
      sidebar(metrics: metrics)
        .frame(width: 212)
        .background(VisualEffectBlur(material: .sidebar))
        .overlay(alignment: .trailing) {
          Rectangle().fill(VocraTheme.hairline).frame(width: 1)
        }

      content(cards: cards, metrics: metrics)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .vocraWindowBackground()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea()
    .environment(\.colorScheme, .light)
    .preferredColorScheme(.light)
    .tint(VocraTheme.accent)
    .sheet(item: $inspectedCard) { card in
      CardDetailSheet(card: card)
    }
  }

  // MARK: Sidebar

  private func sidebar(metrics: DashboardMetrics) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 9) {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(LinearGradient(colors: [VocraTheme.accent, VocraTheme.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
          .frame(width: 28, height: 28)
          .overlay {
            Image(systemName: "square.stack.3d.up.fill")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(.white)
          }
          .shadow(color: VocraTheme.accent.opacity(0.45), radius: 4, y: 2)
        Text("Vocra")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(VocraTheme.ink900)
      }
      .padding(.top, 30)
      .padding(.horizontal, 18)
      .padding(.bottom, 18)

      VStack(spacing: 3) {
        ForEach(VocraSection.allCases) { item in
          SidebarNavButton(
            section: item,
            isSelected: section == item,
            badge: item == .review ? metrics.dueToday : nil
          ) {
            section = item
          }
        }
      }
      .padding(.horizontal, 10)

      Spacer()

      streakWidget(metrics: metrics)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func streakWidget(metrics: DashboardMetrics) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 7) {
        Image(systemName: "flame.fill")
          .font(.system(size: 16))
          .foregroundStyle(VocraTheme.flame)
        Text("\(metrics.streak)")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(VocraTheme.ink900)
        Text("天连续")
          .font(.system(size: 12.5))
          .foregroundStyle(VocraTheme.ink500)
      }
      HStack(spacing: 3) {
        ForEach(Array(metrics.weekLookups.enumerated()), id: \.offset) { _, value in
          Capsule()
            .fill(value > 0 ? VocraTheme.flame : VocraTheme.fillStrong)
            .frame(height: 5)
        }
      }
    }
    .padding(.horizontal, 13)
    .padding(.vertical, 11)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(VocraTheme.hairline, lineWidth: 1)
    }
  }

  // MARK: Content

  @ViewBuilder
  private func content(cards: [VocabularyCard], metrics: DashboardMetrics) -> some View {
    switch section {
    case .today:
      TodayView(
        metrics: metrics,
        recent: Array(cards.prefix(5)),
        onStartReview: { section = .review },
        onOpen: { inspectedCard = $0 }
      )
    case .vocabulary:
      VocabularyListView(cards: cards, onOpen: { inspectedCard = $0 })
    case .review:
      ReviewView(cards: appModel.dueCards()) { cardID, rating in
        appModel.applyReview(cardID: cardID, rating: rating)
      }
      .padding(.horizontal, 30)
      .padding(.vertical, 24)
    case .settings:
      SettingsView()
    }
  }
}

enum VocraSection: String, CaseIterable, Identifiable {
  case today
  case vocabulary
  case review
  case settings

  var id: Self { self }

  var title: String {
    switch self {
    case .today: "今天"
    case .vocabulary: "生词本"
    case .review: "复习"
    case .settings: "设置"
    }
  }

  var systemImage: String {
    switch self {
    case .today: "house"
    case .vocabulary: "book"
    case .review: "rectangle.stack"
    case .settings: "gearshape"
    }
  }
}

private struct SidebarNavButton: View {
  let section: VocraSection
  let isSelected: Bool
  let badge: Int?
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: section.systemImage)
          .font(.system(size: 15, weight: .medium))
          .frame(width: 20)
        Text(section.title)
          .font(.system(size: 14, weight: .medium))
        Spacer(minLength: 0)
        if let badge, badge > 0 {
          Text("\(badge)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(isSelected ? Color.white.opacity(0.28) : VocraTheme.accent, in: Capsule())
        }
      }
      .foregroundStyle(isSelected ? Color.white : VocraTheme.ink700)
      .padding(.horizontal, 11)
      .padding(.vertical, 8)
      .background {
        if isSelected {
          RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(VocraTheme.accent)
            .shadow(color: VocraTheme.accent.opacity(0.45), radius: 4, y: 2)
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
