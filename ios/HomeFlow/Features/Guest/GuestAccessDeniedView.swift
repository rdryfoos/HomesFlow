import SwiftUI

// @covers AC-GUEST-02, FR-GUEST-01

struct GuestAccessDeniedView: View {
    var title: String = "Access restricted"
    var message: String =
        "Your guest account cannot view this item. Ask the home admin if you need access."

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "lock.fill",
            description: Text(message)
        )
    }
}
