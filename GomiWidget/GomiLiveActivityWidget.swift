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
            let tint = Color(hexString: context.attributes.themeColorHex)
            let deadline = context.state.deadline
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.symbolName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // 给 H:MM:SS 足够宽度，避免秒位变成 `--`
                    DualTimeStack(
                        deadline: deadline,
                        style: .expanded
                    )
                    .frame(minWidth: 88, alignment: .trailing)
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.categoryName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(context.attributes.bagTypeLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomBar(attributes: context.attributes, state: context.state)
                        .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: context.attributes.symbolName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tint)
                    Text(context.attributes.compactCategoryLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            } compactTrailing: {
                DualTimeStack(
                    deadline: deadline,
                    style: .compact
                )
                .frame(width: 48, alignment: .trailing)
            } minimal: {
                Image(systemName: context.attributes.symbolName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
            }
            .keylineTint(tint)
        }
    }
}

// MARK: - 倒计时 +「08:00 前」双层时间

private enum DualTimeStyle {
    case expanded
    case compact
    case lockScreen
}

private struct DualTimeStack: View {
    let deadline: Date
    let style: DualTimeStyle

    var body: some View {
        let byLabel = String(
            format: L10n.t("live_activity_by_time"),
            LiveActivityTimeFormat.hhmm(deadline)
        )
        VStack(alignment: .trailing, spacing: style == .compact ? 0 : 2) {
            // 主：实时倒计时
            Group {
                if deadline > Date.now {
                    Text(timerInterval: Date.now...deadline, countsDown: true)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(style == .compact ? 0.7 : 0.75)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(L10n.t("countdown_passed"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .font(primaryFont)
            .fontWeight(.bold)
            .foregroundStyle(.white)

            // 副：具体截止「08:00 前」
            Text(byLabel)
                .font(secondaryFont)
                .foregroundStyle(style == .compact ? Color.white.opacity(0.55) : Color.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .environment(\.timeZone, JapanCalendar.timeZone)
    }

    private var primaryFont: Font {
        switch style {
        case .compact:
            return .system(size: 11, weight: .bold)
        case .expanded:
            return .title3
        case .lockScreen:
            return .title2
        }
    }

    private var secondaryFont: Font {
        switch style {
        case .compact:
            return .system(size: 8, weight: .medium)
        case .expanded, .lockScreen:
            return .caption2.weight(.semibold)
        }
    }
}

// MARK: - Lock screen / banner

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<GomiActivityAttributes>

    var body: some View {
        let color = Color(hexString: context.attributes.themeColorHex)
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.85))
                    .frame(width: 40, height: 40)
                Image(systemName: context.attributes.symbolName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
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

            DualTimeStack(
                deadline: context.state.deadline,
                style: .lockScreen
            )
            .frame(minWidth: 96, alignment: .trailing)
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

// MARK: - Expanded bottom（唯一打卡控件）

private struct ExpandedBottomBar: View {
    let attributes: GomiActivityAttributes
    let state: GomiActivityAttributes.ContentState

    var body: some View {
        let color = Color(hexString: attributes.themeColorHex)
        Group {
            if state.isCompleted {
                Label(L10n.t("live_activity_status_done"), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(color.opacity(0.28), in: Capsule())
                    .labelStyle(.titleAndIcon)
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
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}

private enum LiveActivityTimeFormat {
    static func hhmm(_ date: Date) -> String {
        let parts = JapanCalendar.calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
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
