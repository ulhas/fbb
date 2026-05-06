import SwiftUI

struct ErrorCard: View {
    let title: String
    let message: String?
    let isRetryable: Bool
    let retry: () -> Void

    init(
        title: String = "Couldn't load",
        message: String? = nil,
        isRetryable: Bool = true,
        retry: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.isRetryable = isRetryable
        self.retry = retry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label {
                Text(title).font(.fbb.bodyBold).foregroundStyle(Color.semanticError)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.semanticError)
            }

            if let message {
                Text(message)
                    .font(.fbb.caption)
                    .foregroundStyle(Color.inkSecondary)
            }

            if isRetryable {
                Button("Retry", action: retry)
                    .buttonStyle(.bordered)
                    .tint(.fbbOrange)
                    .padding(.top, Spacing.xxs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
