//
//  Test.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/04/02.
//

import Foundation
import SwiftUI

struct MyFirstView: View {
    
    var body: some View {
        
        NavigationStack{
            ZStack{
                
            }
            
            .navigationTitle("MyFirstView")
            .toolbar{
                ToolbarItem(placement: .bottomBar){
                    NavigationLink(destination: MySecondView()) {
                        Text("Second View")
                    }
                }
            }
        }
    }
}

struct MySecondView: View {
    var body: some View {
        VStack {
            Text("Hello")
        }
        .navigationTitle("Second View")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Text("?????")
            }
        }
    }
}

struct MyView_Previews: PreviewProvider {
    static var previews: some View {
        return  MyFirstView()
    }
}
