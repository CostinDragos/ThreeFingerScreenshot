//
//  ThreeFingerScreenshotTests.swift
//  ThreeFingerScreenshotTests
//
//  Created by Dragoș Costin on 18/05/2026.
//

@testable import ThreeFingerScreenshot
import UIKit
import XCTest

@MainActor
final class ThreeFingerScreenshotTests: XCTestCase {
  func testSingletonIsShared() {
    let instance1 = ScreenshotManager.shared
    let instance2 = ScreenshotManager.shared
    XCTAssertTrue(
      instance1 === instance2,
      "ScreenshotManager should implement the singleton pattern properly",
    )
  }

  func testAttachAddsGestureRecognizer() {
    let manager = ScreenshotManager.shared
    let window = UIWindow(frame: UIScreen.main.bounds)

    manager.attach(to: window)

    let gestures = window.gestureRecognizers ?? []
    XCTAssertFalse(gestures.isEmpty, "A gesture recognizer should be added to the window")

    let panGesture = gestures.compactMap { $0 as? UIPanGestureRecognizer }.first
    XCTAssertNotNil(panGesture, "The added gesture should be a UIPanGestureRecognizer")

    if let panGesture {
      XCTAssertEqual(
        panGesture.minimumNumberOfTouches,
        3,
        "The pan gesture must require exactly 3 fingers",
      )
      XCTAssertEqual(
        panGesture.maximumNumberOfTouches,
        3,
        "The pan gesture must require exactly 3 fingers",
      )
      XCTAssertTrue(
        panGesture.delegate === manager,
        "ScreenshotManager should act as the delegate for the gesture",
      )
    }
  }

  func testSimultaneousGestureRecognition() {
    let manager = ScreenshotManager.shared
    let window = UIWindow(frame: UIScreen.main.bounds)
    manager.attach(to: window)

    guard let panGesture = window.gestureRecognizers?.compactMap({ $0 as? UIPanGestureRecognizer })
      .first
    else {
      XCTFail("Could not find the attached UIPanGestureRecognizer")
      return
    }

    let dummyGesture = UITapGestureRecognizer()

    let shouldRecognize = manager.gestureRecognizer(
      panGesture,
      shouldRecognizeSimultaneouslyWith: dummyGesture,
    )

    XCTAssertTrue(shouldRecognize, "The delegate should allow simultaneous gesture recognition")
  }
}
