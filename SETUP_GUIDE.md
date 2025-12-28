# GameCenter Achievement Automation Setup Guide

## Prerequisites

### 1. App Store Connect API Key Setup
1. Go to https://appstoreconnect.apple.com/access/integrations/api
2. Create a new API key with the following permissions:
   - **Game Center** (Full access)
   - **App Manager** (Read-only is fine, or Full for versioning)
3. Save your:
   - **Issuer ID** (UUID format)
   - **Key ID** (10 character alphanumeric)
   - **Private Key** (.p8 file) - keep this secure!

### 2. Swift Package Setup

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/AvdLee/appstoreconnect-swift-sdk.git", .upToNextMajor(from: "4.0.0"))
]
```

Or if you're using Xcode, add via File → Add Packages:
```
https://github.com/AvdLee/appstoreconnect-swift-sdk.git
```

### 3. Configure Your App

Your app must already be:
- Created in App Store Connect
- Have Game Center enabled in Features
- Have an app ID for reference

## Usage

### Basic Setup

```swift
let config = GameCenterAutomationConfig(
    issuerId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    apiKeyId: "ABCD1234XY",
    privateKeyPath: "~/.appstoreconnect/AuthKey_ABCD1234XY.p8",
    appId: "123456789"  // Your App ID from App Store Connect
)

let automation = GameCenterAchievementAutomation(config: config)
```

### Create a Single Achievement

```swift
let achievement = try await automation.createAchievement(
    referenceName: "First Victory",
    vendorIdentifier: "com.myapp.achievement.first_victory",
    pointValue: 50,
    isSecret: false,
    canRepeat: false
)
```

### Add Localizations

```swift
try await automation.addLocalization(
    achievementId: achievement.data.id,
    locale: "en-US",
    name: "First Victory",
    beforeEarnedDescription: "Win your first match",
    afterEarnedDescription: "You've won your first match!"
)
```

### Upload Achievement Image

Images must be PNG files. The SDK will handle uploading to Apple's servers:

```swift
let imageData = try Data(contentsOf: URL(fileURLWithPath: "/path/to/achievement.png"))
try await automation.uploadImage(
    achievementId: achievement.data.id,
    imageData: imageData
)
```

### Batch Create Multiple Achievements

```swift
let achievements = [
    AchievementData(
        name: "First Player",
        vendorIdentifier: "com.game.first_player",
        points: 5,
        isSecret: false,
        localizations: [
            AchievementLocalization(
                locale: "en-US",
                name: "First Player",
                beforeDescription: "Play your first game",
                afterDescription: "You've played your first game!"
            )
        ]
    ),
    AchievementData(
        name: "Speed Demon",
        vendorIdentifier: "com.game.speed_demon",
        points: 25,
        isSecret: false,
        localizations: [
            AchievementLocalization(
                locale: "en-US",
                name: "Speed Demon",
                beforeDescription: "Complete a level in under 30 seconds",
                afterDescription: "You're a speed demon!"
            )
        ]
    )
]

await automation.createAchievementsBatch(achievements: achievements)
```

## Important Implementation Details

### Workflow Order

The API requires following a specific order:

1. **Get or Create Game Center Detail** - Links your app to Game Center
2. **Create Achievement** - Define the achievement itself
3. **Add Localizations** - Add language-specific text (required for at least one language)
4. **Upload Images** - Add achievement artwork
5. **Create Release** - Attach to an app store version (required for live deployment)

The provided code handles steps 1-4 automatically.

### Vendor Identifier Rules

- Must be unique across your app
- Cannot be changed after creation
- Suggested format: `com.yourcompany.appname.achievement_name`
- Use lowercase and underscores, no spaces

### Image Requirements

- Format: PNG only
- Recommended size: 256x256 pixels (required for Game Center display)
- The SDK manages upload but there's a known issue: images sometimes don't display in the App Store Connect UI, though they work in-game

### Authentication

The SDK automatically:
- Generates JWT tokens from your private key
- Adds them to request headers
- Handles token refresh/rotation
- Manages rate limiting

You don't need to manually handle JWT creation with this SDK.

### Error Handling

Common errors you might encounter:

```swift
// Game Center not enabled for app
NSError(domain: "GameCenterAutomation", code: -1, ...)

// Image upload failed
NSError(domain: "GameCenterAutomation", code: -2, ...)

// Invalid locale format
// Invalid vendor identifier format
// Achievement point value out of range (0-2000)
```

## Rate Limiting

The App Store Connect API has rate limits:
- The SDK handles retries automatically
- Batch operations are recommended for multiple achievements
- Consider adding delays between batch operations if processing many at once

## Testing

### Before Going Live

1. Create achievements in sandbox/test environment first
2. Verify achievements appear in App Store Connect UI
3. Test that images upload and display correctly
4. Confirm localizations show properly
5. Submit achievements for review as part of app version submission

### Important Notes

- Achievements must be approved by Apple before they're visible to users
- Submit your app version that includes achievements for review through App Store Connect
- Test with a sandbox user account
- Game Center must be enabled in your app's Xcode project capabilities

## Troubleshooting

### "Game Center detail not found"
- Ensure Game Center is enabled in your app's App Store Connect features
- Verify the appId matches your actual app ID (not bundle ID)

### "Invalid API credentials"
- Check that issuerId and apiKeyId are correct
- Verify the private key file exists and is readable
- Ensure the API key has Game Center permissions

### Images not showing in UI
- This is a known Apple issue
- Images are uploaded correctly but may not display in App Store Connect web UI
- They typically work fine in the actual app

### Achievements not appearing
- Verify localizations were added (at least one is required)
- Check that point value is between 0-2000
- Confirm vendor identifier is unique and follows naming rules

## Security Best Practices

1. **Never commit private keys to version control**
   - Store them in environment variables or secure files outside the repo
   - Use .gitignore to exclude `.p8` files

2. **Use a configuration file outside your repo**
   ```swift
   let config = try GameCenterAutomationConfig.loadFromSecureLocation()
   ```

3. **Rotate API keys periodically**
   - Create new keys in App Store Connect
   - Update your automation configuration

4. **Audit API access**
   - Review App Store Connect API usage logs
   - Monitor for unauthorized access attempts

## Performance Considerations

- Creating achievements is relatively fast (< 1 second per achievement)
- Image uploads depend on file size and network speed
- Batch operations are sequential but efficient
- Consider async/await for production systems

## Next Steps

1. Set up your API key and store it securely
2. Verify your app ID is correct
3. Start with creating a single test achievement
4. Test the full workflow (create, localize, image, release)
5. Scale to batch operations once comfortable
6. Submit app version with achievements for review

## References

- [Apple App Store Connect API Documentation](https://developer.apple.com/documentation/appstoreconnectapi)
- [GitHub: appstoreconnect-swift-sdk](https://github.com/AvdLee/appstoreconnect-swift-sdk)
- [Game Center Configuration](https://developer.apple.com/help/app-store-connect/configure-game-center/configure-game-center)
