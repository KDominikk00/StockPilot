import SwiftUI

struct QuoteBadge: View {
    let ticker: String

    @State private var quote: Quote?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let quote {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(quote.price, format: .number.precision(.fractionLength(2)))
                        .font(.body.monospacedDigit())
                    Text(changeText(quote.changePercent))
                        .font(.caption)
                        .foregroundStyle(quote.changePercent >= 0 ? .green : .red)
                }
            } else if isLoading {
                ProgressView().controlSize(.small)
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: ticker) {
            isLoading = true
            quote = await QuoteService.shared.quote(forTicker: ticker)
            isLoading = false
        }
    }

    private func changeText(_ percent: Double) -> String {
        String(format: "%+.2f%%", percent)
    }
}
