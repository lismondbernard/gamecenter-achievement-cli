// GameCenterAchievementCLI.swift
// A command-line tool to automate GameCenter achievement creation
//
// Usage: swift run GameCenterCLI create-batch ~/achievements.json

import Foundation

// MARK: - CLI Configuration

struct CLIConfig: Codable {
    let issuerId: String
    let apiKeyId: String
    let privateKeyPath: String
    let appId: String
}

// MARK: - Command Line Arguments Parser

enum CLICommand {
    case create(name: String, vendorId: String, points: Int, imagePath: String?)
    case createFromJSON(String)
    case list
    case deleteAll
    case help
}

class CLIArgumentParser {
    static func parse(_ args: [String]) -> CLICommand {
        guard args.count > 1 else {
            return .help
        }

        let command = args[1]

        switch command {
        case "create":
            return parseCreateCommand(Array(args.dropFirst(2)))
        case "create-batch":
            if args.count > 2 {
                return .createFromJSON(args[2])
            }
            return .help
        case "list":
            return .list
        case "delete-all":
            return .deleteAll
        default:
            return .help
        }
    }

    private static func parseCreateCommand(_ args: [String]) -> CLICommand {
        var name: String?
        var vendorId: String?
        var points: Int = 10
        var imagePath: String?

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--name":
                if i + 1 < args.count {
                    name = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--vendor-id":
                if i + 1 < args.count {
                    vendorId = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--points":
                if i + 1 < args.count, let p = Int(args[i + 1]) {
                    points = p
                    i += 2
                } else {
                    i += 1
                }
            case "--image":
                if i + 1 < args.count {
                    imagePath = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            default:
                i += 1
            }
        }

        guard let name = name, let vendorId = vendorId else {
            return .help
        }

        return .create(name: name, vendorId: vendorId, points: points, imagePath: imagePath)
    }
}

// MARK: - CLI Main Application

class GameCenterAchievementCLI {
    private let configPath: String
    private var config: CLIConfig?

    init(configPath: String = "~/.gamecenter-cli-config.json") {
        self.configPath = (configPath as NSString).expandingTildeInPath
    }

    func run(_ command: CLICommand) async {
        // Load configuration
        guard loadConfiguration() else {
            print("[ERROR] Failed to load configuration from \(configPath)")
            print("Create a config file with: issuerId, apiKeyId, privateKeyPath, appId")
            return
        }

        guard let config = self.config else {
            print("[ERROR] Configuration not loaded")
            return
        }

        let automationConfig = GameCenterAutomationConfig(
            issuerId: config.issuerId,
            apiKeyId: config.apiKeyId,
            privateKeyPath: config.privateKeyPath,
            appId: config.appId
        )

        let automation = GameCenterAchievementAutomation(config: automationConfig)

        switch command {
        case .create(let name, let vendorId, let points, _):
            await createAchievement(
                automation: automation,
                name: name,
                vendorId: vendorId,
                points: points
            )

        case .createFromJSON(let jsonPath):
            await createFromJSON(automation: automation, jsonPath: jsonPath)

        case .list:
            print("[ERROR] List command not yet implemented")

        case .deleteAll:
            await deleteAllAchievements(automation: automation)

        case .help:
            printHelp()
        }
    }

    // MARK: - Private Methods

    private func loadConfiguration() -> Bool {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            let decoder = JSONDecoder()
            config = try decoder.decode(CLIConfig.self, from: data)
            return true
        } catch {
            print("[ERROR] Config load error: \(error.localizedDescription)")
            return false
        }
    }

    private func createAchievement(
        automation: GameCenterAchievementAutomation,
        name: String,
        vendorId: String,
        points: Int
    ) async {
        print("Creating achievement: \(name)")

        do {
            // Create achievement
            print("  - Creating achievement...")
            let achievement = try await automation.createAchievement(
                referenceName: name,
                vendorIdentifier: vendorId,
                pointValue: points,
                isSecret: false,
                canRepeat: false
            )
            print("  [OK] Achievement created (ID: \(achievement.data.id))")

            // Add English localization
            print("  - Adding English localization...")
            _ = try await automation.addLocalization(
                achievementId: achievement.data.id,
                locale: "en-US",
                name: name,
                beforeEarnedDescription: "Earn \(name)",
                afterEarnedDescription: "You've earned \(name)!"
            )
            print("  [OK] English localization added")

            print("")
            print("[SUCCESS] Achievement created!")
            print("   ID: \(achievement.data.id)")
            print("   Vendor ID: \(vendorId)")
            print("   Points: \(points)")

        } catch {
            print("")
            print("[FAIL] Failed to create achievement: \(error.localizedDescription)")
        }
    }

