//
//  Button.swift
//  nugg.xyz
//
//  Created by walter on 11/27/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import SwiftUI

enum MonoColor {
    case dark
    case light
}

struct Button<Content: View>: View {
    var background: MonoColor

    var content: () -> Content // change to closure

    var action: () -> Void

    init(background: MonoColor = .dark, action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.background = background
        self.content = content
        self.action = action
    }

    var body: some View {
        SwiftUI.Button(role: .none, action: {
            self.action()
        }) {
            Section {
                self.content()
            }
            .font(.system(.body, design: .rounded).weight(.heavy))
            .foregroundColor(self.background == .dark ? .white : .accentColor)
            .padding(.horizontal, 17)
            .padding(.vertical, 12)
            .background(self.background == .light ? .white : .accentColor)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.01), radius: 1, x: 0, y: 0)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 4, y: 0)
            .shadow(color: Color.black.opacity(0.04), radius: 24, x: 16, y: 0)
            .shadow(color: Color.black.opacity(0.01), radius: 32, x: 24, y: 0)
        }.border(.clear)
    }
}

struct Button_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Button(background: .light, action: {
                print("hi")
            }) {
                Text(verbatim: "Hello")
            }.padding(5.0).background(.primary)
            Button(action: {
                print("hi")
            }) {
                Text(verbatim: "12:43")
            }.padding(5.0).background(.white)
            Button(action: {
                print("hi")
            }) {
                Text(verbatim: "Hello")
            }.padding(5.0).background(.blue)
            Button(background: .dark, action: {
                print("hi")
            }) {
                Text(verbatim: "12:43")
            }.padding(5.0).background(.primary)
        }
    }
}
