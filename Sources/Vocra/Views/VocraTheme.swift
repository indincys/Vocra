import AppKit
import AVFoundation
import Foundation
import SwiftUI
import VocraCore

// MARK: - oklch color tokens

extension Color {
  /// A color that resolves to `light` or `dark` based on the viewer's system appearance,
  /// so a single token adapts across light and dark mode.
  static func vocraDynamic(_ light: Color, _ dark: Color) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
    })
  }

  /// Faithful reproduction of a CSS `oklch(L C H / opacity)` design token.
  ///
  /// The Vocra design system (assets/theme.css) expresses every color in
  /// `oklch`, so the cleanest way to stay pixel-faithful is to convert at the
  /// source rather than hand-baking hex approximations.
  init(oklch lightness: Double, _ chroma: Double, _ hue: Double, opacity: Double = 1) {
    let hueRadians = hue * .pi / 180
    let a = chroma * cos(hueRadians)
    let b = chroma * sin(hueRadians)

    // oklab -> non-linear LMS
    let lDash = lightness + 0.3963377774 * a + 0.2158037573 * b
    let mDash = lightness - 0.1055613458 * a - 0.0638541728 * b
    let sDash = lightness - 0.0894841775 * a - 1.2914855480 * b
    let l = lDash * lDash * lDash
    let m = mDash * mDash * mDash
    let s = sDash * sDash * sDash

    // LMS -> linear sRGB
    let red = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    let green = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    let blue = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    func encode(_ channel: Double) -> Double {
      let clamped = min(max(channel, 0), 1)
      return clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }

    self.init(.sRGB, red: encode(red), green: encode(green), blue: encode(blue), opacity: opacity)
  }
}

// MARK: - Design tokens

enum VocraTheme {
  /// Builds a light/dark token pair from two oklch specs.
  private static func dyn(
    _ light: (Double, Double, Double),
    _ dark: (Double, Double, Double),
    opacity: Double = 1
  ) -> Color {
    Color.vocraDynamic(
      Color(oklch: light.0, light.1, light.2, opacity: opacity),
      Color(oklch: dark.0, dark.1, dark.2, opacity: opacity)
    )
  }

  // Neutral base — near-white in light, deep cool charcoal in dark.
  static let bg0 = dyn((0.98, 0.004, 250), (0.175, 0.008, 260))
  static let bg1 = dyn((0.965, 0.005, 250), (0.205, 0.008, 260))
  // Ink scale flips: dark text on light → light text on dark.
  static let ink900 = dyn((0.22, 0.012, 260), (0.96, 0.006, 260))
  static let ink700 = dyn((0.36, 0.012, 260), (0.84, 0.008, 260))
  static let ink500 = dyn((0.52, 0.012, 260), (0.70, 0.010, 260))
  static let ink400 = dyn((0.62, 0.010, 260), (0.60, 0.010, 260))
  static let ink300 = dyn((0.74, 0.008, 260), (0.48, 0.010, 260))
  static let hairline = dyn((0.55, 0.01, 260), (0.80, 0.01, 260), opacity: 0.16)
  static let fill = dyn((0.62, 0.02, 255), (0.72, 0.02, 255), opacity: 0.13)
  static let fillStrong = dyn((0.62, 0.02, 255), (0.72, 0.02, 255), opacity: 0.20)

  // Accent (system blue) — nudged brighter in dark for contrast.
  static let accent = dyn((0.62, 0.17, 255), (0.68, 0.17, 255))
  static let accentStrong = dyn((0.55, 0.19, 255), (0.64, 0.19, 255))
  static let accentSoft = dyn((0.62, 0.17, 255), (0.70, 0.17, 255), opacity: 0.16)
  static let accentInk = dyn((0.46, 0.16, 255), (0.76, 0.15, 255))
  static let violet = dyn((0.60, 0.16, 305), (0.70, 0.16, 305))
  static let flame = dyn((0.63, 0.18, 40), (0.70, 0.18, 40))

