//
//  ScreenshotManager.swift
//  ThreeFingerScreenshot
//
//  Created by Dragoș Costin on 18/05/2026.
//

import Photos
import UIKit

/// A thread-safe, global manager responsible for handling the three-finger screenshot gesture.
///
/// `ScreenshotManager` mimics the native iOS screenshot functionality. When a three-finger pan gesture
/// is recognized on the attached window, it captures the current screen hierarchy, displays a visual flash,
/// animates a thumbnail preview to the bottom-left corner of the screen, and automatically saves the
/// captured image to the user's Photo Library.
@MainActor
public class ScreenshotManager: NSObject {
  
  /// The shared, global instance of the screenshot manager.
  /// Use this instance to attach the gesture recognizer to your application's primary window.
  public static let shared = ScreenshotManager()

  /// The primary window the gesture is attached to.
  private weak var hostWindow: UIWindow?
  
  /// A task used to automatically dismiss the animated thumbnail after a short delay.
  private var dismissTask: DispatchWorkItem?
  
  /// An overlay view used to freeze the screen visually while the three-finger gesture is actively dragging.
  private var frozenOverlay: UIImageView?
  
  /// The image representation of the screen captured at the exact moment the gesture began.
  private var frozenScreenshot: UIImage?
  
  /// A collection of active gesture recognizers that were firing simultaneously with the three-finger pan.
  /// Used to temporarily pause them and re-enable them to prevent UI conflicts during the swipe.
  private var simultaneousGestures = NSHashTable<UIGestureRecognizer>.weakObjects()

  /// Private initializer to enforce the singleton pattern.
  override private init() {
    super.init()
  }

  /// Configures and attaches the global three-finger pan gesture recognizer to the specified window.
  ///
  /// Call this method once during your application's lifecycle, typically during scene connection
  /// or when your root SwiftUI view appears.
  ///
  /// - Parameter window: The `UIWindow` to attach the gesture recognizer to. Typically the application's key window.
  public func attach(to window: UIWindow) {
    hostWindow = window

    // This new version uses a Pan Gesture to track the drag continuously
    let panGesture = UIPanGestureRecognizer(
      target: self,
      action: #selector(handleThreeFingerPan(_:)),
    )
    panGesture.minimumNumberOfTouches = 3
    panGesture.maximumNumberOfTouches = 3
    panGesture.delegate = self
    window.addGestureRecognizer(panGesture)
  }

  /// Handles the continuous state updates of the three-finger pan gesture.
  ///
  /// - Parameter gesture: The `UIPanGestureRecognizer` responsible for tracking the three-finger swipe.
  @objc private func handleThreeFingerPan(_ gesture: UIPanGestureRecognizer) {
    guard let window = hostWindow else { return }

    switch gesture.state {
    case .began:
      guard let screenshot = captureSnapshot(of: window) else { return }
      frozenScreenshot = screenshot

      for gesture in simultaneousGestures.allObjects {
        gesture.isEnabled = false
        gesture.isEnabled = true
      }
      simultaneousGestures.removeAllObjects()

      let overlay = UIImageView(image: screenshot)
      overlay.frame = window.bounds
      window.addSubview(overlay)
      frozenOverlay = overlay

    case .changed:
      break

    case .ended:
      let translation = gesture.translation(in: window)
      if translation.y > 100 {
        if let screenshot = frozenScreenshot {
          flashScreen(window: window)
          animateThumbnail(image: screenshot, window: window)
          saveToPhotos(image: screenshot)
        }
      }
      unfreezeScreen()

    case .cancelled, .failed:
      unfreezeScreen()

    default:
      break
    }
  }

  /// Removes the static overlay created during the pan gesture, smoothly unfreezing the UI.
  private func unfreezeScreen() {
    UIView.animate(withDuration: 0.2) {
      self.frozenOverlay?.alpha = 0
    } completion: { _ in
      self.frozenOverlay?.removeFromSuperview()
      self.frozenOverlay = nil
      self.frozenScreenshot = nil
    }
  }

  /// Dismisses the floating thumbnail preview when the user swipes it away.
  ///
  /// - Parameter gesture: The `UISwipeGestureRecognizer` attached to the thumbnail container.
  @objc private func handleThumbnailSwipe(_ gesture: UISwipeGestureRecognizer) {
    guard let view = gesture.view else { return }
    dismissTask?.cancel()

    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
      view.frame.origin.x = -view.bounds.width - 50
      view.alpha = 0
    } completion: { _ in
      view.removeFromSuperview()
    }
  }
}

// MARK: - Private Helpers

extension ScreenshotManager {
  
