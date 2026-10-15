import SwiftUI

/// Links to the published Privacy Policy and Terms of Service.
///
/// Google's OAuth verification requires the privacy policy to be reachable from
/// the app interface, not only from the homepage.
struct LegalLinksSection: View {

  var body: some View {
    Section {
      HStack {
        Text("Your calendar data stays on this Mac.")
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer()

        Link("Privacy Policy", destination: Links.privacyPolicy)
        Link("Terms", destination: Links.termsOfService)
      }
      .font(.caption)
    }
  }
}

#Preview {
  Form {
    LegalLinksSection()
  }
  .formStyle(.grouped)
}
