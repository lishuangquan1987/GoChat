# GoChat Client

A cross-platform chat application built with Flutter.

## Features

- User authentication (login/register)
- Private messaging
- Group chat
- Friend management
- Real-time messaging with WebSocket
- Image and video sharing
- Cross-platform support (Windows, macOS, Linux, Android, iOS)

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK
- GoChat Server running on localhost:8080

### Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Run the app:
```bash
flutter run
```

### Build for specific platforms

```bash
# Android
flutter build apk

# iOS
flutter build ios

# Windows
flutter build windows

# macOS
flutter build macos

# Linux
flutter build linux
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/                # Data models
│   ├── user.dart
│   ├── message.dart
│   ├── conversation.dart
│   └── group.dart
├── pages/                 # UI pages
│   ├── login_page.dart
│   ├── home_page.dart
│   ├── chat_page.dart
│   └── ...
├── providers/             # State management
│   ├── user_provider.dart
│   ├── chat_provider.dart
│   ├── friend_provider.dart
│   └── group_provider.dart
├── services/              # Business logic
│   ├── api_service.dart
│   ├── websocket_service.dart
│   └── storage_service.dart
└── widgets/               # Reusable widgets
```

## Configuration

Update the API base URL in `lib/services/api_service.dart` and WebSocket URL in `lib/services/websocket_service.dart` to match your server address.

## License

MIT
