//
//  CardSlotView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/03/10.
//

import SwiftUI

struct FlashCardsGroup: View {
    var body: some View {
        VStack () {
            // Navigation bar
             HStack {
                 Image(systemName: "chevron.left")
                 Text("Group Name")
                     .font(.headline)
                 Spacer()
                 Image(systemName: "line.horizontal.3")
             }
             .padding(.bottom, 10)
             .padding(.horizontal, 10)
             .background(Color.secondary)
             .foregroundColor(.white)
             
            Spacer()
             // Main content
             VStack(alignment: .leading, spacing: 8) {
                 HStack {
                     Text("Word")
                     Spacer()
                     Text("Desc.")
                 }
                 HStack {
                     Text("Long Word...")
                     Spacer()
                     Text("Desc-")
                 }
             }
             .padding()
             
             // Button
             ZStack {
                 Circle()
                     .foregroundColor(.green)
                     .frame(width: 80, height: 80)
                 Text("Practice!")
                     .foregroundColor(.white)
                     .font(.headline)
             }
             .padding()
         }
             
    }
}

struct CardSlotView_Previews: PreviewProvider {
    static var previews: some View {
        FlashCardsGroup()
    }
}
