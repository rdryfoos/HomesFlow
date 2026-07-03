import SwiftUI
import UIKit

// @covers FR-HOME-01, AC-HOME-07, AC-A11Y-01, NFR-A11Y-01

struct HomeHeroCard: View {
    let home: HomeSummary
    var style: Style = .list
    var showsDisclosureIndicator: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum Style {
        case list
        case dashboard
        case detail
        case sidebar

        var height: CGFloat {
            switch self {
            case .list: 152
            case .dashboard: 528
            case .detail: 220
            case .sidebar: 120
            }
        }

        var photoVerticalAlignment: Alignment {
            switch self {
            case .list: .top
            default: .center
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .list, .detail: 0
            case .dashboard: 0
            case .sidebar: 12
            }
        }

        var titleFont: Font {
            switch self {
            case .list: .title3.bold()
            case .dashboard: .title.bold()
            case .detail: .title2.bold()
            case .sidebar: .headline.bold()
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HomePhotoFillView(
                photoData: nil,
                storagePath: home.photoURL,
                homeId: home.id,
                verticalAlignment: style.photoVerticalAlignment
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
                    Text(home.locationLabel)
                        .lineLimit(style == .detail || style == .dashboard ? 3 : 2)
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
                }
                .font(style == .sidebar ? .caption : .subheadline)
                .foregroundStyle(.white.opacity(0.92))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            if SyncIndicatorPolicy.showsBadge(for: home) {
                syncBadge
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            if showsDisclosureIndicator {
                disclosureIndicator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
        // AC-A11Y-01: hero height scales with Dynamic Type so the name and
        // address overlay reflow without clipping at accessibility sizes.
        .frame(height: AccessibilityBaseline.scaledHeroHeight(base: style.height, for: dynamicTypeSize))
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        SyncIndicatorPolicy.accessibilityLabel(for: home)
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
    var verticalAlignment: Alignment = .center

    @State private var loadedImage: UIImage?

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFill()
                } else if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: verticalAlignment)
            .clipped()
        }
        .task(id: loadKey) {
            await loadPhotoIfNeeded()
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

    private func loadPhotoIfNeeded() async {
        if photoData != nil {
            loadedImage = photoData.flatMap(UIImage.init(data:))
            return
        }

        guard let path = storagePath else {
            loadedImage = nil
            return
        }

        if let repo = appEnvironment?.homeRepository,
           let cached = repo.cachedPhoto(for: path) {
            loadedImage = cached
            return
        }

        guard let repo = appEnvironment?.homeRepository else {
            loadedImage = nil
            return
        }

        loadedImage = try? await repo.loadPhoto(storagePath: path)
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
