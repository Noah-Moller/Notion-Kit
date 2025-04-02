//
//  NotionExampleView.swift
//  T-Cal
//
//  Created by Noah Moller on 23/3/2025.
//

import SwiftUI
import NotionKitClient
import NotionKit

// Example NotionExampleView for T-Cal

struct NotionPageDetailView: View {
    let page: NotionPage
    let clientManager: NotionClientManager
    @State private var blocks: [NotionBlock] = []
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading page...")
            } else if let error = error {
                VStack {
                    Text("Error loading page")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error.localizedDescription as String)
                        .font(.subheadline)
                    Button("Retry") {
                        _Concurrency.Task {
                            await loadPageContent()
                        }
                    }
                    .padding()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(page.properties["title"] ?? "Untitled")
                            .font(.title)
                            .bold()
                        
                        ForEach(blocks, id: \.id) { block in
                            NotionBlockView(block: block, clientManager: clientManager)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(page.properties["title"] ?? "Page Details")
        .task {
            await loadPageContent()
        }
    }
    
    private func loadPageContent() async {
        isLoading = true
        error = nil
        
        do {
            await clientManager.fetchPageBlocks(pageId: page.id)
            blocks = clientManager.pageBlocks
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
}

struct NotionBlockView: View {
    let block: NotionBlock
    let clientManager: NotionClientManager
    @State private var childBlocks: [NotionBlock] = []
    @State private var isLoading = false
    @State private var isExpanded = false
    @State private var error: Error?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
            
            if block.has_children {
                if isExpanded {
                    if isLoading {
                        ProgressView()
                            .padding(.leading)
                    } else if let error = error {
                        Text("Error loading children: \(error.localizedDescription)")
                            .foregroundColor(.red)
                            .padding(.leading)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(childBlocks, id: \.id) { childBlock in
                                NotionBlockView(block: childBlock, clientManager: clientManager)
                                    .padding(.leading)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var content: some View {
        VStack(alignment: .leading) {
            switch block.type {
            case "paragraph":
                if let text = block.paragraph?.rich_text {
                    richText(text)
                }
            case "heading_1":
                if let text = block.heading_1?.rich_text {
                    richText(text)
                        .font(.title)
                        .bold()
                }
            case "heading_2":
                if let text = block.heading_2?.rich_text {
                    richText(text)
                        .font(.title2)
                        .bold()
                }
            case "heading_3":
                if let text = block.heading_3?.rich_text {
                    richText(text)
                        .font(.title3)
                        .bold()
                }
            case "bulleted_list_item":
                if let text = block.bulleted_list_item?.rich_text {
                    HStack(alignment: .top) {
                        Text("•")
                        richText(text)
                    }
                }
            case "numbered_list_item":
                if let text = block.numbered_list_item?.rich_text {
                    HStack(alignment: .top) {
                        Text("\(block.numbered_list_item?.rich_text.count ?? 1).")
                        richText(text)
                    }
                }
            case "to_do":
                if let todo = block.to_do {
                    HStack {
                        Image(systemName: todo.checked ? "checkmark.square.fill" : "square")
                            .foregroundColor(todo.checked ? .blue : .gray)
                        richText(todo.rich_text)
                    }
                }
            case "toggle":
                if let toggle = block.toggle {
                    DisclosureGroup(isExpanded: $isExpanded) {
                        if isLoading {
                            ProgressView()
                                .padding(.leading)
                        } else if let error = error {
                            Text("Error loading children: \(error.localizedDescription)")
                                .foregroundColor(.red)
                                .padding(.leading)
                        } else if childBlocks.isEmpty && block.has_children {
                            Text("Loading...")
                                .foregroundColor(.secondary)
                                .padding(.leading)
                                .onAppear {
                                    _Concurrency.Task {
                                        await loadChildBlocks()
                                    }
                                }
                        } else if childBlocks.isEmpty {
                            Text("No content")
                                .foregroundColor(.secondary)
                                .padding(.leading)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(childBlocks, id: \.id) { childBlock in
                                    NotionBlockView(block: childBlock, clientManager: clientManager)
                                        .padding(.leading)
                                }
                            }
                        }
                    } label: {
                        richText(toggle.rich_text)
                    }
                    .onChange(of: isExpanded) { newValue in
                        print("Toggle expanded: \(newValue), has children: \(block.has_children), child blocks count: \(childBlocks.count)")
                        if newValue && block.has_children && childBlocks.isEmpty {
                            _Concurrency.Task {
                                print("Loading child blocks for \(block.id)")
                                await loadChildBlocks()
                            }
                        }
                    }
                }
            case "code":
                if let code = block.code {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(code.language.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            richText(code.rich_text)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                }
            case "image":
                if let image = block.image,
                   let url = image.url {
                    AsyncImage(url: URL(string: url)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(8)
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundColor(.red)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxHeight: 300)
                }
            case "divider":
                Divider()
            case "callout":
                if let callout = block.callout {
                    HStack(alignment: .top, spacing: 8) {
                        if callout.icon.type == "emoji" {
                            Text(callout.icon.emoji ?? "ℹ️")
                        }
                        richText(callout.rich_text)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            case "quote":
                if let quote = block.quote {
                    HStack {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 4)
                        richText(quote.rich_text)
                            .padding(.leading, 8)
                    }
                }
            case "table_of_contents":
                VStack(alignment: .leading, spacing: 4) {
                    Text("Table of Contents")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    if block.has_children {
                        DisclosureGroup(isExpanded: $isExpanded) {
                            if isLoading {
                                ProgressView()
                                    .padding(.leading)
                            } else if let error = error {
                                Text("Error loading contents: \(error.localizedDescription)")
                                    .foregroundColor(.red)
                                    .padding(.leading)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(childBlocks, id: \.id) { childBlock in
                                        NotionBlockView(block: childBlock, clientManager: clientManager)
                                            .padding(.leading)
                                    }
                                }
                            }
                        } label: {
                            Text("View Contents")
                                .foregroundColor(.blue)
                        }
                        .onChange(of: isExpanded) { newValue in
                            if newValue && childBlocks.isEmpty {
                                _Concurrency.Task {
                                    await loadChildBlocks()
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)

            case "unsupported":
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unsupported block type: \(block.unsupported?.originalType ?? block.type)")
                        .foregroundColor(.secondary)
                        .italic()
                    if block.has_children {
                        DisclosureGroup(isExpanded: $isExpanded) {
                            if isLoading {
                                ProgressView()
                                    .padding(.leading)
                            } else if let error = error {
                                Text("Error loading children: \(error.localizedDescription)")
                                    .foregroundColor(.red)
                                    .padding(.leading)
                            } else if childBlocks.isEmpty {
                                Text("Loading...")
                                    .foregroundColor(.secondary)
                                    .padding(.leading)
                                    .onAppear {
                                        Task {
                                            await loadChildBlocks()
                                        }
                                    }
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(childBlocks, id: \.id) { childBlock in
                                        NotionBlockView(block: childBlock, clientManager: clientManager)
                                            .padding(.leading)
                                    }
                                }
                            }
                        } label: {
                            Text("View Content")
                                .foregroundColor(.blue)
                        }
                        .onChange(of: isExpanded) { newValue in
                            if newValue && childBlocks.isEmpty {
                                Task {
                                    await loadChildBlocks()
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)

            default:
                Text("Unknown block type: \(block.type)")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .if(block.has_children && !["toggle", "table_of_contents", "image", "unsupported"].contains(block.type)) { view in
            view.onTapGesture {
                print("Block type: \(block.type), has_children: \(block.has_children)")
                if let unsupported = block.unsupported {
                    print("Unsupported block details - type: \(unsupported.originalType ?? "unknown"), raw data: \(unsupported.rawData ?? [:])")
                }
                isExpanded.toggle()
                if isExpanded && childBlocks.isEmpty {
                    Task {
                        await loadChildBlocks()
                    }
                }
            }
        }
    }
    
    private func richText(_ text: [RichTextItem]) -> Text {
        text.reduce(Text("")) { result, item in
            var content = Text(item.plain_text)
            
            // Apply annotations
            if item.annotations?.bold == true {
                content = content.bold()
            }
            if item.annotations?.italic == true {
                content = content.italic()
            }
            if item.annotations?.strikethrough == true {
                content = content.strikethrough()
            }
            if item.annotations?.underline == true {
                content = content.underline()
            }
            if item.annotations?.code == true {
                content = content.font(.system(.body, design: .monospaced))
            }
            
            // Apply color
            content = content.foregroundColor(color(from: item.annotations?.color ?? "default"))
            
            // Apply link formatting if it's a link
            if let href = item.href,
               let url = URL(string: href) {
                content = content.foregroundColor(.blue).underline()
            }
            
            return result + content
        }
    }
    
    private func color(from notionColor: String) -> Color {
        switch notionColor {
        case "gray": return .gray
        case "brown": return .brown
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "gray_background": return Color(.systemGray6)
        case "brown_background": return Color(.systemBrown).opacity(0.2)
        case "orange_background": return Color.orange.opacity(0.2)
        case "yellow_background": return Color.yellow.opacity(0.2)
        case "green_background": return Color.green.opacity(0.2)
        case "blue_background": return Color.blue.opacity(0.2)
        case "purple_background": return Color.purple.opacity(0.2)
        case "pink_background": return Color.pink.opacity(0.2)
        case "red_background": return Color.red.opacity(0.2)
        default: return .primary
        }
    }
    
    private func loadChildBlocks() async {
        isLoading = true
        error = nil
        
        do {
            print("Starting to load child blocks for block \(block.id) of type \(block.type)")
            childBlocks = try await clientManager.fetchChildBlocks(blockId: block.id)
            print("Successfully loaded \(childBlocks.count) child blocks for block type \(block.type)")
            print("Child block types: \(childBlocks.map { $0.type }.joined(separator: ", "))")
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
            print("Error loading child blocks for \(block.id) of type \(block.type): \(error)")
            print("Error details: \(String(describing: error))")
        }
    }
}

// Helper extension for conditional modifiers
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct NotionExampleView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var selectedTab = 0
    @State private var showingPage = false
    @State private var selectedPage: NotionPage?
    
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
                            selectedPage = page
                            showingPage = true
                        }
                    )
                }
            }
            .navigationTitle(selectedTab == 0 ? "Notion Databases" : "Notion Pages")
            .sheet(isPresented: $showingPage) {
                if let page = selectedPage {
                    NavigationView {
                        NotionPageBlocksView(
                            clientManager: appModel.notionClient,
                            page: page
                        )
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingPage = false
                                }
                            }
                        }
                    }
                }
            }
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

#Preview {
    NotionExampleView()
        .environmentObject(AppModel()) // You would need to define AppModel with notionClient
}