  // Sentence-role palette — light & lively (L≈0.70-0.80). Legible on both surfaces.
  static let roleSubject = Color(oklch: 0.71, 0.14, 248)
  static let rolePredicate = Color(oklch: 0.72, 0.15, 22)
  static let roleObject = Color(oklch: 0.74, 0.14, 165)
  static let roleAdverbial = Color(oklch: 0.80, 0.13, 82)
  static let roleClause = Color(oklch: 0.72, 0.15, 300)
  static let roleConnector = Color(oklch: 0.70, 0.04, 260)
  static let roleTransition = Color(oklch: 0.71, 0.17, 350)

  // Deeper ink variants for text labels — darkened on light, lightened on dark.
  static let roleSubjectInk = dyn((0.48, 0.15, 248), (0.76, 0.13, 248))
  static let rolePredicateInk = dyn((0.50, 0.16, 22), (0.76, 0.15, 22))
  static let roleObjectInk = dyn((0.47, 0.14, 165), (0.75, 0.13, 165))
  static let roleAdverbialInk = dyn((0.50, 0.13, 75), (0.80, 0.13, 82))
  static let roleClauseInk = dyn((0.49, 0.16, 300), (0.76, 0.15, 300))
  static let roleConnectorInk = dyn((0.46, 0.04, 260), (0.74, 0.04, 260))
  static let roleTransitionInk = dyn((0.50, 0.18, 350), (0.77, 0.16, 350))

  // Glass wash / stroke / elevated-thumb surfaces — bright whites on light, muted on dark.
  static let glassHighlight = Color.vocraDynamic(.white.opacity(0.35), .white.opacity(0.06))
  static let glassWash = Color.vocraDynamic(.white.opacity(0.18), .white.opacity(0.04))
  static let glassStroke = Color.vocraDynamic(.white.opacity(0.55), .white.opacity(0.10))
  static let elevatedSurface = Color.vocraDynamic(.white, Color(oklch: 0.34, 0.01, 260))

  static let shadow = Color(red: 20 / 255, green: 22 / 255, blue: 40 / 255)

  /// Hue-driven accent for the CEFR-like / mastery / rating scales used across
  /// the design (oklch L≈0.6 C≈0.14, ink at L≈0.46).
  static func hued(_ hue: Double, lightness: Double = 0.60, chroma: Double = 0.14, opacity: Double = 1) -> Color {
    Color(oklch: lightness, chroma, hue, opacity: opacity)
  }
}

extension LearningColorToken {
  /// Lively underline / token color (the refreshed sentence-role palette).
  var vocraColor: Color {
    switch self {
    case .blue: VocraTheme.roleSubject
    case .green: VocraTheme.roleObject
    case .orange: VocraTheme.roleAdverbial
    case .purple: VocraTheme.roleClause
    case .pink: VocraTheme.roleTransition
    case .neutral: VocraTheme.roleConnector
    }
  }

  /// Deeper ink variant for legible text labels on light surfaces.
  var vocraInk: Color {
    switch self {
    case .blue: VocraTheme.roleSubjectInk
    case .green: VocraTheme.roleObjectInk
    case .orange: VocraTheme.roleAdverbialInk
    case .purple: VocraTheme.roleClauseInk
    case .pink: VocraTheme.roleTransitionInk
    case .neutral: VocraTheme.roleConnectorInk
    }
  }
}

// MARK: - Surfaces

extension View {
  /// In-window card: a bright translucent-white panel with a hairline edge and
  /// soft lift, optionally tinted with an accent wash.
  func vocraCard(cornerRadius: CGFloat = 16, tint: Color? = nil, padding: CGFloat? = 14) -> some View {
    modifier(VocraCardModifier(cornerRadius: cornerRadius, tint: tint, padding: padding))
  }

  /// Floating glass shell for popovers / panels presented over the desktop.
  func vocraGlassPanel(cornerRadius: CGFloat = 22) -> some View {
    modifier(VocraGlassPanelModifier(cornerRadius: cornerRadius))
  }
}

