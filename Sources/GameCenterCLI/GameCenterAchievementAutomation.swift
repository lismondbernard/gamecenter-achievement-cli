import Foundation
import AppStoreConnect_Swift_SDK

// MARK: - Configuration
struct GameCenterAutomationConfig {
    let issuerId: String
    let apiKeyId: String
    let privateKeyPath: String
    let appId: String
}

// MARK: - GameCenter Achievement Automation
class GameCenterAchievementAutomation {
    private let config: GameCenterAutomationConfig
    private var cachedGameCenterDetailId: String?

    private lazy var client: APIProvider = {
        let expandedPath = (config.privateKeyPath as NSString).expandingTildeInPath
        let privateKeyURL = URL(fileURLWithPath: expandedPath)

        let configuration = try! APIConfiguration(
            issuerID: config.issuerId,
            privateKeyID: config.apiKeyId,
            privateKeyURL: privateKeyURL
        )
        return APIProvider(configuration: configuration)
    }()

    init(config: GameCenterAutomationConfig) {
        self.config = config
    }

    // MARK: - Create Achievement
    /// Creates a new Game Center achievement
    /// - Parameters:
    ///   - referenceName: Internal reference name (e.g., "First Player")
    ///   - vendorIdentifier: Unique identifier (e.g., "com.game.achievement.first_player")
    ///   - pointValue: Point value for the achievement
    ///   - isSecret: Whether achievement is hidden until earned (showBeforeEarned = !isSecret)
    ///   - canRepeat: Whether achievement can be earned multiple times
    func createAchievement(
        referenceName: String,
        vendorIdentifier: String,
        pointValue: Int,
        isSecret: Bool = false,
        canRepeat: Bool = false
    ) async throws -> GameCenterAchievementResponse {
        // First, get the game center detail for the app
        let gameCenterDetailId = try await fetchGameCenterDetailId()

        // Create the achievement request
        let achievementRequest = GameCenterAchievementCreateRequest(
            data: .init(
                type: .gameCenterAchievements,
                attributes: .init(
                    referenceName: referenceName,
                    vendorIdentifier: vendorIdentifier,
                    points: pointValue,
                    isShowBeforeEarned: !isSecret,  // showBeforeEarned is the opposite of isSecret
                    isRepeatable: canRepeat
                ),
                relationships: .init(
                    gameCenterDetail: .init(
                        data: .init(
                            type: .gameCenterDetails,
                            id: gameCenterDetailId
                        )
                    )
                )
            )
        )

        // Create the request using the SDK's endpoint structure
        let request = APIEndpoint.v1.gameCenterAchievements.post(achievementRequest)
        return try await client.request(request)
    }

    // MARK: - Add Localization
    /// Adds language-specific localization for an achievement
    /// - Parameters:
    ///   - achievementId: ID of the achievement
    ///   - locale: Language locale (e.g., "en-US", "es-ES"). Will be auto-mapped to valid format.
    ///   - name: Achievement title in the specified language
    ///   - beforeEarnedDescription: Description shown before earning
    ///   - afterEarnedDescription: Description shown after earning
    func addLocalization(
        achievementId: String,
        locale: String,
        name: String,
        beforeEarnedDescription: String,
        afterEarnedDescription: String
    ) async throws -> GameCenterAchievementLocalizationResponse {
        // Map the locale to valid App Store Connect format
        let mappedLocale = LocaleMapper.mapToAppStoreLocale(locale)

        // Warn if the locale was mapped to a different value
        if mappedLocale != locale {
            print("    [INFO] Mapped locale '\(locale)' -> '\(mappedLocale)'")
        }

        // Validate the locale
        if !LocaleMapper.isValidLocale(mappedLocale) {
            print("    [WARNING] Locale '\(mappedLocale)' may not be valid for App Store Connect")
        }

        let localizationRequest = GameCenterAchievementLocalizationCreateRequest(
            data: .init(
                type: .gameCenterAchievementLocalizations,
                attributes: .init(
                    locale: mappedLocale,
                    name: name,
                    beforeEarnedDescription: beforeEarnedDescription,
                    afterEarnedDescription: afterEarnedDescription
                ),
                relationships: .init(
                    gameCenterAchievement: .init(
                        data: .init(
                            type: .gameCenterAchievements,
                            id: achievementId
                        )
                    )
                )
            )
        )

        let request = APIEndpoint.v1.gameCenterAchievementLocalizations.post(localizationRequest)
        return try await client.request(request)
    }

    // MARK: - Helper Methods

    private func fetchGameCenterDetailId() async throws -> String {
        // Return cached value if available
        if let cached = cachedGameCenterDetailId {
            return cached
        }

        // Fetch the GameCenterDetail for the app
        let request = APIEndpoint.v1.apps.id(config.appId).gameCenterDetail.get()
        let response: GameCenterDetailResponse = try await client.request(request)

        // Cache and return the ID
        cachedGameCenterDetailId = response.data.id
        return response.data.id
    }
}

