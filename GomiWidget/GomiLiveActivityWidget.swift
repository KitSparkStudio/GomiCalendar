//
//  GomiLiveActivityWidget.swift
//  GomiWidget
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct GomiLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GomiActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    glowingIcon(
                        symbol: context.attributes.symbolName,
                        hex: context.attributes.themeColorHex,
                        size: 30
                    )
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdownText(deadline: context.attributes.deadlineDate)
                        .font(.title2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 3) {
                        Text(context.attributes.categoryName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(context.attributes.bagTypeLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(hexString: context.attributes.themeColorHex))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomBar(attributes: context.attributes, state: context.state)
                        .padding(.top, 4)
                }
            } compactLeading: {
                glowingIcon(
                    symbol: context.attributes.symbolName,
                    hex: context.attributes.themeColorHex,
                    size: 16
                )
            } compactTrailing: {
                countdownText(deadline: context.attributes.deadlineDate)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 44)
                    .padding(.trailing, 2)
            } minimal: {
                Circle()
                    .fill(Color(hexString: context.attributes.themeColorHex))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Image(systemName: context.attributes.symbolName)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: Color(hexString: context.attributes.themeColorHex).opacity(0.85), radius: 3)
            }
            .keylineTint(Color(hexString: context.attributes.themeColorHex))
        }
    }

    @ViewBuilder
    private func countdownText(deadline: Date) -> some View {
        if deadline > Date() {
            Text(timerInterval: Date.now...deadline, countsDown: true)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        } else {
            Text("0:00")
                .monospacedDigit()
        }
    }

    private func glowingIcon(symbol: String, hex: String, size: CGFloat) -> some View {
        let color = Color(hexString: hex)
        return ZStack {
            Circle()
                .fill(color.opacity(0.4))
                .frame(width: size + 10, height: size + 10)
                .blur(radius: 4)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.95), color.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size + 4, height: size + 4)
                .shadow(color: color.opacity(0.9), radius: 5, y: 1)
            Image(systemName: symbol)
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Lock screen / banner (expanded-style card)

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<GomiActivityAttributes>

    var body: some View {
        let color = Color(hexString: context.attributes.themeColorHex)
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 52, height: 52)
                    .blur(radius: 3)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: color.opacity(0.7), radius: 8, y: 2)
                Image(systemName: context.attributes.symbolName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(context.attributes.categoryName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(context.attributes.bagTypeLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.22), in: Capsule())
                    .foregroundStyle(color)
                    .lineLimit(1)
                Text(context.attributes.districtName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.t("live_activity_until"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                if context.attributes.deadlineDate > Date() {
                    Text(timerInterval: Date.now...context.attributes.deadlineDate, countsDown: true)
                        .font(.title2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text("0:00")
                        .font(.title2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: 0x161A1E))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.28), .clear, color.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
    }
}

// MARK: - Expanded bottom

private struct ExpandedBottomBar: View {
    let attributes: GomiActivityAttributes
    let state: GomiActivityAttributes.ContentState

    var body: some View {
        let color = Color(hexString: attributes.themeColorHex)
        VStack(spacing: 8) {
            if state.isCompleted {
                Text(L10n.t("live_activity_status_done"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(color.opacity(0.28), in: Capsule())
            } else {
                Button(intent: CompleteGomiDropIntent()) {
                    Label(L10n.t("live_activity_mark_done"), systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}

// MARK: - Color helper (Widget target)

private extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    init(hexString: String) {
        var cleaned = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(hex: UInt32(value))
    }
}
