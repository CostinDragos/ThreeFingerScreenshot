# ThreeFingerScreenshot

[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org)[![iOS](https://img.shields.io/badge/iOS-14.0+-blue.svg)](https://developer.apple.com/ios/)[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A sleek, native Swift package inspired completely by the popular OnePlus three-finger swipe gesture.

This package allows you to effortlessly integrate an intuitive, global three-finger swipe-down gesture into your iOS applications to capture beautiful app snapshots. It features a seamless "UI freeze" during the drag, a visual camera flash, an interactive floating thumbnail, and automatic saving to the user's Photo Library.

<div align="center">
  <video src="https://github.com/user-attachments/assets/1e13a859-6813-4e21-9d1d-7409f5ac9b43" width="250" autoplay loop muted playsinline></video>
</div>

## Features

- **Global 3-Finger Gesture:** Seamlessly recognizes a three-finger pan gesture anywhere in your app. Smart delegate handling ensures it never interferes with standard SwiftUI Lists or UIKit ScrollViews.
- **Instant UI Freeze:** The exact millisecond the user touches the screen with three fingers, the UI visually "freezes," giving the user immediate, tactile feedback that the screenshot capture has begun.
- **Interactive Apple-Style Thumbnail:** After capture, a thumbnail shrinks to the bottom-left corner. It automatically dismisses after 2.5 seconds, or the user can actively swipe it left into oblivion.
- **Auto-Save to Photos:** Built on the modern, thread-safe `PHPhotoLibrary` framework. Automatically prompts for add-only photo permissions and drops the screenshot directly into the camera roll.
- **Lightweight & Idiomatic:** Written entirely in Swift using native `UIKit` primitives and structured for easy adoption in both `SwiftUI` and `UIKit` environments.

## Requirements

- iOS 14.0+
- Xcode 13.0+
- Swift 5.5+

## Installation

You can install `ThreeFingerScreenshot` using Swift Package Manager (SPM).

In Xcode:

1. Go to **File > Add Package Dependencies...**
2. Enter the repository URL for this package.
3. Select the version or branch you wish to integrate and add it to your project.

## Implementation Guide

To use `ThreeFingerScreenshot`, you must attach the global `ScreenshotManager` to your application's primary `UIWindow`.

### SwiftUI

In a SwiftUI lifecycle app, the best place to configure the gesture is by accessing the underlying `UIWindow` within your main `App` entry point using the `.onAppear` modifier.

```swift
import SwiftUI
import ThreeFingerScreenshot

@main
struct YourApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .onAppear {
          setupScreenshotGesture()
        }
    }
  }

  private func setupScreenshotGesture() {
    // Safely extract the primary window from the active scene
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first
    else {
      print("Failed to find UIWindow for ScreenshotManager")
      return
    }

    // Attach the global screenshot listener to the window
    ScreenshotManager.shared.attach(to: window)
  }
}
```

### UIKit

If you are using a standard `AppDelegate` or `SceneDelegate`, you can easily attach it to the window property when the app finishes launching or the scene connects:

```swift
import ThreeFingerScreenshot
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    let window = UIWindow(windowScene: windowScene)

    // Setup your root view controller here
    // ...

    self.window = window
    window.makeKeyAndVisible()

    // Attach the screenshot gesture globally
    ScreenshotManager.shared.attach(to: window)
  }
}
```

## API Reference

### `ScreenshotManager`

The core orchestrator of the gesture recognition and screenshot pipeline. It is enforced as a thread-safe singleton that strictly operates on the `@MainActor`.

#### `static let shared: ScreenshotManager`

Access the global, shared instance of the screenshot manager.

#### `func attach(to window: UIWindow)`

Configures the screenshot gesture recognizer and attaches it globally to the provided window.

- **Parameters:**
  - `window`: The target `UIWindow` to apply the global tracking gesture to. Typically, this is your application's primary window or key window.

**Note:** This manager conforms to `UIGestureRecognizerDelegate` to enable simultaneous gesture recognition (`shouldRecognizeSimultaneouslyWith`). This ensures that your app's standard scroll views and interactive components continue to function normally even while the three-finger gesture listener is active.

## Permissions Required

Because this package automatically saves screenshots to the iOS Photo Library, you **must** include the following key in your application's `Info.plist`:

- **`NSPhotoLibraryAddUsageDescription`** (Privacy - Photo Library Additions Usage Description)  
  Provide a clear string explaining to the user why the app needs to save photos, e.g., *"This app requires access to save three-finger screenshots to your Photos."*

Without this key, the application will fail to save the image and will print a permissions error in the console.

## License

This project is licensed under the MIT License.
