//
//  AutoLocateButton.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI

/// 「自動定位当前地区（現在地から自動設定）」醒目按钮。
struct AutoLocateButton: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    var onLocated: (() -> Void)?

    @State private var locator = LocationPlaceResolver.shared
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await locate() }
            } label: {
                HStack(spacing: 10) {
                    if locator.isLocating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "location.fill")
                            .font(.body.weight(.semibold))
                    }
                    Text(L10n.t("locate_button_title"))
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0x0A84FF), Color(hex: 0x34C759)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(locator.isLocating)

            if let errorText {
                Text(errorText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.danger)
            }
        }
    }

    private func locate() async {
        errorText = nil
        do {
            try await appModel.autoLocateCurrentMunicipality()
            onLocated?()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
