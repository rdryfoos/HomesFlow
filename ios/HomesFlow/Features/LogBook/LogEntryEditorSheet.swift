import SwiftUI

// @covers FR-LOG-02, AC-LOG-01, AC-LOG-02, AC-LOG-04

struct LogEntryEditorSheet: View {
    let mode: LogEntryEditorMode
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var bodyText: String

    init(mode: LogEntryEditorMode, onSave: @escaping (String) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _bodyText = State(initialValue: "")
        case .edit(let entry):
            _bodyText = State(initialValue: entry.body)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 160)
                } footer: {
                    Text("Entries sync offline and appear in occurrence-time order for everyone who can access this log.")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(bodyText)
                        dismiss()
                    }
                    .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var title: String {
        switch mode {
        case .create: "New entry"
        case .edit: "Edit entry"
        }
    }
}
