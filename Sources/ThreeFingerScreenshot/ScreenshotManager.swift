//
//  ScreenshotManager.swift
//  ThreeFingerScreenshot
//
//  Created by Dragoș Costin on 18/05/2026.
//

import Photos
import UIKit

@MainActor
public class ScreenshotManager: NSObject {
  public static let shared = ScreenshotManager()

  private weak var hostWindow: UIWindow?
  private var dismissTask: DispatchWorkItem?
  private var frozenOverlay: UIImageView?
  private var frozenScreenshot: UIImage?
  private var simultaneousGestures = NSHashTable<UIGestureRecognizer>.weakObjects()

  override private init() {
    super.init()
  }

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

  private func unfreezeScreen() {
    UIView.animate(withDuration: 0.2) {
      self.frozenOverlay?.alpha = 0
    } completion: { _ in
      self.frozenOverlay?.removeFromSuperview()
      self.frozenOverlay = nil
      self.frozenScreenshot = nil
    }
  }

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
  private func captureSnapshot(of view: UIView) -> UIImage? {
    let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
    return renderer.image { _ in
      view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
    }
  }

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
  public func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer,
  ) -> Bool {
    simultaneousGestures.add(otherGestureRecognizer)
    return true
  }
}
