import SwiftUI
import NotionKit

/// A SwiftUI example view that demonstrates how to use both databases and pages from Notion
public struct NotionExampleView: View {
    @ObservedObject var notionClient: NotionClientManager
    @State private var selectedTab = 0
    
    private let redirectURI: String
    
    public init(notionClient: NotionClientManager, redirectURI: String) {
        self.notionClient = notionClient
        self.redirectURI = redirectURI
    }
    
    public var body: some View {
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
                        clientManager: notionClient,
                        redirectURI: redirectURI,
                        onDatabaseSelected: { database in
                            print("Selected database: \(database.name)")
                            database.properties.forEach { print($0.key) }
                        }
                    )
                } else {
                    NotionPagesView(
                        clientManager: notionClient,
                        redirectURI: redirectURI,
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

/// A simplified connect view for use in your app
public struct CustomConnectView: View {
    private let clientManager: NotionClientManager
    private let redirectURI: String
    
    public init(clientManager: NotionClientManager, redirectURI: String) {
        self.clientManager = clientManager
        self.redirectURI = redirectURI
    }
    
    public var body: some View {
        VStack {
            Text("Connect to your Notion account")
                .font(.headline)
            
            Button("Connect to Notion") {
                self.connectToNotion(
                    clientManager: clientManager,
                    redirectURI: redirectURI
                )
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}

#if DEBUG
struct NotionExampleView_Previews: PreviewProvider {
    static var previews: some View {
        let clientManager = NotionClientManager(
            apiServerURL: URL(string: "https://example.com")!,
            clientId: "test-client-id"
        )
        
        return NotionExampleView(
            notionClient: clientManager,
            redirectURI: "https://example.com/callback"
        )
    }
}
#endif 