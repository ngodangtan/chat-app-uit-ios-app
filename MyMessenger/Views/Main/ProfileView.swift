import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var userName: String = ""
    @State private var email: String = ""
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.accentColor)
                .padding(.top, 32)

            Text(userName)
                .font(.title2)
                .bold()

            Text(email)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
            Button("Log Out") {
                auth.logout()
            }
        }
        .padding()
        .navigationTitle("Profile")
        .task {
            Task {
                let profile = try? await auth.getProfile()
                userName = profile?.username ?? ""
                email = profile?.email ?? ""
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { ProfileView() }
    }
}
