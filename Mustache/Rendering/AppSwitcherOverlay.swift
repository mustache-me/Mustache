//
//  AppSwitcherOverlay.swift
//  Mustache
//
//  App Switcher Overlay - Shows app icons with numbers in center of screen
//

import AppKit
import SwiftUI

struct AppSwitcherItem: View {
    let app: TrackedApplication
    let isHighlighted: Bool
    let badgeStyle: BadgeStyle

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isHighlighted ? Color.white : Color.clear, lineWidth: 2.5)
                )
                .scaleEffect(isHighlighted ? 1.05 : 1.0)

            if let key = app.assignedKey {
                CircularBadgeView(
                    key: key,
                    style: badgeStyle,
                    isHighlighted: isHighlighted,
                    showBorder: true
                )
                .offset(x: -3, y: -3)
            }
        }
        .frame(width: 64, height: 64)
        .contentShape(Rectangle())
    }
}

struct AppSwitcherOverlay: View {
    let applications: [TrackedApplication]
    let highlightedNumber: Int?
    let badgeStyle: BadgeStyle
    let itemsPerRow: Int
    let rowCount: Int

    var body: some View {
        let appsWithNumbers = applications.filter { $0.assignedNumber != nil }

        if rowCount == 1 {
            HStack(spacing: 12) {
                ForEach(appsWithNumbers, id: \.bundleIdentifier) { app in
                    let isHighlighted = app.assignedNumber == highlightedNumber
                    AppSwitcherItem(app: app, isHighlighted: isHighlighted, badgeStyle: badgeStyle)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all)
        } else {
            VStack(spacing: 12) {
                ForEach(0 ..< rowCount, id: \.self) { rowIndex in
                    let startIndex = rowIndex * itemsPerRow
                    if startIndex < appsWithNumbers.count {
                        let endIndex = min(startIndex + itemsPerRow, appsWithNumbers.count)
                        let rowApps = Array(appsWithNumbers[startIndex ..< endIndex])

                        HStack(spacing: 12) {
                            ForEach(rowApps, id: \.bundleIdentifier) { app in
                                let isHighlighted = app.assignedNumber == highlightedNumber
                                AppSwitcherItem(app: app, isHighlighted: isHighlighted, badgeStyle: badgeStyle)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all)
        }
    }
}

class AppSwitcherWindow: NSPanel {
    private var hostingController: NSViewController?
    private var badgeStyle: BadgeStyle = .init()

    init(badgeStyle: BadgeStyle = BadgeStyle()) {
        self.badgeStyle = badgeStyle
        guard let _ = NSScreen.main else {
            super.init(
                contentRect: .zero,
                styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            return
        }

        let windowRect = NSRect(x: 0, y: 0, width: 900, height: 120)

        super.init(
            contentRect: windowRect,
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        center()
        isFloatingPanel = false
        hidesOnDeactivate = false
        isOpaque = true
        backgroundColor = NSColor.windowBackgroundColor
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        styleMask.remove([.closable, .miniaturizable, .resizable])

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func updateContent(applications: [TrackedApplication], highlightedNumber: Int? = nil, badgeStyle: BadgeStyle? = nil, layoutMode: LayoutMode = .dynamic, gridRows: Int = 2, gridColumns: Int = 5) {
        if let newStyle = badgeStyle {
            self.badgeStyle = newStyle
        }

        let appsWithNumbers = applications.filter { $0.assignedNumber != nil }
        let appCount = appsWithNumbers.count

        guard let screen = NSScreen.main else { return }
        let screenWidth = screen.frame.width

        let padding: CGFloat = 20
        let iconWidth: CGFloat = 64
        let spacing: CGFloat = 12

        let itemsPerRow: Int
        let rowCount: Int
        let iconsInWidestRow: Int

        switch layoutMode {
        case .grid:
            itemsPerRow = gridColumns
            let actualRowsNeeded = (appCount + gridColumns - 1) / gridColumns
            rowCount = min(gridRows, actualRowsNeeded)

            let remainder = appCount % gridColumns
            if remainder > 0, actualRowsNeeded <= gridRows {
                iconsInWidestRow = gridColumns
            } else {
                iconsInWidestRow = gridColumns
            }

        case .dynamic:
            let maxWindowWidth = screenWidth * 0.8
            let maxFitInOneRow = max(1, Int((maxWindowWidth - 2 * padding + spacing) / (iconWidth + spacing)))

            if appCount <= maxFitInOneRow {
                itemsPerRow = appCount
                rowCount = 1
                iconsInWidestRow = appCount
            } else {
                rowCount = (appCount + maxFitInOneRow - 1) / maxFitInOneRow
                itemsPerRow = (appCount + rowCount - 1) / rowCount
                iconsInWidestRow = itemsPerRow
            }
        }

        let overlayView = AppSwitcherOverlay(
            applications: applications,
            highlightedNumber: highlightedNumber,
            badgeStyle: self.badgeStyle,
            itemsPerRow: itemsPerRow,
            rowCount: rowCount
        )

        if let existingController = hostingController as? NSHostingController<AppSwitcherOverlay> {
            existingController.rootView = overlayView
        } else {
            let controller = NSHostingController(rootView: overlayView)
            controller.view.wantsLayer = true
            controller.view.layer?.backgroundColor = NSColor.clear.cgColor

            contentViewController = controller
            hostingController = controller as NSViewController
        }

        let contentWidth = CGFloat(iconsInWidestRow * 64 + max(0, iconsInWidestRow - 1) * 12)
        let windowWidth = contentWidth + (padding * 2)

        let contentHeight = CGFloat(rowCount * 64 + max(0, rowCount - 1) * 12)
        let windowHeight = contentHeight + 26

        var newFrame = frame
        newFrame.size = NSSize(width: windowWidth, height: windowHeight)

        let screenFrame = screen.frame
        newFrame.origin.x = screenFrame.midX - (windowWidth / 2)
        newFrame.origin.y = screenFrame.midY - (windowHeight / 2)

        setFrame(newFrame, display: true)
    }
}
