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

/// A SwiftUI view that displays the blocks of a Notion page
public struct NotionPageBlocksView: View {
    // MARK: - Properties
    
    /// The Notion client manager
    @ObservedObject private var clientManager: NotionClientManager
    
    /// The ID of the page to display
    private let pageId: String
    
    /// The title of the page
    private let pageTitle: String
    
    // MARK: - Initialization
    
    /// Initialize a new Notion page blocks view
    /// - Parameters:
    ///   - clientManager: The Notion client manager
    ///   - page: The Notion page to display
    public init(clientManager: NotionClientManager, page: NotionPage) {
        self.clientManager = clientManager
        self.pageId = page.id
        
        // Try to extract a title from the page
        if let title = page.url.split(separator: "/").last {
            self.pageTitle = String(title)
        } else {
            self.pageTitle = "Notion Page"
        }
    }
    
    // MARK: - Body
    
    public var body: some View {
        content
            .navigationTitle(pageTitle)
            .onAppear {
                if clientManager.selectedPageId != pageId || clientManager.pageBlocks.isEmpty {
                    clientManager.fetchPageBlocks(pageId: pageId)
                }
            }
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
        if clientManager.pageBlocks.isEmpty && !clientManager.isLoading {
            emptyPageView
        } else {
            pageBlocksView
        }
    }
    
    private var pageBlocksView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(clientManager.pageBlocks) { block in
                    blockView(for: block)
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func blockView(for block: NotionBlock) -> some View {
        switch block.type {
        case "paragraph":
            Text(block.content)
                .fixedSize(horizontal: false, vertical: true)
        
        case "heading_1":
            Text(block.content)
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
        
        case "heading_2":
            Text(block.content)
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)
        
        case "heading_3":
            Text(block.content)
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
        
        case "bulleted_list_item":
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                Text(block.content)
                    .fixedSize(horizontal: false, vertical: true)
            }
        
        case "numbered_list_item":
            HStack(alignment: .top, spacing: 8) {
                Text("1.")
                Text(block.content)
                    .fixedSize(horizontal: false, vertical: true)
            }
        
        case "to_do":
            if let todo = block.to_do {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: todo.checked ? "checkmark.square.fill" : "square")
                    Text(block.content)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        
        case "toggle":
            DisclosureGroup(
                content: {
                    Text("Toggle content would appear here if we had nested blocks")
                        .padding(.leading)
                },
                label: {
                    Text(block.content)
                        .fixedSize(horizontal: false, vertical: true)
                }
            )
        
        case "code":
            if let code = block.code {
                VStack(alignment: .leading, spacing: 4) {
                    Text(code.language)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(block.content)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        
        case "image":
            if let imageUrl = block.image?.url {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                    } else if phase.error != nil {
                        Text("Failed to load image")
                            .foregroundColor(.red)
                    } else {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            }
        
        case "divider":
            Divider()
        
        case "callout":
            if let callout = block.callout {
                HStack(alignment: .top, spacing: 8) {
                    if let emoji = callout.icon.emoji {
                        Text(emoji)
                            .font(.title2)
                    }
                    Text(block.content)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
        
        case "quote":
            HStack {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 4)
                Text(block.content)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 8)
        
        default:
            Text("Unsupported block type: \(block.type)")
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var emptyPageView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No content found")
                .font(.headline)
            
            Text("This page appears to be empty or the content couldn't be loaded.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: {
                clientManager.fetchPageBlocks(pageId: pageId)
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

#if DEBUG
struct NotionPageBlocksView_Previews: PreviewProvider {
    static var previews: some View {
        let clientManager = NotionClientManager(
            apiServerURL: URL(string: "https://example.com")!,
            clientId: "test-client-id"
        )
        
        let page = NotionPage(
            id: "page-id",
            url: "https://notion.so/workspace/Test-Page-123456",
            properties: [:]
        )
        
        return NavigationView {
            NotionPageBlocksView(
                clientManager: clientManager,
                page: page
            )
        }
    }
}
#endif 