import SwiftUI
import UIKit

// @covers FR-HOME-01

struct HomeHeroCard: View {
    let home: HomeSummary
    var style: Style = .list
    var showsDisclosureIndicator: Bool = false

    enum Style {
        case list
        case detail

        var height: CGFloat {
            switch self {
            case .list: 152
            case .detail: 220
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .list: 0
            case .detail: 0
            }
        }

        var titleFont: Font {
            switch self {
            case .list: .title3.bold()
            case .detail: .title2.bold()
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HomePhotoFillView(
                photoData: nil,
                storagePath: home.photoURL,
                homeId: home.id
            )

            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(home.name)
                    .font(style.titleFont)
                    .foregroundStyle(.white)
                Label {
                    Text(home.streetAddress)
                        .lineLimit(style == .detail ? 3 : 2)
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            if home.isPendingSync {
                syncBadge
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            if showsDisclosureIndicator {
                disclosureIndicator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
        .frame(height: style.height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [home.name, home.streetAddress]
        if home.isPendingSync {
            parts.append("Not synced")
        }
        return parts.joined(separator: ", ")
    }

    private var syncBadge: some View {
        Image(systemName: "icloud.and.arrow.up")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.45), in: Capsule())
            .accessibilityLabel("Not synced")
    }

    private var disclosureIndicator: some View {
        Image(systemName: "chevron.right")
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
            .padding(.trailing, 16)
            .accessibilityHidden(true)
    }
}

struct HomePhotoFillView: View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: loadKey) {
            await loadRemoteURL()
        }
    }

    private var loadKey: String {
        "\(homeId?.uuidString ?? "")|\(storagePath ?? "")|\(photoData?.count ?? 0)"
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.secondary.opacity(0.2),
                    Color.secondary.opacity(0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "house.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.45))
        }
    }

    private func loadRemoteURL() async {
        guard photoData == nil,
              let path = storagePath,
              let homeId,
              let repo = appEnvironment?.homeRepository else {
            remoteURL = nil
            return
        }
        let summary = HomeSummary(id: homeId, name: "", streetAddress: "", photoURL: path)
        remoteURL = try? await repo.signedPhotoURL(for: summary)
    }
}

struct HomePhotoThumbnail: View {
    let photoData: Data?
    let storagePath: String?
    let homeId: UUID?

    var body: some View {
        HomePhotoFillView(
            photoData: photoData,
            storagePath: storagePath,
            homeId: homeId
        )
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
