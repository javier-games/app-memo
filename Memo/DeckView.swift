//
//  CardSlotView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/03/10.
//

import SwiftUI



struct DeckView: View {
    
    private enum Sheets{
        case None, AddCard, EditCard
    }
    
    @Binding var deck: DeckData
    
    @State private var isPresenting = false
    @State private var sheetSelection: Sheets = .None
    
    @State private var cardSelected : CardData = CardData(frontText: "", backText: "")
    
    
    var body: some View {
        
        
        ZStack{
            VStack{
                
                List{
                    
                    Section{
                        ForEach(deck.cardList) { card in
                            Button (
                                action: {
                                    openEditCardView(card: card)
                                },
                                label: {
                                    HStack {
                                        Text(card.backText)
                                        Spacer()
                                        Text(card.frontText).fontWeight(.light)
                                    }
                                }
                            )
                        }
                        .onDelete(perform: deleteCard)
                    } header: {
                        if deck.cardList.isEmpty || deck.cardList.count == 0 {
                            Text("This deck is empty. Add some cards to start practicing!")
                        }
                        else{
                            Spacer()
                        }
                    }
                    
                    Button (
                        action: openAddCardView,
                        label: { Label("Add", systemImage: "plus") }
                    )
                }
                
                .sheet(
                    isPresented: $isPresenting,
                    onDismiss: onDismiss
                ){
                    if sheetSelection == .AddCard {
                        AddCardView(action: addCard)
                    }
                    else if sheetSelection == .EditCard {
                        EditCardView(card: $cardSelected)
                    }
                }
                
                
            }
        }
        
        .navigationTitle(deck.icon + " " + deck.name)
        .toolbar {
            ToolbarItem(placement: .bottomBar){
                NavigationLink(destination: PracticeView(deck: $deck)) {
                    HStack(){
                        Image(systemName:"play.square.stack.fill")
                            .symbolEffect(.bounce.up.byLayer, value: isPresenting )
                        Text("Practice")
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 20)
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .offset(CGSize(width: 0, height: 5))
            }
        }
    }
    
    func openAddCardView(){
        sheetSelection = .AddCard
        isPresenting = true
    }
    
    func openEditCardView(card: CardData){
        sheetSelection = .EditCard
        cardSelected = card
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
        sheetSelection = .None
        print(sheetSelection)
    }
}



struct AddCardView: View {
    
    @Environment(\.dismiss) var dismiss
    
    let action: (CardData) -> Void
    
    @State private var frontText : String = ""
    @State private var frontHintText : String = ""
    @State private var backText : String = ""
    @State private var backHintText : String = ""
    
    var body: some View {
        
        NavigationView {
            Form {
                
                Section{
                    TextField("Back", text: $backText)
                    TextField("Hint", text: $backHintText)
                }
                
                Section{
                    TextField("Front", text: $frontText)
                    TextField("Hint", text: $frontHintText)
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
        action(CardData(frontText: frontText, backText: backText, frontHintText: frontHintText, backHintText: backHintText))
        dismiss()
    }
    
    func cancelDeck(){
        dismiss()
    }
}

struct EditCardView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @Binding var card : CardData
    
    @State private var frontText : String = ""
    @State private var frontHintText : String = ""
    @State private var backText : String = ""
    @State private var backHintText : String = ""

    
    var body: some View {
        
        NavigationView {
            Form {
                
                Section{
                    TextField("Back", text: $backText)
                    TextField("Hint", text: $backHintText)
                }
                
                Section{
                    TextField("Front", text: $frontText)
                    TextField("Hint", text: $frontHintText)
                }
                
                .onAppear(){
                    backText = card.backText
                    frontText = card.frontText
                    backHintText = card.backHintText
                    frontHintText = card.frontHintText
                }
                
                
                Section{
                    HStack{
                        Spacer()
                        
                        Button("Save", action: editCard)
                            .disabled(card.frontText.isEmpty||card.backText.isEmpty)
                        
                        Spacer()
                    }
                }
                
            }
            .navigationBarItems(leading: Button("Cancel", action: cancelDeck))
            .navigationBarTitle("Edit Card", displayMode: .inline)
        }
    }
    
    func editCard() {
        card.backText = backText
        card.frontText = frontText
        card.backHintText = backHintText
        card.frontHintText = frontHintText
        
        MemoApp.saveDecksData()
        
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
        return  NavigationView {DeckView(deck: .constant(deck))}
       
    }
}
