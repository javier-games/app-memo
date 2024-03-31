//
//  SettingsView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/03/27.
//

import SwiftUI

enum AppearanceStyle {
    case dark, light, auto
}

struct SettingsView: View {
    
    
    @State private var profileImageSize = false
    @State private var fontSize: CGFloat = 5
    @State private var appearance: AppearanceStyle = .auto

    var body: some View {
        List {
            

            Section {
                Slider(value: $fontSize, in: 1...10) {
                    Label("Default Font Size", systemImage: "text.magnifyingglass")
                }

                Picker("Appearance", selection: $appearance) {
                    Text("Dark").tag(AppearanceStyle.dark)
                    Text("Light").tag(AppearanceStyle.light)
                    Text("Auto").tag(AppearanceStyle.auto)
                }
            } header: { Text("Appearance") }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("2.2.1")
                }
            } header: { Text("ABOUT") }
        }
    }
}

struct Settings_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
