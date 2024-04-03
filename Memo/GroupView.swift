//
//  CardSlotView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/03/10.
//

import SwiftUI

struct GroupView: View {
    
    @Binding var deck: DeckData
    
    @State private var isPresenting = false
    
    var body: some View {
        
        
        ZStack{
            VStack{
                
                List{
                    
                    Section{
                        ForEach(deck.cardList) { card in
                            CardRaw(card: card)
                        }
                        .onDelete(perform: deleteCard)
                    } header: {
                        if deck.cardList.isEmpty {
                            Text("This deck is empty. Add some cards to start practicing!")
                        }
                    }
                    
                    Button (
                        action: openAddCardView,
                        label: { Label("Add", systemImage: "plus") }
                    )
                }
                
                .sheet(
                    isPresented: $isPresenting,
                    onDismiss: onDismiss,
                    content: { AddCardView(action: addCard)  }
                )
                
                
            }
            
            VStack{
                Spacer()
                Button(action: {
                    // Put the navigation code inside the closure
                }) {
                    NavigationLink(destination: FlashCardsView(deck: $deck)) {
                        Text("PRACTICE")
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(50)
                            .bold()
                    }
                }
                .padding()
                
                
            }
        }
        
        .navigationTitle(deck.icon + " " + deck.name)
        .toolbar {
            
        }
    }
    
    func openAddCardView(){
        isPresenting = true
    }
    
    func addCard(newCard: CardData){
        withAnimation {
            deck.cardList.append(newCard)
        }
        
        MemoApp.saveDecksData()
    }
    
    func deleteCard(at offsets: IndexSet){
        withAnimation {
            deck.cardList.remove(atOffsets: offsets)
        }
        
        MemoApp.saveDecksData()
    }
    
    func onDismiss(){
        
    }
}

struct CardRaw: View {
    
    let card: CardData

    var body: some View {
        
        HStack {
            Text(card.frontText)
            
            Text(card.backText)
        }
    }
}

struct AddCardView: View {
    
    @Environment(\.dismiss) var dismiss
    
    let action: (CardData) -> Void
    
    @State private var frontText : String = ""
    @State private var backText : String = ""
    
    var body: some View {
        
        NavigationView {
            Form {
                
                Section{
                    TextField("Front", text: $frontText)
                    TextField("Back", text: $backText)
                }
                
                Section{
                    HStack{
                        Spacer()
                        
                        Button("Add", action: addCard)
                            .disabled(frontText.isEmpty||backText.isEmpty)
                        
                        Spacer()
                    }
                }
                
            }
            .navigationBarItems(leading: Button("Cancel", action: cancelDeck))
            .navigationBarTitle("New Card", displayMode: .inline)
        }
    }
    
    func addCard() {
        action(CardData(frontText: frontText, backText: backText))
        dismiss()
    }
    
    func cancelDeck(){
        dismiss()
    }
}

struct CardSlotView_Previews: PreviewProvider {
    static var previews: some View {
        
        let deck = DeckData(name: "My Deck", icon: "🤓", color: Color.red)
        deck.cardList.append(CardData(frontText: "Front1", backText: "Back1"))
        deck.cardList.append(CardData(frontText: "Front2", backText: "Back2"))
        return  NavigationView {GroupView(deck: .constant(deck))}
       
    }
}