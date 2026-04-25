import SwiftUI

/// Placeholder view shown when there are no upcoming events to display.
struct NoAccountsView: View {
    
    var onManageAccount: (() -> Void)?
    
    var body: some View {
            ContentUnavailableView {
                Label("No Accounts", systemImage: "person.crop.circle.badge.plus")
            } description: {
                Text("Add a Google account to see your calendar events.")
            } actions: {
                if onManageAccount != nil {
                    Button { onManageAccount!() }
                    label: {
                        Label("Manage acocunt", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .eventHoverEffect()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 600)
        .padding()
    }
}


#Preview {
    NoAccountsView()
}

#Preview {
    NoAccountsView(onManageAccount: { })
}
