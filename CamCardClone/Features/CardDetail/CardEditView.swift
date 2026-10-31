import SwiftUI

/// 结构化字段编辑界面：识别结果的人工校正入口（Human-in-the-Loop）。
struct CardEditView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CardDraft
    private let isNew: Bool

    @State private var name: String
    @State private var company: String
    @State private var jobTitle: String
    @State private var department: String
    @State private var mobiles: String
    @State private var officePhones: String
    @State private var faxes: String
    @State private var emails: String
    @State private var websites: String
    @State private var address: String
    @State private var postalCode: String
    @State private var notes: String
    @State private var selectedTagIDs: Set<UUID>
    @State private var newTagName = ""

    init(draft: CardDraft, isNew: Bool) {
        self._draft = State(initialValue: draft)
        self.isNew = isNew
        let card = draft.card
        _name = State(initialValue: card.name ?? "")
        _company = State(initialValue: card.company ?? "")
        _jobTitle = State(initialValue: card.jobTitle ?? "")
        _department = State(initialValue: card.department ?? "")
        _mobiles = State(initialValue: card.mobiles.joined(separator: "\n"))
        _officePhones = State(initialValue: card.officePhones.joined(separator: "\n"))
        _faxes = State(initialValue: card.faxes.joined(separator: "\n"))
        _emails = State(initialValue: card.emails.joined(separator: "\n"))
        _websites = State(initialValue: card.websites.joined(separator: "\n"))
        _address = State(initialValue: card.address ?? "")
        _postalCode = State(initialValue: card.postalCode ?? "")
        _notes = State(initialValue: card.notes ?? "")
        _selectedTagIDs = State(initialValue: Set(card.tagIDs))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let raw = draft.rawOCRText, !raw.isEmpty {
                    Section("识别原文") {
                        Text(raw)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("raw-ocr-text")
                    }
                }

                Section("基本信息") {
                    field("姓名", text: $name, id: "field-name")
                    field("公司", text: $company, id: "field-company")
                    field("职位", text: $jobTitle, id: "field-jobTitle")
                    field("部门", text: $department, id: "field-department")
                }

                Section("联系方式（每行一个）") {
                    multiline("手机", text: $mobiles, id: "field-mobiles")
                    multiline("办公电话", text: $officePhones, id: "field-officePhones")
                    multiline("传真", text: $faxes, id: "field-faxes")
                    multiline("邮箱", text: $emails, id: "field-emails")
                    multiline("网址", text: $websites, id: "field-websites")
                }

                Section("地址") {
                    field("地址", text: $address, id: "field-address")
                    field("邮编", text: $postalCode, id: "field-postalCode")
                }

                Section("备注") {
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("field-notes")
                }

                Section("标签") {
                    ForEach(environment.store.tags) { tag in
                        Button {
                            toggle(tag.id)
                        } label: {
                            HStack {
                                Text(tag.name).foregroundStyle(.primary)
                                Spacer()
                                if selectedTagIDs.contains(tag.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    HStack {
                        TextField("新建标签", text: $newTagName)
                            .accessibilityIdentifier("new-tag-field")
                        Button("添加") {
                            if let tag = environment.store.createTag(named: newTagName) {
                                selectedTagIDs.insert(tag.id)
                                newTagName = ""
                            }
                        }
                        .accessibilityIdentifier("add-tag-button")
                    }
                }
            }
            .navigationTitle(isNew ? "确认名片" : "编辑名片")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .accessibilityIdentifier("edit-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .accessibilityIdentifier("edit-save")
                        .disabled(!hasAnyContent)
                }
            }
        }
    }

    /// 空名片没有保存意义（T20：字段为空时的异常路径）。
    private var hasAnyContent: Bool {
        [name, company, jobTitle, department, address, postalCode, notes,
         mobiles, officePhones, faxes, emails, websites]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func field(_ title: String, text: Binding<String>, id: String) -> some View {
        // 不用 LabeledContent：iOS 16 上它会把子元素合并成一个无障碍元素，
        // 导致 UI 测试无法按标识符定位输入框。HStack 布局与原生 LabeledContent 视觉一致。
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            TextField(title, text: text)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier(id)
        }
    }

    private func multiline(_ title: String, text: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: text, axis: .vertical)
                .lineLimit(1...4)
                .accessibilityIdentifier(id)
        }
    }

    private func toggle(_ tagID: UUID) {
        if selectedTagIDs.contains(tagID) {
            selectedTagIDs.remove(tagID)
        } else {
            selectedTagIDs.insert(tagID)
        }
    }

    private func lines(_ text: String) -> [String] {
        text.split(separator: "\n")
            .flatMap { $0.split(separator: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func save() {
        var card = draft.card
        card.name = TextNormalizer.sanitized(name)
        card.company = TextNormalizer.sanitized(company)
        card.jobTitle = TextNormalizer.sanitized(jobTitle)
        card.department = TextNormalizer.sanitized(department)
        card.mobiles = lines(mobiles)
        card.officePhones = lines(officePhones)
        card.faxes = lines(faxes)
        card.emails = lines(emails)
        card.websites = lines(websites)
        card.address = TextNormalizer.sanitized(address)
        card.postalCode = TextNormalizer.sanitized(postalCode)
        card.notes = TextNormalizer.sanitized(notes)
        card.tagIDs = Array(selectedTagIDs)

        if let original = draft.originalImageData, let processed = draft.processedImageData {
            if let paths = try? environment.store.saveImages(original: original, processed: processed, cardID: card.id) {
                card.originalImagePath = paths.original
                card.processedImagePath = paths.processed
            }
        }
        if let raw = draft.rawOCRText { card.rawOCRText = raw }

        if isNew {
            environment.store.add(card)
        } else {
            environment.store.update(card)
        }
        dismiss()
    }
}
