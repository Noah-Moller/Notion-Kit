import SwiftUI

public struct NotionConnectButton: View {
    let userId: String
    let serverURL: String
    
    public init(userId: String, serverURL: String) {
        self.userId = userId
        self.serverURL = serverURL
    }
    
    public var body: some View {
        Button {
            guard let url = URL(string: "http://\(serverURL)/notion/authorize?user_id=\(userId)") else { return }
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