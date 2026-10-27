import SwiftUI
import SafariServices

/// A filing link to show in the in-app reader. Only http(s) URLs are accepted:
/// SFSafariViewController refuses anything else.
struct ReaderLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }

    init?(string: String) {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        self.url = url
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

extension View {
    func readerSheet(item: Binding<ReaderLink?>) -> some View {
        sheet(item: item) { link in
            SafariView(url: link.url).ignoresSafeArea()
        }
    }
}
