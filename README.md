# GameCenter Achievement CLI

A command-line tool to automate GameCenter achievement creation and management via the App Store Connect API.

## Features

✅ **Batch create achievements** from JSON file
✅ **Multi-language localizations** (supports all App Store locales)
✅ **Automatic locale mapping** (e.g., `it-IT` → `it`, `ja-JP` → `ja`)
✅ **Handle existing achievements** (updates localizations if achievement exists)
✅ **Delete achievements** (with confirmation prompt)
✅ **Full async/await** support
✅ **Proper error handling** and progress reporting

## Prerequisites

- macOS 13.0 or later
- Swift 5.9 or later
- App Store Connect API credentials (Issuer ID, Key ID, Private Key)

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/gamecenter-cli.git
   cd gamecenter-cli
   ```

2. **Build the project:**
   ```bash
   swift build -c release
   ```

3. **Optional: Install globally:**
   ```bash
   cp .build/release/GameCenterCLI /usr/local/bin/gamecenter-cli
   ```

## Configuration

### 1. Get App Store Connect API Credentials

1. Go to [App Store Connect API Keys](https://appstoreconnect.apple.com/access/integrations/api)
2. Create a new API key with **Game Center** permissions (Full Access)
3. Download the `.p8` private key file
4. Note your **Issuer ID** and **Key ID**

### 2. Create Configuration File

Create `~/.gamecenter-cli-config.json`:

```json
{
  "issuerId": "your-issuer-id-here",
  "apiKeyId": "your-api-key-id",
  "privateKeyPath": "~/.appstoreconnect/AuthKey_YOURKEY.p8",
  "appId": "your-app-id"
}
```

**Security Notes:**
- Store the `.p8` file in a secure location (e.g., `~/.appstoreconnect/`)
- Set proper permissions: `chmod 600 ~/.gamecenter-cli-config.json`
- Never commit credentials to version control

### 3. Find Your App ID

Your App ID (numeric) can be found in App Store Connect:
- Go to **My Apps** → Select your app
- Look at the URL: `https://appstoreconnect.apple.com/apps/{APP_ID}/appstore`

## Usage

### Batch Create Achievements

Create multiple achievements from a JSON file:

```bash
swift run GameCenterCLI create-batch achievements.json
```

**JSON Format:**

```json
[
  {
    "name": "First Victory",
    "vendorIdentifier": "com.myapp.first_victory",
    "points": 10,
    "isSecret": false,
    "localizations": [
      {
        "locale": "en-US",
        "name": "First Victory",
        "beforeDescription": "Win your first game",
        "afterDescription": "You won your first game!"
      },
      {
        "locale": "es-ES",
        "name": "Primera Victoria",
        "beforeDescription": "Gana tu primer juego",
        "afterDescription": "¡Ganaste tu primer juego!"
      }
    ]
  }
]
```

### Delete All Achievements

Remove all achievements (with confirmation):

```bash
swift run GameCenterCLI delete-all
```

**⚠️ Warning:** This action is permanent. You'll be asked to type "yes" to confirm.

### Help

Show available commands:

```bash
swift run GameCenterCLI help
```

## Supported Locales

The tool automatically maps common locale codes to App Store Connect's format:

| Your Code | Mapped To | Language |
|-----------|-----------|----------|
| `it-IT` | `it` | Italian |
| `ja-JP` | `ja` | Japanese |
| `ko-KR` | `ko` | Korean |
| `zh-CN` | `zh-Hans` | Chinese (Simplified) |
| `zh-TW` | `zh-Hant` | Chinese (Traditional) |

**Full list of valid App Store Connect locales:**
```
ar-SA, ca, cs, da, de-DE, el, en-AU, en-CA, en-GB, en-US, es-ES, es-MX,
fi, fr-CA, fr-FR, he, hi, hr, hu, id, it, ja, ko, ms, nl-NL, no, pl,
pt-BR, pt-PT, ro, ru, sk, sv, th, tr, uk, vi, zh-Hans, zh-Hant
```

## Achievement Requirements

### Vendor Identifier
- Format: `com.company.appname.achievement_name`
- Must be unique per app
- Cannot be changed after creation
- Use lowercase, dots, hyphens, underscores only

### Points
- Range: 0 to 2000 per achievement
- Total across all achievements: **max 1000 points**
- Recommended distribution:
  - Easy: 5-10 points
  - Medium: 15-25 points
  - Hard: 50-100 points

### Secret Achievements
- Hidden from players until earned
- Set `"isSecret": true` in JSON
- Good for surprises and special accomplishments

### Localizations
- At least one localization required (typically `en-US`)
- Each locale needs:
  - `name`: Achievement title
  - `beforeDescription`: Shown before earning
  - `afterDescription`: Shown after earning

