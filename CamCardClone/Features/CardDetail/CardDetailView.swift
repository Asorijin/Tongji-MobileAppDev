import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CardDetailView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    let cardID: UUID
    @State private var activeSheet: ActiveSheet?
    @State private var activeAlert: DetailAlert?
    @State private var shareItems: [Any] = []

    /// 单一 sheet / alert 枚举：iOS 16 上同一视图挂多个同类 presentation 时只有最后一个生效。
    private enum ActiveSheet: Identifiable {
        case edit
        case share

        var id: Int {
            switch self {
            case .edit: return 0
            case .share: return 1
            }
        }
    }

    private enum DetailAlert: Identifiable {
        case delete
        case exportFailure(String)

        var id: String {
            switch self {
            case .delete: return "delete"
            case .exportFailure: return "exportFailure"
            }
        }
    }

    private var card: BusinessCard? {
        environment.store.card(withID: cardID)
    }

    var body: some View {
        Group {
            if let card = card {
                detail(card)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.rectangle")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("名片不存在")
                        .font(.headline)
                    Text("可能已被删除")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("名片详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { activeSheet = .edit } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    Button { export(card) } label: {
                        Label("导出联系人（VCF）", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { activeAlert = .delete } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("detail-menu")
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit:
                if let card {
                    CardEditView(draft: CardDraft(card: card), isNew: false)
                }
            case .share:
                ShareSheet(items: shareItems)
            }
        }
        .alert(alertTitle, isPresented: alertPresented) {
            if isDeleteAlert {
                Button("删除", role: .destructive) {
                    environment.store.delete(cardID: cardID)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } else {
                Button("好", role: .cancel) { activeAlert = nil }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private var alertPresented: Binding<Bool> {
        Binding(
            get: { activeAlert != nil },
            set: { if !$0 { activeAlert = nil } }
        )
    }

    private var isDeleteAlert: Bool {
        guard case .delete? = activeAlert else { return false }
        return true
    }

    private var alertTitle: String {
        if case .delete? = activeAlert { return "删除这张名片？" }
        if case .exportFailure? = activeAlert { return "导出失败" }
        return ""
    }

    private var alertMessage: String {
        if case .delete? = activeAlert { return "删除后无法恢复" }
        if case .exportFailure(let message)? = activeAlert { return message }
        return ""
    }

    private func detail(_ card: BusinessCard) -> some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text(card.displayInitials)
                        .font(.largeTitle)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(Color.accentColor.opacity(0.15)))
                    Text(card.displayName)
                        .font(.title2.weight(.semibold))
                        .accessibilityIdentifier("detail-name")
                    if let subtitle = [card.jobTitle, card.company].compactMap({ $0 }).joined(separator: " · ").nonEmpty {
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            if let imageData = environment.store.images.data(forRelativePath: card.processedImagePath),
               let uiImage = UIImage(data: imageData) {
                Section("名片图像") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .accessibilityIdentifier("detail-image")
                }
            }

            Section("联系信息") {
                if !card.mobiles.isEmpty {
                    ForEach(card.mobiles, id: \.self) { phone in
                        linkRow(title: "手机", value: phone, systemImage: "iphone", url: phoneURL(phone), id: "detail-mobile")
                    }
                }
                if !card.officePhones.isEmpty {
                    ForEach(card.officePhones, id: \.self) { phone in
                        linkRow(title: "办公电话", value: phone, systemImage: "phone", url: phoneURL(phone), id: "detail-office")
                    }
                }
                if !card.faxes.isEmpty {
                    ForEach(card.faxes, id: \.self) { fax in
                        valueRow(title: "传真", value: fax, systemImage: "printer", id: "detail-fax")
                    }
                }
                if !card.emails.isEmpty {
                    ForEach(card.emails, id: \.self) { email in
                        linkRow(title: "邮箱", value: email, systemImage: "envelope", url: URL(string: "mailto:\(email)"), id: "detail-email")
                    }
                }
                if !card.websites.isEmpty {
                    ForEach(card.websites, id: \.self) { site in
                        linkRow(title: "网址", value: site, systemImage: "globe", url: URL(string: site), id: "detail-website")
                    }
                }
                if let address = card.address {
                    valueRow(title: "地址", value: address, systemImage: "mappin.and.ellipse", id: "detail-address")
                }
                if let postal = card.postalCode {
                    valueRow(title: "邮编", value: postal, systemImage: "number", id: "detail-postalCode")
                }
                if let department = card.department {
                    valueRow(title: "部门", value: department, systemImage: "building.2", id: "detail-department")
                }
                if let notes = card.notes {
                    valueRow(title: "备注", value: notes, systemImage: "note.text", id: "detail-notes")
                }
            }

            if !environment.store.tags(for: card).isEmpty {
                Section("标签") {
                    FlowLayout(spacing: 6) {
                        ForEach(environment.store.tags(for: card)) { tag in
                            Text(tag.name)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        }
                    }
                }
            }
        }
    }

    private func linkRow(title: String, value: String, systemImage: String, url: URL?, id: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage).foregroundStyle(.secondary)
            Spacer()
            if let url {
                Link(value, destination: url).accessibilityIdentifier(id)
            } else {
                Text(value)
            }
        }
    }

    private func valueRow(title: String, value: String, systemImage: String, id: String) -> some View {
        HStack(alignment: .top) {
            Label(title, systemImage: systemImage).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).accessibilityIdentifier(id)
        }
    }

    private func phoneURL(_ phone: String) -> URL? {
        URL(string: "tel:" + phone.replacingOccurrences(of: " ", with: ""))
    }

    private func export(_ card: BusinessCard?) {
        guard let card else { return }
        do {
            let url = try VCardExporter.writeFile(for: card, in: FileManager.default.temporaryDirectory)
            shareItems = [url]
            activeSheet = .share
        } catch {
            activeAlert = .exportFailure(error.localizedDescription)
        }
    }
}

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
