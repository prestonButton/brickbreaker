//
//  ContentView.swift
//  App
//
//  Created by Alex Oakley on 12/5/23.
//

import Brickbreaker
import SwiftUI

let bridge = GameTriumphBridge {
    BreakerViewController()
}

struct ContentView: View {
    var body: some View {
        VStack {
            Button("Start game") {
                bridge.window = UIApplication.shared.keyWindow
                bridge.startGame()
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
