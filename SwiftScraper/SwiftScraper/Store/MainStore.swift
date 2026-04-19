//  Created by Alex Skorulis on 19/4/2026.

import ASKCore
import Combine
import Knit
import KnitMacros
import Foundation

final class MainStore: ObservableObject {
    
    private static let settingsKey = "MainStore.settings.v1"
    
    @Published var settings: Settings {
        didSet {
            try! keyValueStore.set(codable: settings, forKey: Self.settingsKey)
        }
    }
    
    private let keyValueStore: PKeyValueStore
    
    @Resolvable<Resolver>
    init(keyValueStore: PKeyValueStore) {
        self.keyValueStore = keyValueStore
        settings = (try? keyValueStore.codable(forKey: Self.settingsKey)) ?? .init()
    }
}
