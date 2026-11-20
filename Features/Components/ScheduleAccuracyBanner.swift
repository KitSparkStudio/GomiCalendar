//
//  ScheduleAccuracyBanner.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI

/// 收集日误差温和提示 / 已应用自定义后的安心反馈；点击进入「自定义收集日」。
struct ScheduleAccuracyBanner: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme

    /// 首页可关闭；设置页传 `nil` 永久保留。
    var onDismiss: (() -> Void)?
    var onOpenCustomSchedule: () -> Void

    private var isConfirmed: Bool {
        appModel.hasCustomScheduleOverride
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onOpenCustomSchedule) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isConfirmed ? "checkmark.seal.fill" : "info.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(accent)
                        .padding(.top, 1)

                    Text(L10n.t(isConfirmed ? "schedule_hint_confirmed" : "schedule_hint_warning"))
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.85))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("close"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent.opacity(colorScheme == .dark ? 0.35 : 0.22), lineWidth: 1)
        )
        // 依赖 scheduleEpoch，保存/清除覆盖后即时切换文案
        .id(appModel.scheduleEpoch)
    }

    private var accent: Color {
        isConfirmed ? Color(hex: 0x34C759) : Color(hex: 0xFF9F0A)
    }

    private var backgroundFill: Color {
        if isConfirmed {
            return Color(hex: 0x34C759).opacity(colorScheme == .dark ? 0.14 : 0.10)
        }
        return Color(hex: 0xFF9F0A).opacity(colorScheme == .dark ? 0.12 : 0.08)
    }
}
