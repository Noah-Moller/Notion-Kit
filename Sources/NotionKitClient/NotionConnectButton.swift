import SwiftUI
import NotionKit

public struct NotionConnectButton: View {
    let clientManager: NotionClientManager
    let onCompletion: () -> Void
    
    public init(clientManager: NotionClientManager, onCompletion: @escaping () -> Void) {
        self.clientManager = clientManager
        self.onCompletion = onCompletion
    }
    
    public var body: some View {
        Button {
            let baseURL = clientManager.apiServerURL.absoluteString
            guard let url = URL(string: "\(baseURL)/notion/authorize?user_id=\(clientManager.userId)") else { return }
            
            // Register for auth completion notification
            NotificationCenter.default.addObserver(
                forName: .notionAuthCompleted,
                object: nil,
                queue: .main
            ) { _ in
                onCompletion()
            }
            
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        } label: {
            HStack(spacing: 8) {
                Image("NotionLogo", bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                Text("Connect with Notion")
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
        }
    }
}

// MARK: - Notification Name
public extension Notification.Name {
    static let notionAuthCompleted = Notification.Name("notionAuthCompleted")
} 