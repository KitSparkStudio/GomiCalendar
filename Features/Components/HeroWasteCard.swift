//
//  HeroWasteCard.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI

struct HeroWasteCard: View {
    let title: String
    let subtitle: String
    let categories: [WasteCategory]
    let isSuspended: Bool
    let suspensionNote: String?
    let countdownText: String
    let deadline: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.weight(.bold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(countdownText)
                    .font(.headline.monospacedDigit().weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            if isSuspended {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("status_suspended"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.danger)
                    if let suspensionNote {
                        Text(suspensionNote)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if categories.isEmpty {
                Text(L10n.t("no_collection_today"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(categories) { category in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(category.themeColor)
                                .frame(width: 8, height: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.names.resolved())
                                    .font(.title3.weight(.bold))
                                WasteCategoryBadge(category: category)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            Text(String(format: L10n.t("deadline_format"), deadline))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06), radius: 16, y: 8)
    }
}
