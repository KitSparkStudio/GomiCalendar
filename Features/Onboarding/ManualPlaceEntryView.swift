//
//  ManualPlaceEntryView.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI

/// 「找不到我的地区」：手动输入任意日本地名并创建模板档案。
struct ManualPlaceEntryView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    var prefectureCode: String?
    /// 创建成功后回调（用于打开自定义收集日）。
    var onCreated: (() -> Void)?

    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L10n.t("manual_place_intro"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField(L10n.t("manual_place_placeholder"), text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Button {
                        create()
                    } label: {
                        Text(L10n.t("manual_place_create"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(L10n.t("manual_place_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("close")) { dismiss() }
                }
            }
        }
    }

    private func create() {
        _ = appModel.adoptCustomPlace(
            displayName: name,
            prefectureCode: prefectureCode ?? appModel.settings.selectedPrefectureCode
        )
        dismiss()
        DispatchQueue.main.async {
            onCreated?()
        }
    }
}
