//
//  TextField.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 14/9/25.
//

import SwiftUI

struct InfoField_Preview: View {
    @State var fName = ""
    @State var lName = ""
    
    var body: some View {
        VStack(spacing: 50) {
            InfoField(title: "First Name", text: $fName)
            InfoField(title: "Last Name", text: $lName)
        }
        .padding()
    }
}

#Preview {
    InfoField_Preview()
}

struct InfoField: View {
    let title: String
    @Binding var text: String
    @FocusState var isTyping: Bool
    
    var body: some View {
        ZStack(alignment: .leading) {
            TextField("", text: $text)
                .padding(.leading)
                .frame(height: 55)
                .focused($isTyping)
                .background(
                    isTyping ?
                    Color.white :
                    Color.primary.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(lineWidth: 2)
                        .foregroundColor(isTyping ? .blue : .gray)
                )
            
            Text(title)
                .padding(.horizontal, 5)
                .background(.white.opacity(isTyping || !text.isEmpty ? 1 : 0))
                .foregroundStyle(isTyping ? .blue : Color.primary)
                .padding(.leading)
                .offset(y: isTyping || !text.isEmpty ? -27 : 0)
                .onTapGesture {
                    isTyping.toggle()
                }
        }
        .animation(.linear(duration: 0.2), value: isTyping)
    }
}
