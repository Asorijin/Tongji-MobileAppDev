import SwiftUI

struct TagManagementView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTagID: UUID?
    @State private var newTagName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("新建标签") {
                    HStack {
                        TextField("如 Conference / Professor / Customer", text: $newTagName)
                            .accessibilityIdentifier("tag-name-field")
                        Button("添加") {
                            if let tag = environment.store.createTag(named: newTagName) {
                                newTagName = ""
                                _ = tag
                            }
                        }
                        .accessibilityIdentifier("tag-add")
                    }
                }
                Section("全部标签") {
                    if environment.store.tags.isEmpty {
                        Text("还没有标签").foregroundStyle(.secondary)
                    }
                    ForEach(environment.store.tags) { tag in
                        Button {
                            selectedTagID = tag.id
                            dismiss()
                        } label: {
                            HStack {
                                Text(tag.name).foregroundStyle(.primary)
                                Spacer()
                                Text("\(environment.store.cards(withTag: tag.id).count) 张")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if selectedTagID == tag.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .accessibilityIdentifier("tag-row-\(tag.name)")
                        .swipeActions {
                            Button("删除", role: .destructive) {
                                environment.store.deleteTag(tag.id)
                                if selectedTagID == tag.id { selectedTagID = nil }
                            }
                        }
                    }
                }
            }
            .navigationTitle("标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
