import SwiftUI

struct CardListView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var searchText = ""
    @State private var selectedTagID: UUID?
    @State private var activeSheet: ActiveSheet?

    /// 单一 sheet 枚举：iOS 16 上同一视图挂多个 .sheet 只有最后一个生效。
    private enum ActiveSheet: Identifiable {
        case scanner
        case manualEntry
        case tags

        var id: Int {
            switch self {
            case .scanner: return 0
            case .manualEntry: return 1
            case .tags: return 2
            }
        }
    }

    private var visibleCards: [BusinessCard] {
        var cards = environment.store.search(searchText)
        if let selectedTagID {
            cards = cards.filter { $0.tagIDs.contains(selectedTagID) }
        }
        return cards
    }

    var body: some View {
        NavigationStack {
            Group {
                if environment.store.cards.isEmpty {
                    EmptyCardListView(
                        onScan: { activeSheet = .scanner },
                        onManualEntry: { activeSheet = .manualEntry }
                    )
                } else {
                    cardList
                }
            }
            .navigationTitle("名片夹")
            .searchable(text: $searchText, prompt: "搜索姓名、公司、职位、电话、邮箱")
            .toolbar {
                // iOS 16 兼容：不使用 .topBarLeading/.topBarTrailing（iOS 17+）。
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        activeSheet = .tags
                    } label: {
                        Label("标签", systemImage: "tag")
                    }
                    .accessibilityIdentifier("tags-button")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        activeSheet = .scanner
                    } label: {
                        Label("扫描名片", systemImage: "camera.viewfinder")
                    }
                    .accessibilityIdentifier("scan-button")
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .scanner:
                    ScannerView()
                case .manualEntry:
                    CardEditView(draft: CardDraft(), isNew: true)
                case .tags:
                    TagManagementView(selectedTagID: $selectedTagID)
                }
            }
        }
    }

    private var cardList: some View {
        List {
            if let selectedTagID, let tag = environment.store.tags.first(where: { $0.id == selectedTagID }) {
                HStack {
                    Label("标签：\(tag.name)", systemImage: "tag.fill")
                    Spacer()
                    Button("清除") { self.selectedTagID = nil }
                        .accessibilityIdentifier("clear-tag-filter")
                }
            }
            ForEach(visibleCards) { card in
                NavigationLink(value: card.id) {
                    CardRow(card: card)
                }
                .accessibilityIdentifier("card-row-\(card.displayName)")
                // 列表内滑动删除（T14）；详情页菜单的删除走确认弹窗。
                .swipeActions {
                    Button(role: .destructive) {
                        environment.store.delete(cardID: card.id)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("card-list")
        .navigationDestination(for: UUID.self) { id in
            CardDetailView(cardID: id)
        }
        .overlay {
            if visibleCards.isEmpty {
                SearchEmptyView()
            }
        }
    }
}

/// 搜索无结果占位视图（iOS 16 兼容版 ContentUnavailableView）。
private struct SearchEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("没有匹配的名片")
                .font(.headline)
                .accessibilityIdentifier("search-empty-title")
            Text("换个关键词试试")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

struct EmptyCardListView: View {
    let onScan: () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("名片夹为空")
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("empty-state-title")
            Text("拍摄或导入一张名片，开始建立你的名片夹")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: onScan) {
                Label("扫描名片", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .accessibilityIdentifier("empty-state-scan")
            Button("手动录入", action: onManualEntry)
                .accessibilityIdentifier("empty-state-manual")
        }
    }
}

struct CardRow: View {
    let card: BusinessCard

    var body: some View {
        HStack(spacing: 12) {
            Text(card.displayInitials)
                .font(.headline)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(card.displayName).font(.body.weight(.medium))
                if let subtitle = subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var subtitle: String? {
        let parts = [card.jobTitle, card.company].compactMap { $0 }
        return parts.isEmpty ? card.allPhones.first : parts.joined(separator: " · ")
    }
}