  /// Captures a static image representation of the entire view hierarchy.
  ///
  /// - Parameter view: The `UIView` (typically the root `UIWindow`) to capture.
  /// - Returns: A `UIImage` containing the rendered hierarchy, or `nil` if the context could not be established.
  private func captureSnapshot(of view: UIView) -> UIImage? {
    let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
    return renderer.image { _ in
      view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
    }
  }

  /// Produces a quick, full-screen white flash animation to provide visual feedback for the screenshot.
  ///
  /// - Parameter window: The window to present the flash overlay on.
  private func flashScreen(window: UIWindow) {
    let flashView = UIView(frame: window.bounds)
    flashView.backgroundColor = .white
    flashView.alpha = 1.0
    window.addSubview(flashView)

    UIView.animate(withDuration: 0.3) {
      flashView.alpha = 0.0
    } completion: { _ in
      flashView.removeFromSuperview()
    }
  }

  /// Creates and animates a small thumbnail of the captured screenshot into the bottom-left corner of the screen.
  ///
  /// The thumbnail includes a drop shadow and a border, mirroring the native iOS screenshot design.
  /// It automatically dismisses after a short delay unless swiped away by the user.
  ///
  /// - Parameters:
  ///   - image: The captured screenshot image to display.
  ///   - window: The window to present and animate the thumbnail inside.
  private func animateThumbnail(image: UIImage, window: UIWindow) {
    let containerView = UIView(frame: window.bounds)
    containerView.layer.shadowColor = UIColor.black.cgColor
    containerView.layer.shadowOpacity = 0.3
    containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
    containerView.layer.shadowRadius = 8
    containerView.isUserInteractionEnabled = true

    let swipeGesture = UISwipeGestureRecognizer(
      target: self,
      action: #selector(handleThumbnailSwipe(_:)),
    )
    swipeGesture.direction = .left
    containerView.addGestureRecognizer(swipeGesture)

    let imageView = UIImageView(image: image)
    imageView.frame = containerView.bounds
    imageView.layer.cornerRadius = 12
    imageView.layer.masksToBounds = true
    imageView.layer.borderWidth = 2
    imageView.layer.borderColor = UIColor.white.cgColor

    containerView.addSubview(imageView)
    window.addSubview(containerView)

    let thumbWidth = window.bounds.width * 0.25
    let thumbHeight = window.bounds.height * 0.25
    let targetFrame = CGRect(
      x: 16,
      y: window.bounds.height - thumbHeight - 32,
      width: thumbWidth,
      height: thumbHeight,
    )

    UIView.animate(
      withDuration: 0.5,
      delay: 0,
      usingSpringWithDamping: 0.75,
      initialSpringVelocity: 0.5,
      options: .curveEaseOut,
    ) {
      containerView.frame = targetFrame
      imageView.frame = containerView.bounds
    } completion: { _ in
      let task = DispatchWorkItem { [weak containerView] in
        guard let view = containerView else { return }
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
          view.frame.origin.x = -view.bounds.width - 50
          view.alpha = 0
        } completion: { _ in
          view.removeFromSuperview()
        }
      }
      self.dismissTask = task
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
    }
  }

  /// Requests the necessary permissions and saves the provided image to the iOS Photo Library.
  ///
  /// - Parameter image: The `UIImage` to be saved to the user's camera roll.
  private func saveToPhotos(image: UIImage) {
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        print("ScreenshotManager: No permission to save to photos")
        return
      }

      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAsset(from: image)
      }) { success, error in
        if let error {
          print("ScreenshotManager Error: Failed to save image - \(error.localizedDescription)")
        } else if success {
          print("ScreenshotManager: Successfully saved 3-finger screenshot!")
        }
      }
    }
  }
}

// MARK: - UIGestureRecognizerDelegate

extension ScreenshotManager: UIGestureRecognizerDelegate {
  
  /// Asks the delegate if two gesture recognizers should be allowed to recognize gestures simultaneously.
  ///
  /// This implementation ensures that the three-finger screenshot gesture does not consume interactions
  /// meant for underlying scroll views or controls. It adds the conflicting gesture to the tracking list
  /// so it can be temporarily disabled when the three-finger swipe initiates.
  ///
  /// - Parameters:
  ///   - gestureRecognizer: An instance of a subclass of the abstract base class `UIGestureRecognizer`.
  ///   - otherGestureRecognizer: Another instance of a subclass of the abstract base class `UIGestureRecognizer`.
  /// - Returns: `true` to allow simultaneous recognition, `false` otherwise. This implementation always returns `true`.
  public func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer,
  ) -> Bool {
    simultaneousGestures.add(otherGestureRecognizer)
    return true
  }
}