private struct VocraCardModifier: ViewModifier {
  let cornerRadius: CGFloat
  let tint: Color?
  let padding: CGFloat?

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    return content
      .padding(padding.map { EdgeInsets(top: $0, leading: $0, bottom: $0, trailing: $0) } ?? EdgeInsets())
      .background {
        ZStack {
          shape.fill(.regularMaterial)
          shape.fill(VocraTheme.glassWash)
          if let tint {
            shape.fill(tint)
          }
          shape.fill(
            LinearGradient(
              colors: [VocraTheme.glassHighlight, Color.white.opacity(0.02)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .blendMode(.softLight)
        }
      }
      .overlay {
        shape.strokeBorder(VocraTheme.glassStroke, lineWidth: 1)
      }
      .overlay {
        shape.strokeBorder(VocraTheme.hairline, lineWidth: 1)
      }
  }
}

private struct VocraGlassPanelModifier: ViewModifier {
  let cornerRadius: CGFloat

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    return content
      .background {
        shape.fill(.ultraThinMaterial)
        shape.fill(VocraTheme.glassWash)
        shape.fill(
          LinearGradient(
            colors: [VocraTheme.glassHighlight, Color.white.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottom
          )
        )
        .blendMode(.softLight)
      }
      .overlay {
        shape.strokeBorder(VocraTheme.glassStroke, lineWidth: 1)
      }
      .clipShape(shape)
  }
}

// MARK: - Atoms

/// Section heading: accent glyph + bold caption + optional hint.
struct VocraSectionLabel: View {
  let systemImage: String
  let title: String
  var hint: String?

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: systemImage)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(VocraTheme.accent)
      Text(title)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(VocraTheme.ink500)
        .tracking(0.2)
      if let hint {
        Text("· \(hint)")
          .font(.system(size: 11))
          .foregroundStyle(VocraTheme.ink400)
      }
    }
  }
}

/// Pill chip used for tags, parts of speech, sources, etc.
struct VocraChip: View {
  let text: String
  var dot: Color?
  var tint: Color?
  var monospaced = false

  var body: some View {
    HStack(spacing: 5) {
      if let dot {
        Circle().fill(dot).frame(width: 7, height: 7)
      }
      Text(text)
        .font(.system(size: 11.5, weight: .medium, design: monospaced ? .monospaced : .default))
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .foregroundStyle(tint ?? VocraTheme.ink700)
    .padding(.horizontal, 9)
    .padding(.vertical, 3)
    .background(
      (tint?.opacity(0.14) ?? VocraTheme.fill),
      in: Capsule(style: .continuous)
    )
  }
}

/// Monospace key-cap, e.g. ⌃ ⌘ D.
struct KbdKey: View {
  let label: String
  var large = false

  init(_ label: String, large: Bool = false) {
    self.label = label
    self.large = large
  }

  var body: some View {
    Text(label)
      .font(.system(size: large ? 14 : 11, weight: large ? .semibold : .medium, design: .monospaced))
      .foregroundStyle(large ? VocraTheme.ink700 : VocraTheme.ink400)
      .frame(minWidth: large ? 30 : nil)
      .padding(.horizontal, large ? 9 : 7)
      .padding(.vertical, large ? 5 : 4)
      .background(VocraTheme.fill, in: RoundedRectangle(cornerRadius: large ? 8 : 7, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: large ? 8 : 7, style: .continuous)
          .strokeBorder(VocraTheme.hairline, lineWidth: 1)
      }
  }
}

/// Thin mastery progress bar with a hue that warms from amber → mint with skill.
struct MasteryBar: View {
  let value: Double
  var width: CGFloat = 52

  private var hue: Double {
    value >= 0.85 ? 150 : value >= 0.5 ? 95 : 40
  }

  var body: some View {
    ZStack(alignment: .leading) {
      Capsule().fill(VocraTheme.fillStrong)
      Capsule()
        .fill(VocraTheme.hued(hue))
        .frame(width: max(4, width * value))
    }
    .frame(width: width, height: 5)
  }
}

/// Compact line + area sparkline used by the Today stat tiles.
struct Sparkline: View {
  let data: [Double]
  var size = CGSize(width: 96, height: 30)

