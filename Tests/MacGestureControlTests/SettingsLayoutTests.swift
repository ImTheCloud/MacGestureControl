import XCTest
import AppKit
import SwiftUI
@testable import MacGestureControl

/// Guards the popover's geometry. The popover previously rendered with a 0x0
/// content size, which AppKit anchored off the top of the screen.
final class SettingsLayoutTests: XCTestCase {

    private func hostedSize(screenHeight: CGFloat) -> NSSize {
        PopoverLayout.shared.update(forScreenHeight: screenHeight)
        let hosting = NSHostingController(rootView: SettingsView())
        hosting.sizingOptions = [.preferredContentSize]
        hosting.view.layoutSubtreeIfNeeded()
        return hosting.view.fittingSize
    }

    override func tearDown() {
        PopoverLayout.shared.update(forScreenHeight: 985)
        super.tearDown()
    }

    /// A hosting controller that reports no preferred size leaves the popover at
    /// its default 0x0, which is what broke the presentation.
    func testHostingControllerReportsAConcreteSize() {
        let hosting = NSHostingController(rootView: SettingsView())
        hosting.sizingOptions = [.preferredContentSize]
        hosting.view.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(hosting.preferredContentSize.width, 0)
        XCTAssertGreaterThan(hosting.preferredContentSize.height, 0)

        let popover = NSPopover()
        popover.contentViewController = hosting
        popover.contentSize = hosting.view.fittingSize
        XCTAssertGreaterThan(popover.contentSize.height, 0)
    }

    /// `chromeHeight` is the header, tab bar, footer and dividers. It is used to
    /// work out how much room the scrolling area may take, so it must stay true.
    func testChromeHeightConstantMatchesTheRealLayout() {
        // A short screen forces the content to its cap, making chrome the remainder.
        let shortScreen: CGFloat = 600
        let total = hostedSize(screenHeight: shortScreen).height
        let cappedContent = PopoverLayout.shared.maxContentHeight

        XCTAssertEqual(
            total - cappedContent,
            SettingsMetrics.chromeHeight,
            accuracy: 1,
            "SettingsMetrics.chromeHeight is stale — the popover would mis-size itself"
        )
    }

    func testWidthMatchesTheDeclaredMetric() {
        XCTAssertEqual(hostedSize(screenHeight: 985).width, SettingsMetrics.width)
    }

    /// The tallest tab must fit under the menu bar on every screen we can expect.
    func testPopoverFitsWithinTheScreenItIsShownOn() {
        // 13" MacBook, 16" MacBook, 1080p and 4K externals.
        for visibleHeight in [740.0, 985.0, 1010.0, 1410.0] as [CGFloat] {
            let total = hostedSize(screenHeight: visibleHeight).height
            XCTAssertLessThanOrEqual(
                total,
                visibleHeight,
                "popover is \(total)pt tall on a \(visibleHeight)pt screen"
            )
        }
    }

    /// On a roomy screen nothing should be hidden behind a scroll bar.
    func testDashboardNeedsNoScrollingOnALaptopScreen() {
        let total = hostedSize(screenHeight: 985)
        XCTAssertLessThan(
            total.height - SettingsMetrics.chromeHeight,
            PopoverLayout.shared.maxContentHeight,
            "the busiest tab should fit without scrolling on a laptop display"
        )
    }

    /// A cramped screen shrinks the scrolling area instead of overflowing.
    func testContentShrinksWithTheScreen() {
        let roomy = hostedSize(screenHeight: 985).height
        // Small enough to clamp the content whatever is currently bound, but
        // still above the floor, so this measures shrinking and not the floor.
        let cramped = hostedSize(screenHeight: 500).height
        XCTAssertLessThan(cramped, roomy)
    }

    /// Below a floor the popover stops shrinking rather than becoming a sliver.
    func testContentStopsShrinkingAtTheFloor() {
        let total = hostedSize(screenHeight: 400).height
        XCTAssertEqual(
            total,
            SettingsMetrics.minContentHeight + SettingsMetrics.chromeHeight,
            accuracy: 1
        )
    }
}
