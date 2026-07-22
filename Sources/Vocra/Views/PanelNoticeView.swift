import SwiftUI

/// Transient bottom-right confirmation, sized and styled like the lookup HUD so collecting
/// an article feels like the same family of feedback as looking a word up.
struct PanelNoticeView: View {
  let notice: PanelNotice

  var body: some View {
    HStack(spacing: 11) {
      Image(systemName: notice.symbolName)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(VocraTheme.accent)
      VStack(alignment: .leading, spacing: 2) {
        Text(notice.title)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(VocraTheme.ink900)
        Text(notice.subtitle)
          .font(.system(size: 11.5))
          .foregroundStyle(VocraTheme.ink500)
          .lineLimit(2)
          .truncationMode(.middle)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 15)
    .padding(.vertical, 12)
    .frame(width: PanelNoticeView.size.width, height: PanelNoticeView.size.height, alignment: .leading)
    .vocraFloatingGlass(cornerRadius: 16)
  }

  static let size = CGSize(width: 320, height: 66)
}
