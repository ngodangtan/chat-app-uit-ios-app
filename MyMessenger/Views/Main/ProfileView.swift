import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.accentColor)
                .padding(.top, 32)

            Text("User Name")
                .font(.title2)
                .bold()

            Text("user@example.com")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
            Button("Log Out") {
                auth.logout()
            }
        }
        .padding()
        .navigationTitle("Profile")
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { ProfileView() }
    }
}
