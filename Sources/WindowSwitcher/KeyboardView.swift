import SwiftUI

/// Shared state between the overlay panel and the SwiftUI keyboard.
final class OverlayModel: ObservableObject {
    @Published var rows: [[KeyCap]] = []
    @Published var windowCount: Int = 0
    var onSelect: (WindowInfo) -> Void = { _ in }
}

private let keyWidth: CGFloat = 90
private let keyHeight: CGFloat = 92
private let keySpacing: CGFloat = 12

struct KeyboardView: View {
    @ObservedObject var model: OverlayModel

    var body: some View {
        VStack(spacing: 18) {
            HeaderBar(count: model.windowCount)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: keySpacing) {
                ForEach(Array(model.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: keySpacing) {
                        ForEach(row) { cap in
                            KeyCapView(cap: cap) {
                                if let w = cap.window { model.onSelect(w) }
                            }
                        }
                    }
                }
            }
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 44, y: 20)
        .padding(40)
    }
}

// MARK: - Header

private struct HeaderBar: View {
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            logo
            Text("窗口闪切")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
            Text(count > 0
                 ? "按对应按键直达窗口，多窗口 App 也能一键选中"
                 : "当前没有可切换的窗口")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 12)
            hintChip
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }

    private var logo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.46, green: 0.62, blue: 1.0),
                             Color(red: 0.30, green: 0.44, blue: 0.95)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
        }
        .frame(width: 26, height: 26)
    }

    private var hintChip: some View {
        HStack(spacing: 5) {
            Text("⌥Tab")
            Text("·")
            Text("双击 Fn")
            Text("·")
            Text("Esc 关闭")
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.08)))
    }
}

// MARK: - Key cap

private struct KeyCapView: View {
    let cap: KeyCap
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(hovering && cap.window != nil ? 0.16 : 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(hovering && cap.window != nil ? 0.45 : 0.12),
                                          lineWidth: 1)
                    )
                content
            }
            .frame(width: keyWidth, height: keyHeight)
        }
        .buttonStyle(.plain)
        .disabled(cap.window == nil)
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var content: some View {
        if let win = cap.window {
            VStack(spacing: 4) {
                if let icon = win.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 48, height: 48)
                }
                Text(win.displayTitle)
                    .font(.system(size: 9.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: keyWidth - 10)
            }
            .padding(.vertical, 6)
            // faint key hint in the top-left corner, like 浮光
            .overlay(alignment: .topLeading) {
                Text(cap.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.5))
                    .padding(.leading, 7)
                    .padding(.top, 6)
            }
        } else {
            Text(cap.label)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.6))
        }
    }
}
