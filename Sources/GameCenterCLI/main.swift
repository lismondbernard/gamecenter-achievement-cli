import Foundation

// Main entry point
let args = CommandLine.arguments
let command = CLIArgumentParser.parse(args)
let cli = GameCenterAchievementCLI()

await cli.run(command)
