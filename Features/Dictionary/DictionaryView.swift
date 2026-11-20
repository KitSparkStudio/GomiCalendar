//
//  DictionaryView.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI

struct DictionaryView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var query = ""
    @State private var gojuon: GojuonRow = .all
    @State private var selectedItem: WasteItemEntry?

    private var filteredItems: [WasteItemEntry] {
        appModel.config.itemDictionary.filter { item in
            guard gojuon.matches(kana: item.names.kana ?? item.names.ja) else { return false }
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return true }
            return SearchNormalizer.matches(q, in: SearchNormalizer.dictionaryTokens(for: item))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme).ignoresSafeArea()

                VStack(spacing: 0) {
                    SearchField(
                        text: $query,
                        prompt: L10n.t("dictionary_search_prompt")
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                    gojuonBar
                        .padding(.bottom, 8)

                    if sizeClass == .regular {
                        splitContent
                    } else {
                        listContent
                    }
                }
            }
            .navigationTitle(L10n.t("tab_dictionary"))
            .sheet(item: $selectedItem) { item in
                ItemDetailSheet(item: item, category: category(for: item))
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var gojuonBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GojuonRow.allCases) { row in
                    Button {
                        gojuon = row
                    } label: {
                        Text(row.label)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                row == gojuon ? Color.accentColor : AppTheme.card(for: colorScheme),
                                in: Capsule()
                            )
                            .foregroundStyle(row == gojuon ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var listContent: some View {
        List(filteredItems) { item in
            Button {
                selectedItem = item
            } label: {
                ItemRow(item: item, category: category(for: item))
            }
            .listRowBackground(AppTheme.card(for: colorScheme))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var splitContent: some View {
        HStack(spacing: 0) {
            List(filteredItems, selection: Binding(
                get: { selectedItem?.id },
                set: { id in
                    selectedItem = appModel.config.itemDictionary.first { $0.id == id }
                }
            )) { item in
                ItemRow(item: item, category: category(for: item))
                    .tag(item.id)
                    .listRowBackground(AppTheme.card(for: colorScheme))
            }
            .listStyle(.sidebar)
            .frame(minWidth: 280, idealWidth: 320)

            Divider()

            Group {
                if let selectedItem, let category = category(for: selectedItem) {
                    ItemDetailContent(item: selectedItem, category: category)
                        .padding(24)
                } else {
                    ContentUnavailableView(
                        L10n.t("dictionary_select_prompt"),
                        systemImage: "magnifyingglass"
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background(for: colorScheme))
        }
    }

    private func category(for item: WasteItemEntry) -> WasteCategory? {
        appModel.config.categories.first { $0.id == item.categoryId }
    }
}

private struct ItemRow: View {
    let item: WasteItemEntry
    let category: WasteCategory?

    var body: some View {
        HStack(spacing: 12) {
            if let category {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(category.themeColor)
                    .frame(width: 6, height: 36)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.names.resolvedForApp())
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(secondaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let category {
                Text(category.names.resolvedForApp())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(category.themeColor.opacity(0.18), in: Capsule())
            }
        }
        .contentShape(Rectangle())
    }

    private var secondaryLine: String {
        if let kana = item.names.kana { return kana }
        return item.names.en
    }
}

struct ItemDetailSheet: View {
    let item: WasteItemEntry
    let category: WasteCategory?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ItemDetailContent(item: item, category: category)
                .padding(20)
                .navigationTitle(L10n.t("item_detail_title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.t("close")) { dismiss() }
                    }
                }
        }
    }
}

struct ItemDetailContent: View {
    let item: WasteItemEntry
    let category: WasteCategory?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.names.resolved())
                        .font(.largeTitle.weight(.bold))
                    if AppLanguageCode.load().resolvedContentCode() == "ja",
                       let kana = item.names.kana {
                        Text(kana)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                if let category {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.t("classification_result"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(category.names.resolvedForApp())
                            .font(.title.weight(.bold))
                            .foregroundStyle(category.themeColor)

                        labeledRequirement(
                            title: L10n.t("disposal_bag_type"),
                            value: category.bagBadge.label.resolvedForApp()
                        )
                        WasteCategoryBadge(category: category)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label(L10n.t("tips_warning_title"), systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.danger)
                    Text(L10n.t("disposal_requirements"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.danger.opacity(0.9))
                    Text(item.tips.resolvedForApp())
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppTheme.danger.opacity(0.5), lineWidth: 1.5)
                )
            }
        }
    }

    private func labeledRequirement(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
        }
    }
}
