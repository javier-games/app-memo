//
//  GroupsView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/03/27.
//

import Foundation
import SwiftUI

struct DecksView: View {
    
    @Binding var deckList: [DeckData]
    @State private var selectedDecksIds: Set<UUID> = []
    @State private var isPresenting = false
    
    var body: some View {
        
        NavigationStack {
            
            VStack{
            
                List{
                    
                    Section{
                        ForEach($deckList) { deck in
                            DeckRaw(deck: deck)
                        }
                        .onDelete(perform: deleteDeck)
                    } header: {
                        if deckList.isEmpty {
                            Text("Memo looks quite empty uh? Try adding some decks.")
                        }
                        else{
                            Spacer()
                        }
                    }
                    
                    Button (
                        action: openAddDeckView,
                        label: { Label("Add", systemImage: "plus") }
                    )
                }
                
                .sheet(
                    isPresented: $isPresenting,
                    onDismiss: onDismiss,
                    content: { AddDeckView(action: addDeck) }
                )
            }
            
            .navigationTitle("Decks")
        }
    }
    
    func openAddDeckView() {
        isPresenting = true
    }
    
    func onDismiss() {
        
    }
    
    func addDeck(newDeck: DeckData){
        withAnimation {
            deckList.append(newDeck)
        }
        
        MemoApp.saveDecksData()
    }
    
    func deleteDeck(at offsets: IndexSet) {
        withAnimation {
            deckList.remove(atOffsets: offsets)
        }
        
        MemoApp.saveDecksData()
    }
}

struct DeckRaw: View {
    
    @Binding var deck: DeckData

    var body: some View {
        
        NavigationLink(
            destination: DeckView(deck: $deck)
        ) {
            HStack {
                Text(deck.icon).frame(width: 30)
                Text(deck.name)
            }
        }
    }
}

struct AddDeckView: View {
    
    @Environment(\.dismiss) var dismiss
    
    let action: (DeckData) -> Void
    
    @State private var name : String = ""
    @State private var icon : String = ""
    @State private var color = Color.white
    
    var body: some View {
        
        NavigationView {
            Form {
                
                Section{
                    HStack{
                        
                        EmojiTextField(text: $icon, placeholder: "")
                            .frame(width: 30)
                            .onAppear(perform: setRandomEmoji)
                        
                        TextField("Name", text: $name)
                    }
                    
                    ColorPicker("Color", selection: $color)
                }
                
                Section{
                    HStack{
                        Spacer()
                        
                        Button("Add", action: addDeck)
                            .disabled(name.isEmpty)
                        
                        Spacer()
                    }
                }
                
            }
            .navigationBarItems(leading: Button("Cancel", action: cancelDeck))
            .navigationBarTitle("New Deck", displayMode: .inline)
        }
    }
    
    func addDeck() {
        action(DeckData(name: name, icon: icon, color: color))
        dismiss()
    }
    
    func cancelDeck(){
        dismiss()
    }
    
    func setRandomEmoji() {
        
        let emojis: [String] = [
            "✍️", "🗝️", "🔑", "📝",
            "✏️", "🖍️", "✒️", "🖊️",
            "😀", "🤯", "🤓", "🤔",
        ]
        
        let randomIndex = Int.random(in: 0..<emojis.count)
        $icon.wrappedValue = emojis[randomIndex]
    }
}

struct DeckListPreview: PreviewProvider {
    static var previews: some View {
        
        let dummyDeckData: [DeckData] = [
            DeckData(name: "My Deck", icon: "😂", color: Color.black)
        ]
        dummyDeckData[0].cardList.append(CardData(frontText: "Front1", backText: "Back1"))
        dummyDeckData[0].cardList.append(CardData(frontText: "Front2", backText: "Back2"))
        
        // Pass the dummy data to the DeckListView using a binding
        return DecksView(deckList: .constant(dummyDeckData))
    }
}
