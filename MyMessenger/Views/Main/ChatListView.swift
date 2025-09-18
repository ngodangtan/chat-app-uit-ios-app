import SwiftUI

struct ChatListView: View {
    let chats: [(name: String, last: String)] = [
        ("Alice", "Hey, how are you?"),
        ("Bob", "Let's catch up later."),
        ("Carol", "Check this out.")
    ]

    var body: some View {
        List {
            ForEach(0..<chats.count, id: \.self) { idx in
                NavigationLink(destination: Text("Chat with \(chats[idx].name)")) {
                    VStack(alignment: .leading) {
                        Text(chats[idx].name)
                            .font(.headline)
                        Text(chats[idx].last)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle("Chats")
    }
}

struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { ChatListView() }
    }
}
