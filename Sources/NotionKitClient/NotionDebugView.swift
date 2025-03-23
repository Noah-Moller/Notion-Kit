import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct NotionDebugView: View {
    @ObservedObject var clientManager: NotionClientManager
    @State private var serverStatus: String = "Unknown"
    @State private var isCheckingServer: Bool = false
    @State private var errorMessage: String?
    
    public init(clientManager: NotionClientManager) {
        self.clientManager = clientManager
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Notion API Diagnostics")
                    .font(.title)
                    .fontWeight(.bold)
                
                Group {
                    Text("Configuration")
                        .font(.headline)
                    
                    HStack {
                        Text("Server URL:")
                        Text(clientManager.serverURL.absoluteString)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("User ID:")
                        Text(clientManager.getUserId())
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Is Authenticated:")
                        Text(clientManager.isAuthenticated ? "Yes" : "No")
                            .foregroundColor(clientManager.isAuthenticated ? .green : .red)
                    }
                }
                
                Group {
                    Text("Server Status")
                        .font(.headline)
                    
                    HStack {
                        Text("Status:")
                        Text(serverStatus)
                            .foregroundColor(serverStatusColor)
                    }
                    
                    if let errorMessage = errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Button(action: checkServerStatus) {
                        HStack {
                            if isCheckingServer {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                            Text(isCheckingServer ? "Checking..." : "Check Server Status")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isCheckingServer)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            checkServerStatus()
        }
    }
    
    private var serverStatusColor: Color {
        switch serverStatus {
        case "Online":
            return .green
        case "Offline":
            return .red
        default:
            return .orange
        }
    }
    
    private func checkServerStatus() {
        guard !isCheckingServer else { return }
        
        isCheckingServer = true
        serverStatus = "Checking..."
        errorMessage = nil
        
        // Create server URL
        let checkURL = clientManager.serverURL.appendingPathComponent("health")
        print("Checking server status at: \(checkURL.absoluteString)")
        
        // Perform basic connectivity check
        let task = URLSession.shared.dataTask(with: checkURL) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.serverStatus = "Offline"
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    print("Server connectivity error: \(error)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    self.serverStatus = httpResponse.statusCode < 400 ? "Online" : "Error"
                    if httpResponse.statusCode >= 400 {
                        self.errorMessage = "HTTP Status: \(httpResponse.statusCode)"
                    }
                    print("Server responded with status code: \(httpResponse.statusCode)")
                } else {
                    self.serverStatus = "Unknown"
                    self.errorMessage = "Received non-HTTP response"
                    print("Received non-HTTP response")
                }
                self.isCheckingServer = false
            }
        }
        task.resume()
        
        // Also try a test connection to the pages endpoint
        let pagesURL = clientManager.serverURL.appendingPathComponent("notion/pages")
        var components = URLComponents(url: pagesURL, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "user_id", value: clientManager.getUserId())]
        
        if let url = components.url {
            print("Also testing pages endpoint at: \(url.absoluteString)")
            let pagesTask = URLSession.shared.dataTask(with: url) { _, response, error in
                if let error = error {
                    print("Pages endpoint error: \(error)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("Pages endpoint status: \(httpResponse.statusCode)")
                }
            }
            pagesTask.resume()
        }
    }
}

struct NotionDebugView_Previews: PreviewProvider {
    static var previews: some View {
        NotionDebugView(
            clientManager: NotionClientManager(
                apiServerURL: URL(string: "https://example.com")!,
                clientId: "test-client-id"
            )
        )
    }
} 