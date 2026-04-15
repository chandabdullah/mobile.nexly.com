# Nexly

Nexly is a Flutter-based video downloader with quick presets, background download support, and Android share-sheet integration for fast saving of media links.

It supports:

- Direct media URLs
- YouTube links
- Resolver-backed social/video links such as Instagram, Facebook, TikTok, X, and Pinterest

## Features

- Paste a link and download without leaving the app
- Choose quick presets for high, medium, low, or audio-only downloads
- Detect common platforms from the pasted URL
- Queue downloads with `flutter_downloader`
- Save downloaded video to the gallery album on supported platforms
- Launch from the Android share sheet through a lightweight quick-share flow
- Show local notifications for resolving, progress, and failure states

## Stack

- Flutter
- GetX
- `flutter_downloader`
- `youtube_explode_dart`
- `share_handler`
- `flutter_local_notifications`
- `permission_handler`
- `gal`

## Project Structure

```text
lib/
  app/
    core/
      environment/     # Resolver endpoint configuration
      theme/           # Colors and app theme
    data/
      models/          # Preset option enums/models
      services/        # Download, notifications, share-intent handling
    modules/
      home/            # Main downloader UI
      quick_share/     # Android share-sheet entry flow
      splash/          # App bootstrap screen
    routes/            # GetX routes
```

## Requirements

- Flutter SDK
- Dart SDK compatible with the repo's Flutter version
- Android Studio or Xcode for platform builds

## Getting Started

```bash
flutter pub get
flutter run
```

## Resolver Backend

Some links are resolved through a backend service instead of being downloaded directly in the app.

Default resolver:

```text
https://videodownloaderbackend-production-99d3.up.railway.app/resolve
```

You can override it at build or run time with a Dart define:

```bash
flutter run --dart-define=RESOLVER_ENDPOINT=https://your-backend.example.com/resolve
```

Example release build:

```bash
flutter build apk --dart-define=RESOLVER_ENDPOINT=https://your-backend.example.com/resolve
```

## Android Notes

- App name: `Nexly`
- Includes an Android share target for `text/*`
- Uses `flutter_downloader` with a registered file provider
- Requests notification permission for download status updates
- Uses app storage internally and enables public download notifications on Android

## Main Flow

1. Paste or share a supported link.
2. Nexly detects the platform and prepares available media options.
3. Pick a quick preset: high, medium, low, or audio.
4. The app resolves the media URL if needed and queues the download.

## Useful Commands

```bash
flutter analyze
flutter test
flutter build apk
flutter build ios
flutter build web
```

## Entry Points

- Standard app flow: [`lib/main.dart`](lib/main.dart)
- Main download screen: [`lib/app/modules/home/views/home_view.dart`](lib/app/modules/home/views/home_view.dart)
- Download engine: [`lib/app/data/services/download_service.dart`](lib/app/data/services/download_service.dart)
- Share intent handling: [`lib/app/data/services/share_intent_service.dart`](lib/app/data/services/share_intent_service.dart)
- Resolver configuration: [`lib/app/core/environment/app_environment.dart`](lib/app/core/environment/app_environment.dart)

## Status

This repository is configured as a private app project with `publish_to: 'none'`.