## Features

### Automatic Locale Mapping

The tool automatically converts locale codes to App Store Connect's format:

```
[INFO] Mapped locale 'it-IT' -> 'it'
[INFO] Mapped locale 'ja-JP' -> 'ja'
```

### Handle Existing Achievements

When an achievement already exists, the tool will:
1. Fetch the existing achievement ID
2. Add missing localizations
3. Skip localizations that already exist

```
[INFO] Achievement already exists, fetching existing achievement...
[INFO] Found existing achievement with ID: abc123
[SKIP] Localization for en-US already exists
[OK] First Victory - 7 localizations added, 1 skipped
```

### Progress Reporting

Clear progress indicators during batch operations:

```
Creating 47 achievements from achievements.json

[1/47] Creating achievement: First Steps...
  [OK] First Steps created with 8 localizations
[2/47] Creating achievement: Getting Started...
  [OK] Getting Started created with 8 localizations
...
```

## Troubleshooting

### "Invalid locale" Error

**Problem:** `ENTITY_ERROR.LOCALE_INVALID`

**Solution:** Use the correct locale code. Check the supported locales list above. Common fixes:
- `it-IT` → `it`
- `ja-JP` → `ja`
- `ko-KR` → `ko`

### "Total points exceed 1000" Error

**Problem:** `ENTITY_ERROR.INVALID_TOTAL_APP_POINTS`

**Solution:**
- Delete some achievements, or
- Reduce point values to stay under 1000 total
- Use `swift run GameCenterCLI delete-all` to start fresh

### "Cannot delete achievement" Error

**Problem:** `STATE_ERROR.CANNOT_DELETE_HAS_NON_DRAFT_VERSION`

**Solution:**
- Achievements in production cannot be deleted
- Archive them in App Store Connect instead
- Or create new achievements with different vendor IDs

### "Authentication failed"

**Problem:** Invalid API credentials

**Solution:**
- Verify Issuer ID, Key ID, and App ID are correct
- Check that `.p8` file exists and path is correct
- Ensure API key has Game Center permissions
- Use absolute path for `.p8` file or expand tilde (`~`)

## Development

### Build for Development

```bash
swift build
```

### Run Tests

```bash
swift test
```

### Build for Release

```bash
swift build -c release
```

The binary will be at `.build/release/GameCenterCLI`.

## Project Structure

```
gameCenterAPI/
├── Package.swift                          # Swift Package configuration
├── Sources/
│   └── GameCenterCLI/
│       ├── main.swift                     # Entry point
│       ├── GameCenterAchievementCLI.swift # CLI command handling
│       └── GameCenterAchievementAutomation.swift # API logic
├── README.md                              # This file
├── SETUP_GUIDE.md                         # Detailed setup instructions
└── achievements.json                      # Example achievements file
```

## Dependencies

- [appstoreconnect-swift-sdk](https://github.com/AvdLee/appstoreconnect-swift-sdk) (v4.0.0)
  - Provides App Store Connect API bindings
  - Handles JWT authentication automatically

## Security Best Practices

1. **Never commit credentials:**
   - Add `.p8` files to `.gitignore`
   - Add config files to `.gitignore`
   - Use environment variables for CI/CD

2. **Secure file permissions:**
   ```bash
   chmod 600 ~/.gamecenter-cli-config.json
   chmod 600 ~/.appstoreconnect/AuthKey_*.p8
   chmod 700 ~/.appstoreconnect
   ```

3. **Rotate API keys periodically:**
   - Create new keys in App Store Connect
   - Update configuration file
   - Delete old keys

## Limitations

- **Leaderboards:** This tool only supports achievements. Leaderboards must be configured manually in App Store Connect.
- **Images:** Achievement images must be uploaded through App Store Connect web interface.
- **Deletion:** Achievements in production/submitted state cannot be deleted programmatically.

## Resources

- [App Store Connect API Documentation](https://developer.apple.com/documentation/appstoreconnectapi)
- [Game Center Configuration Guide](https://developer.apple.com/help/app-store-connect/configure-game-center)
- [App Store Localizations Reference](https://developer.apple.com/help/app-store-connect/reference/app-store-localizations/)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - See LICENSE file for details

## Acknowledgments

- Built with [AppStoreConnect-Swift-SDK](https://github.com/AvdLee/appstoreconnect-swift-sdk) by Antoine van der Lee
- Developed with assistance from Claude Code

## Support

For issues and questions:
- Open an issue on GitHub
- Check the troubleshooting section above
- Review the SETUP_GUIDE.md for detailed instructions

---

**Created:** December 2025
**Maintained by:** Lismond Bernard
