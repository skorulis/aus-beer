//  Created by Alexander Skorulis on 3/4/2026.

import SwiftUI

private let danMurphysBeerListURL = URL(string: "https://www.danmurphys.com.au/beer/all")!

struct ContentView: View {
    var body: some View {
        WebView(url: danMurphysBeerListURL)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