// MARK: - Batch Achievement Creation
extension GameCenterAchievementAutomation {
    /// Creates multiple achievements from a data structure
    func createAchievementsBatch(
        achievements: [AchievementData]
    ) async {
        var successCount = 0
        var failCount = 0

        for (index, achievement) in achievements.enumerated() {
            do {
                print("[\(index + 1)/\(achievements.count)] Creating achievement: \(achievement.name)...")

                let achievementId: String

                do {
                    let createdAchievement = try await createAchievement(
                        referenceName: achievement.name,
                        vendorIdentifier: achievement.vendorIdentifier,
                        pointValue: achievement.points,
                        isSecret: achievement.isSecret
                    )
                    achievementId = createdAchievement.data.id
                } catch let error as APIProvider.Error {
                    // Check if this is a VENDOR_IDENTIFIER_DUPLICATE error
                    if case .requestFailure(_, let errorResponse, _) = error,
                       let errors = errorResponse?.errors,
                       errors.contains(where: { $0.code == "VENDOR_IDENTIFIER_DUPLICATE" }) {
                        // Achievement already exists, try to find it
                        print("  [INFO] Achievement already exists, fetching existing achievement...")

                        if let existingId = try await findAchievementId(byVendorIdentifier: achievement.vendorIdentifier) {
                            print("  [INFO] Found existing achievement with ID: \(existingId)")
                            achievementId = existingId
                        } else {
                            print("  [FAIL] Could not find existing achievement by vendor identifier")
                            failCount += 1
                            continue
                        }
                    } else {
                        throw error
                    }
                }

                // Add localizations
                var localizationSuccessCount = 0
                var localizationSkipCount = 0
                for localization in achievement.localizations {
                    do {
                        _ = try await addLocalization(
                            achievementId: achievementId,
                            locale: localization.locale,
                            name: localization.name,
                            beforeEarnedDescription: localization.beforeDescription,
                            afterEarnedDescription: localization.afterDescription
                        )
                        localizationSuccessCount += 1
                    } catch let error as APIProvider.Error {
                        // Check if localization already exists (ENTITY_ALREADY_EXISTS or similar)
                        if case .requestFailure(_, let errorResponse, _) = error,
                           let errors = errorResponse?.errors,
                           errors.contains(where: { $0.code == "ENTITY_ALREADY_EXISTS" || $0.code == "LOCALIZATION_DUPLICATE" }) {
                            print("    [SKIP] Localization for \(localization.locale) already exists")
                            localizationSkipCount += 1
                        } else {
                            // Log other localization errors but continue
                            print("    [WARN] Failed to add \(localization.locale) localization: \(error.localizedDescription)")
                        }
                    }
                }

                if localizationSkipCount > 0 {
                    print("  [OK] \(achievement.name) - \(localizationSuccessCount) localizations added, \(localizationSkipCount) skipped (already exist)")
                } else {
                    print("  [OK] \(achievement.name) created with \(localizationSuccessCount) localizations")
                }
                successCount += 1

                // Small delay to avoid rate limiting
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            } catch {
                print("  [FAIL] \(achievement.name): \(error.localizedDescription)")
                failCount += 1
            }
        }

        print("")
        print("========================================")
        print("Batch complete: \(successCount) succeeded, \(failCount) failed")
        print("========================================")
    }

    /// Fetches all achievements for the app and finds one by vendor identifier
    /// - Parameter vendorIdentifier: The vendor identifier to search for
    /// - Returns: The achievement ID if found, nil otherwise
    private func findAchievementId(byVendorIdentifier vendorIdentifier: String) async throws -> String? {
        let achievements = try await fetchAllAchievements()

        // Find the achievement with matching vendor identifier
        for achievement in achievements {
            if achievement.vendorIdentifier == vendorIdentifier {
                return achievement.id
            }
        }

        return nil
    }
}

// MARK: - Delete All Achievements
extension GameCenterAchievementAutomation {
    /// Represents an achievement with its key properties
    struct AchievementInfo {
        let id: String
        let referenceName: String?
        let vendorIdentifier: String?
        let points: Int?
    }

    /// Fetches all achievements for the app
    /// - Returns: Array of achievement info objects
    func fetchAllAchievements() async throws -> [AchievementInfo] {
        let gameCenterDetailId = try await fetchGameCenterDetailId()

        // Fetch all achievements for this Game Center detail
        let request = APIEndpoint.v1.gameCenterDetails.id(gameCenterDetailId).gameCenterAchievements.get(
            parameters: .init(
                fieldsGameCenterAchievements: [.vendorIdentifier, .referenceName, .points],
                limit: 200  // Fetch up to 200 achievements
            )
        )

        let response: GameCenterAchievementsResponse = try await client.request(request)

        return response.data.map { achievement in
            AchievementInfo(
                id: achievement.id,
                referenceName: achievement.attributes?.referenceName,
                vendorIdentifier: achievement.attributes?.vendorIdentifier,
                points: achievement.attributes?.points
            )
        }
    }

