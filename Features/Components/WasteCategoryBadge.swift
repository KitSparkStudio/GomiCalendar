//
//  WasteCategoryBadge.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI

struct WasteCategoryBadge: View {
    let category: WasteCategory
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(category.themeColor)
                .frame(width: compact ? 8 : 10, height: compact ? 8 : 10)
            Text(category.bagBadge.label.resolved())
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(category.themeColor.opacity(0.18), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(category.themeColor.opacity(0.45), lineWidth: 1)
        )
        .accessibilityLabel("\(category.names.resolved()), \(category.bagBadge.label.resolved())")
    }
}

struct DaysUntilCapsule: View {
    let category: WasteCategory
    let daysUntil: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(category.themeColor)
                    .frame(width: 8, height: 8)
                Text(category.names.resolved())
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            Text(daysLabel)
                .font(.title3.weight(.bold))
                .foregroundStyle(category.themeColor)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(12)
        .frame(minWidth: 108, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(category.themeColor.opacity(0.35), lineWidth: 1)
        )
    }

    private var daysLabel: String {
        guard let daysUntil else { return L10n.t("days_unknown") }
        if daysUntil == 0 { return L10n.t("days_today") }
        if daysUntil == 1 { return L10n.t("days_tomorrow") }
        return String(format: L10n.t("days_in_format"), daysUntil)
    }
}
