import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import NotionKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A SwiftUI view that displays a list of Notion pages and allows users to connect to Notion.
public struct NotionPagesView: View {
    // MARK: - Properties
    
    /// The Notion client manager
    @ObservedObject private var clientManager: NotionClientManager
    
    /// The redirect URI for OAuth
    private let redirectURI: String
    
    /// Whether to show only the connection button
    private let showConnectionOnly: Bool
    
    /// Action to perform when a page is selected
    private let onPageSelected: ((NotionPage) -> Void)?
    
    // MARK: - Initialization
    
    /// Initialize a new Notion pages view
    /// - Parameters:
    ///   - clientManager: The Notion client manager
    ///   - redirectURI: The redirect URI for OAuth
    ///   - showConnectionOnly: Whether to show only the connection button
    ///   - onPageSelected: Action to perform when a page is selected
    public init(
        clientManager: NotionClientManager,
        redirectURI: String,
        showConnectionOnly: Bool = false,
        onPageSelected: ((NotionPage) -> Void)? = nil
    ) {
        self.clientManager = clientManager
        self.redirectURI = redirectURI
        self.showConnectionOnly = showConnectionOnly
        self.onPageSelected = onPageSelected
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
            
            if clientManager.pages.isEmpty {
                emptyPagesView
            } else {
                pagesListView
            }
        }
        .padding()
        .onAppear {
            if clientManager.pages.isEmpty {
                clientManager.fetchPages()
            }
        }
    }
    
    private var unauthenticatedView: some View {
        VStack(spacing: 16) {
            Text("Connect to your Notion account to access your pages")
                .multilineTextAlignment(.center)
                .padding()
            
            connectButton
                .padding()
        }
        .padding()
    }
    
    @ViewBuilder
    private var pagesListView: some View {
        List {
            ForEach(clientManager.pages) { page in
                pageRow(page)
            }
        }
        #if os(iOS)
        .listStyle(InsetGroupedListStyle())
        #else
        .listStyle(DefaultListStyle())
        #endif
    }
    
    private func pageRow(_ page: NotionPage) -> some View {
        Button(action: {
            onPageSelected?(page)
        }) {
            HStack {
                VStack(alignment: .leading) {
                    // Since pages might not have a title property directly accessible,
                    // we use the URL which is always available
                    Text(page.url.split(separator: "/").last ?? "Untitled")
                        .font(.headline)
                    
                    Text(page.url)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var emptyPagesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No pages found")
                .font(.headline)
            
            Text("Create a page in Notion and make sure the connected integration has access to it.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: {
                clientManager.fetchPages()
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

// MARK: - Preview

struct NotionPagesView_Previews: PreviewProvider {
    static var previews: some View {
        let clientManager = NotionClientManager(
            apiServerURL: URL(string: "https://example.com")!,
            clientId: "test-client-id"
        )
        
        return NotionPagesView(
            clientManager: clientManager,
            redirectURI: "https://example.com/callback",
            onPageSelected: { _ in }
        )
    }
} 