    /// Deletes all provided achievements
    /// - Parameter achievements: Array of achievements to delete
    func deleteAllAchievements(achievements: [AchievementInfo]) async {
        var successCount = 0
        var failCount = 0

        for (index, achievement) in achievements.enumerated() {
            let name = achievement.referenceName ?? "Unknown"
            print("[\(index + 1)/\(achievements.count)] Deleting: \(name)...")

            do {
                let request = APIEndpoint.v1.gameCenterAchievements.id(achievement.id).delete
                _ = try await client.request(request)
                print("  [OK] Deleted")
                successCount += 1

                // Small delay to avoid rate limiting
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            } catch {
                print("  [FAIL] \(error.localizedDescription)")
                failCount += 1
            }
        }

        print("")
        print("========================================")
        print("Deletion complete: \(successCount) deleted, \(failCount) failed")
        print("========================================")
    }
}

// MARK: - Locale Mapping
/// Maps locale codes from various formats to Apple's App Store Connect API format.
/// Valid locales: ar-SA, ca, cs, da, de-DE, el, en-AU, en-CA, en-GB, en-US, es-ES, es-MX,
/// fi, fr-CA, fr-FR, he, hi, hr, hu, id, it, ja, ko, ms, nl-NL, no, pl, pt-BR, pt-PT,
/// ro, ru, sk, sv, th, tr, uk, vi, zh-Hans, zh-Hant
enum LocaleMapper {
    /// Maps an input locale code to the valid App Store Connect API format.
    /// - Parameter inputLocale: The locale code from the JSON (e.g., "it-IT", "ja-JP")
    /// - Returns: The valid App Store Connect locale code (e.g., "it", "ja")
    static func mapToAppStoreLocale(_ inputLocale: String) -> String {
        // Dictionary of mappings from incorrect/alternative formats to valid ones
        let mappings: [String: String] = [
            // Italian: Apple uses "it" not "it-IT"
            "it-IT": "it",
            "it-it": "it",

            // Japanese: Apple uses "ja" not "ja-JP"
            "ja-JP": "ja",
            "ja-jp": "ja",

            // Korean: Apple uses "ko" not "ko-KR"
            "ko-KR": "ko",
            "ko-kr": "ko",

            // Other languages that only use language code (no region)
            "fi-FI": "fi",
            "sv-SE": "sv",
            "da-DK": "da",
            "no-NO": "no",
            "pl-PL": "pl",
            "tr-TR": "tr",
            "ru-RU": "ru",
            "cs-CZ": "cs",
            "sk-SK": "sk",
            "hu-HU": "hu",
            "ro-RO": "ro",
            "hr-HR": "hr",
            "uk-UA": "uk",
            "el-GR": "el",
            "he-IL": "he",
            "ar-AR": "ar-SA",
            "th-TH": "th",
            "vi-VN": "vi",
            "id-ID": "id",
            "ms-MY": "ms",
            "hi-IN": "hi",
            "ca-ES": "ca",

            // Ensure Chinese variants are correct
            "zh-CN": "zh-Hans",
            "zh-TW": "zh-Hant",
            "zh-HK": "zh-Hant",
        ]

        // Check if there's a mapping for this locale
        if let mappedLocale = mappings[inputLocale] {
            return mappedLocale
        }

        // Return as-is if already valid or unknown
        return inputLocale
    }

    /// List of all valid App Store Connect locale codes
    static let validLocales: Set<String> = [
        "ar-SA", "ca", "cs", "da", "de-DE", "el", "en-AU", "en-CA", "en-GB", "en-US",
        "es-ES", "es-MX", "fi", "fr-CA", "fr-FR", "he", "hi", "hr", "hu", "id",
        "it", "ja", "ko", "ms", "nl-NL", "no", "pl", "pt-BR", "pt-PT", "ro",
        "ru", "sk", "sv", "th", "tr", "uk", "vi", "zh-Hans", "zh-Hant"
    ]

    /// Validates if a locale code is valid for App Store Connect
    static func isValidLocale(_ locale: String) -> Bool {
        return validLocales.contains(locale)
    }
}

// MARK: - Data Models
struct AchievementData: Codable {
    let name: String
    let vendorIdentifier: String
    let points: Int
    let isSecret: Bool
    let localizations: [AchievementLocalization]
}

struct AchievementLocalization: Codable {
    let locale: String
    let name: String
    let beforeDescription: String
    let afterDescription: String
}
