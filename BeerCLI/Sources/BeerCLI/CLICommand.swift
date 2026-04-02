//  Created by Alexander Skorulis on 2/4/2026.

import ArgumentParser
import Foundation

@main
struct CLICommand: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "cli",
        abstract: "Helpful commands to run tools in the app",
        subcommands: []
    )
    
}