  var body: some View {
    Canvas { context, canvasSize in
      guard data.count > 1 else { return }
      let maxValue = data.max() ?? 1
      let minValue = data.min() ?? 0
      let span = max(maxValue - minValue, 1)
      let stepX = canvasSize.width / CGFloat(data.count - 1)

      func point(_ index: Int) -> CGPoint {
        let x = CGFloat(index) * stepX
        let normalized = (data[index] - minValue) / span
        let y = canvasSize.height - normalized * (canvasSize.height - 4) - 2
        return CGPoint(x: x, y: y)
      }

      var line = Path()
      line.move(to: point(0))
      for index in 1..<data.count { line.addLine(to: point(index)) }

      var area = line
      area.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height))
      area.addLine(to: CGPoint(x: 0, y: canvasSize.height))
      area.closeSubpath()

      context.fill(area, with: .color(VocraTheme.accentSoft))
      context.stroke(line, with: .color(VocraTheme.accent), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

      let last = point(data.count - 1)
      let dot = Path(ellipseIn: CGRect(x: last.x - 2.6, y: last.y - 2.6, width: 5.2, height: 5.2))
      context.fill(dot, with: .color(VocraTheme.accent))
    }
    .frame(width: size.width, height: size.height)
  }
}

/// Liquid-glass segmented control: a rounded fill with a sliding white thumb.
struct VocraSegmented<Value: Hashable>: View {
  let options: [(value: Value, label: String)]
  @Binding var selection: Value
  var onChange: ((Value) -> Void)?

  init(options: [(value: Value, label: String)], selection: Binding<Value>, onChange: ((Value) -> Void)? = nil) {
    self.options = options
    self._selection = selection
    self.onChange = onChange
  }

  var body: some View {
    HStack(spacing: 2) {
      ForEach(options, id: \.value) { option in
        let selected = option.value == selection
        Button {
          selection = option.value
          onChange?(option.value)
        } label: {
          Text(option.label)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(selected ? VocraTheme.ink900 : VocraTheme.ink500)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background {
              if selected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                  .fill(VocraTheme.elevatedSurface)
              }
            }
        }
        .buttonStyle(.plain)
      }
    }
    .padding(2)
    .background(VocraTheme.fillStrong, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
  }
}

/// Soft neutral pill button matching `.btn-ghost`.
struct VocraGhostButtonStyle: ButtonStyle {
  var tint: Color = VocraTheme.ink700
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(tint)
      .padding(.horizontal, 14)
      .padding(.vertical, 7)
      .background(VocraTheme.fill, in: Capsule(style: .continuous))
      .opacity(configuration.isPressed ? 0.7 : 1)
  }
}

// MARK: - Speech

/// Lightweight English text-to-speech for the speaker affordances.
@MainActor
final class SpeechPlayer {
  static let shared = SpeechPlayer()
  private let synthesizer = AVSpeechSynthesizer()

  func speak(_ text: String, accent: SpeechAccent? = nil) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    synthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: trimmed)
    utterance.voice = AVSpeechSynthesisVoice(language: (accent ?? storedAccent).languageCode)
    utterance.rate = 0.46
    synthesizer.speak(utterance)
  }

  private var storedAccent: SpeechAccent {
    UserDefaults.standard.string(forKey: "vocra.voiceAccent") == "uk" ? .british : .american
  }
}

enum SpeechAccent {
  case american
  case british

  var languageCode: String {
    switch self {
    case .american: "en-US"
    case .british: "en-GB"
    }
  }
}

/// Round, ghost-styled speaker button matching the design's `.iconbtn`.
struct SpeakerButton: View {
  let text: String
  var size: CGFloat = 15
  @State private var hovering = false

  var body: some View {
    Button {
      SpeechPlayer.shared.speak(text)
    } label: {
      Image(systemName: "speaker.wave.2")
        .font(.system(size: size, weight: .regular))
        .foregroundStyle(hovering ? VocraTheme.ink900 : VocraTheme.ink500)
        .frame(width: size + 13, height: size + 13)
        .background(hovering ? VocraTheme.fill : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}
