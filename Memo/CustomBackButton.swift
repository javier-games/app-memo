//
//  CustomBackButton.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/03/31.
//

import Foundation
import SwiftUI

struct CustomBackButton: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        Button(action: {
            self.presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left")
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.blue) // Customize color as needed
        }
    }
}
