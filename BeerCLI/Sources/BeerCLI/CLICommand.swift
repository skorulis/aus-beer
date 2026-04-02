//  Created by Alexander Skorulis on 2/4/2026.

import ArgumentParser
import Foundation

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
@main
struct CLICommand: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "BeerCLI",
        abstract: "Helpful commands to run tools in the app",
        subcommands: [
            ScrapeCommand.self,
        ]
    )
    
}