    private func createFromJSON(automation: GameCenterAchievementAutomation, jsonPath: String) async {
        let expandedPath = (jsonPath as NSString).expandingTildeInPath

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
            let decoder = JSONDecoder()
            let achievements = try decoder.decode([AchievementData].self, from: data)

            print("Creating \(achievements.count) achievements from \(jsonPath)")
            print("")

            await automation.createAchievementsBatch(achievements: achievements)

        } catch {
            print("[ERROR] Failed to read or parse JSON: \(error.localizedDescription)")
        }
    }

    private func deleteAllAchievements(automation: GameCenterAchievementAutomation) async {
        print("Fetching all achievements...")
        print("")

        do {
            let achievements = try await automation.fetchAllAchievements()

            if achievements.isEmpty {
                print("[INFO] No achievements found to delete.")
                return
            }

            print("Found \(achievements.count) achievement(s):")
            print("")
            for (index, achievement) in achievements.enumerated() {
                let name = achievement.referenceName ?? "Unknown"
                let vendorId = achievement.vendorIdentifier ?? "Unknown"
                print("  \(index + 1). \(name) (\(vendorId))")
            }
            print("")

            // Require explicit confirmation
            print("========================================")
            print("WARNING: This will permanently delete ALL \(achievements.count) achievements!")
            print("This action cannot be undone.")
            print("========================================")
            print("")
            print("Type 'yes' to confirm deletion: ", terminator: "")

            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
                  input.lowercased() == "yes" else {
                print("")
                print("[ABORTED] Deletion cancelled. No achievements were deleted.")
                return
            }

            print("")
            print("Deleting achievements...")
            print("")

            await automation.deleteAllAchievements(achievements: achievements)

        } catch {
            print("[ERROR] Failed to fetch achievements: \(error.localizedDescription)")
        }
    }

    private func printHelp() {
        print("""
        GameCenter Achievement Automation CLI

        USAGE:
            GameCenterCLI <command> [options]

        COMMANDS:
            create          Create a single achievement
            create-batch    Create multiple achievements from JSON file
            list            List all achievements (not yet implemented)
            delete-all      Delete ALL achievements (requires confirmation)
            help            Show this help message

        OPTIONS FOR 'create':
            --name <name>              Achievement name (required)
            --vendor-id <id>           Vendor identifier (required)
            --points <number>          Point value (default: 10)

        EXAMPLES:
            # Create a simple achievement
            GameCenterCLI create --name "First Player" --vendor-id "com.game.first_player"

            # Create achievement with points
            GameCenterCLI create \\
                --name "Speed Demon" \\
                --vendor-id "com.game.speed_demon" \\
                --points 25

            # Create multiple from JSON
            GameCenterCLI create-batch ~/achievements.json

            # Delete all achievements (with confirmation)
            GameCenterCLI delete-all

        CONFIGURATION:
            Create a config file at ~/.gamecenter-cli-config.json:

            {
              "issuerId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
              "apiKeyId": "ABCD1234XY",
              "privateKeyPath": "~/.appstoreconnect/AuthKey_ABCD1234XY.p8",
              "appId": "123456789"
            }

        JSON BATCH FILE FORMAT:
            [
              {
                "name": "First Player",
                "vendorIdentifier": "com.game.first_player",
                "points": 5,
                "isSecret": false,
                "localizations": [
                  {
                    "locale": "en-US",
                    "name": "First Player",
                    "beforeDescription": "Play your first game",
                    "afterDescription": "You've played your first game!"
                  }
                ]
              }
            ]
        """)
    }
}
