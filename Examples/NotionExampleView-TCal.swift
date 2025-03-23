import SwiftUI
import NotionKitClient

// Example NotionExampleView for T-Cal

struct NotionExampleView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("View", selection: $selectedTab) {
                    Text("Databases").tag(0)
                    Text("Pages").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if selectedTab == 0 {
                    NotionDatabaseView(
                        clientManager: appModel.notionClient,
                        redirectURI: "https://tetrix.tech/redirect.php",
                        onDatabaseSelected: { database in
                            print("Selected database: \(database.name)")
                            database.properties.forEach { print($0.key) }
                        }
                    )
                } else {
                    NotionPagesView(
                        clientManager: appModel.notionClient,
                        redirectURI: "https://tetrix.tech/redirect.php",
                        onPageSelected: { page in
                            print("Selected page: \(page.id)")
                            print("Page URL: \(page.url)")
                        }
                    )
                }
            }
            .navigationTitle(selectedTab == 0 ? "Notion Databases" : "Notion Pages")
        }
    }
}

struct CustomConnectView: View {
    @EnvironmentObject var appModel: AppModel
    
    var body: some View {
        VStack {
            Text("Connect to your Notion account")
                .font(.headline)
            
            Button("Connect to Notion") {
                self.connectToNotion(
                    clientManager: appModel.notionClient,
                    redirectURI: "https://tetrix.tech/redirect.php"
                )
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}

// MARK: - Extensions for connectToNotion

private func connectToNotion(clientManager: NotionClientManager, redirectURI: String) {
    #if os(macOS)
    // macOS implementation
    let url = clientManager.getAuthURL(redirectURI: redirectURI)
    NSWorkspace.shared.open(url)
    #else
    // iOS implementation
    let url = clientManager.getAuthURL(redirectURI: redirectURI)
    UIApplication.shared.open(url)
    #endif
}

// MARK: - Preview

#Preview {
    NotionExampleView()
        .environmentObject(AppModel()) // You would need to define AppModel with notionClient
} 