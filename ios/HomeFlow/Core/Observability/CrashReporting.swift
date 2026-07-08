import Foundation
import Sentry

/// Optional crash telemetry — active only when `SENTRY_DSN` is set in xcconfig.
/// No PII in breadcrumbs or tags (craft-conventions.md).
enum CrashReporting {
    static func start() {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String else { return }
        let trimmed = dsn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("your-sentry-dsn") else { return }

        SentrySDK.start { options in
            options.dsn = trimmed
            options.enableCaptureFailedRequests = false
        }
    }
}
