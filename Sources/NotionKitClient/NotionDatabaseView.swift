import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import NotionKit

/// A SwiftUI view that displays a list of Notion databases and allows users to connect to Notion.
public struct NotionDatabaseView: View {
    // MARK: - Properties
    
    /// The Notion client manager
    @ObservedObject private var clientManager: NotionClientManager
    
    /// The redirect URI for OAuth
    private let redirectURI: String
    
    /// Whether to show only the connection button
    private let showConnectionOnly: Bool
    
    /// Action to perform when a database is selected
    private let onDatabaseSelected: ((NotionDatabase) -> Void)?
    
    // MARK: - Initialization
    
    /// Initialize a new Notion database view
    /// - Parameters:
    ///   - clientManager: The Notion client manager
    ///   - redirectURI: The redirect URI for OAuth
    ///   - showConnectionOnly: Whether to show only the connection button
    ///   - onDatabaseSelected: Action to perform when a database is selected
    public init(
        clientManager: NotionClientManager,
        redirectURI: String,
        showConnectionOnly: Bool = false,
        onDatabaseSelected: ((NotionDatabase) -> Void)? = nil
    ) {
        self.clientManager = clientManager
        self.redirectURI = redirectURI
        self.showConnectionOnly = showConnectionOnly
        self.onDatabaseSelected = onDatabaseSelected
    }
    
    // MARK: - Body
    
    public var body: some View {
        content
            .overlay(loadingView)
            .alert(item: errorBinding) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.localizedDescription),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
    
    @ViewBuilder
    private var content: some View {
        if clientManager.isAuthenticated && !showConnectionOnly {
            authenticatedView
        } else {
            unauthenticatedView
        }
    }
    
    private var authenticatedView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Connected to Notion")
                    .font(.headline)
                Spacer()
                disconnectButton
            }
            .padding(.horizontal)
            
            if clientManager.databases.isEmpty {
                emptyDatabasesView
            } else {
                databaseListView
            }
        }
        .padding()
        .onAppear {
            if clientManager.databases.isEmpty {
                clientManager.loadDatabases()
            }
        }
    }
    
    private var unauthenticatedView: some View {
        VStack(spacing: 16) {
            Text("Connect to your Notion account to access your databases")
                .multilineTextAlignment(.center)
                .padding()
            
            connectButton
                .padding()
        }
        .padding()
    }
    
    @ViewBuilder
    private var databaseListView: some View {
        List {
            ForEach(clientManager.databases) { database in
                databaseRow(database)
            }
        }
        #if os(iOS)
        .listStyle(InsetGroupedListStyle())
        #else
        .listStyle(DefaultListStyle())
        #endif
    }
    
    private func databaseRow(_ database: NotionDatabase) -> some View {
        Button(action: {
            onDatabaseSelected?(database)
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(database.name)
                        .font(.headline)
                    
                    Text("Properties: \(database.properties.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var emptyDatabasesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No databases found")
                .font(.headline)
            
            Text("Create a database in Notion and make sure the connected integration has access to it.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: {
                clientManager.loadDatabases()
            }) {
                Text("Refresh")
                    .bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private var connectButton: some View {
        Button(action: {
            self.connectToNotion(clientManager: clientManager, redirectURI: redirectURI)
        }) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 20))
                Text("Connect to Notion")
                    .bold()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(10)
        }
    }
    
    private var disconnectButton: some View {
        Button(action: {
            clientManager.signOut()
        }) {
            Text("Disconnect")
                .foregroundColor(.red)
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        if clientManager.isLoading {
            ZStack {
                Color.black.opacity(0.2)
                    .edgesIgnoringSafeArea(.all)
                
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(30)
                    #if os(iOS)
                    .background(Color(.systemBackground))
                    #else
                    .background(Color(NSColor.windowBackgroundColor))
                    #endif
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
    }
    
    private var errorBinding: Binding<NSError?> {
        Binding<NSError?>(
            get: {
                clientManager.error as NSError?
            },
            set: { _ in
                let manager = clientManager
                DispatchQueue.main.async {
                    manager.resetError()
                }
            }
        )
    }
}

// MARK: - Error Extension

extension NSError: Identifiable {
    public var id: String {
        return "\(domain):\(code)"
    }
}

// MARK: - Preview

struct NotionDatabaseView_Previews: PreviewProvider {
    static var previews: some View {
        let clientManager = NotionClientManager(
            apiServerURL: URL(string: "https://example.com")!,
            clientId: "preview-client-id"
        )
        
        return NotionDatabaseView(
            clientManager: clientManager,
            redirectURI: "notion-app://oauth-callback"
        )
    }
} 