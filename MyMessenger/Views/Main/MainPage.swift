//
//  MainPage.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 14/9/25.
//

import SwiftUI

struct MainPage: View {
    var body: some View {
        TabView {
            NavigationView {
                ChatListView()
            }
            .tabItem {
                Label("Chats", systemImage: "bubble.left.and.bubble.right")
            }
            
            NavigationView {
                ListContactsPage()
            }
            .tabItem {
                Label("Contacts", systemImage: "person.2")
            }


            NavigationView {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
        }
    }
}

struct MainPage_Previews: PreviewProvider {
    static var previews: some View {
        MainPage()
    }
}
