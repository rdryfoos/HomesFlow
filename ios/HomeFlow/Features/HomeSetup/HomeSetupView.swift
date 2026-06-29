import SwiftUI
import PhotosUI
import UIKit

// @covers AC-HOME-01, AC-HOME-02, AC-HOME-03, FR-HOME-01

struct HomeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var appEnvironment

    let existingHome: HomeSummary?
    var onSaved: (HomeSummary) -> Void

    @State private var name: String
    @State private var streetAddress: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(existingHome: HomeSummary? = nil, onSaved: @escaping (HomeSummary) -> Void) {
        self.existingHome = existingHome
        self.onSaved = onSaved
        _name = State(initialValue: existingHome?.name ?? "")
        _streetAddress = State(initialValue: existingHome?.streetAddress ?? "")
    }

    private var isEditing: Bool { existingHome != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            HomePhotoThumbnail(
                                photoData: selectedPhotoData,
                                storagePath: existingHome?.photoURL,
                                homeId: existingHome?.id
                            )
                            Text(selectedPhotoData == nil && existingHome?.photoURL == nil
                                 ? "Add photo"
                                 : "Change photo")
                        }
                    }
                    .onChange(of: selectedPhoto) { _, item in
                        Task { await loadPhoto(from: item) }
                    }
                }

                Section("Home details") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    TextField("Street address", text: $streetAddress, axis: .vertical)
                        .lineLimit(2...4)
                        .textContentType(.fullStreetAddress)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Home" : "Add Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || !canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        HomeValidator.validate(name: name, streetAddress: streetAddress).isSuccess
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else {
            selectedPhotoData = nil
            return
        }
        selectedPhotoData = try? await item.loadTransferable(type: Data.self)
    }

    private func save() async {
        guard let repo = appEnvironment?.homeRepository else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let home: HomeSummary
            if let existingHome {
                home = try await repo.updateHome(
                    id: existingHome.id,
                    name: name,
                    streetAddress: streetAddress,
                    photoData: selectedPhotoData
                )
            } else {
                home = try await repo.createHome(
                    name: name,
                    streetAddress: streetAddress,
                    photoData: selectedPhotoData
                )
            }
            onSaved(home)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct HomePhotoThumbnail: View {
    @Environment(\.appEnvironment) private var appEnvironment

    let photoData: Data?
    let storagePath: String?
    let homeId: UUID?

    @State private var remoteURL: URL?

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let remoteURL {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: storagePath) {
            await loadRemoteURL()
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.15)
            Image(systemName: "house")
                .foregroundStyle(.secondary)
        }
    }

    private func loadRemoteURL() async {
        guard photoData == nil,
              let path = storagePath,
              let homeId,
              let repo = appEnvironment?.homeRepository else { return }
        let summary = HomeSummary(id: homeId, name: "", streetAddress: "", photoURL: path, isPendingSync: false)
        remoteURL = try? await repo.signedPhotoURL(for: summary)
    }
}

private extension Result where Success == Void, Failure == HomeValidationError {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
