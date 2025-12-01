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
    let iconSize: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.21875)) // 14/64 ratio
                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: iconSize * 0.21875)
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
        .frame(width: iconSize, height: iconSize)
        .contentShape(Rectangle())
    }
}

struct AppSwitcherOverlay: View {
    let applications: [TrackedApplication]
    let highlightedNumber: Int?
    let badgeStyle: BadgeStyle
    let itemsPerRow: Int
    let rowCount: Int
    let iconSize: CGFloat
    let maxAppsToShow: Int

    var body: some View {
        let appsWithNumbers = applications.filter { $0.assignedNumber != nil }
        let appsToDisplay = Array(appsWithNumbers.prefix(maxAppsToShow))

        if rowCount == 1 {
            HStack(spacing: 12) {
                // In single row mode, show up to itemsPerRow apps
                ForEach(appsToDisplay, id: \.bundleIdentifier) { app in
                    let isHighlighted = app.assignedNumber == highlightedNumber
                    AppSwitcherItem(app: app, isHighlighted: isHighlighted, badgeStyle: badgeStyle, iconSize: iconSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all)
        } else {
            VStack(spacing: 12) {
                ForEach(0 ..< rowCount, id: \.self) { rowIndex in
                    let startIndex = rowIndex * itemsPerRow
                    if startIndex < appsToDisplay.count {
                        let endIndex = min(startIndex + itemsPerRow, appsToDisplay.count)
                        let rowApps = Array(appsToDisplay[startIndex ..< endIndex])

                        HStack(spacing: 12) {
                            ForEach(rowApps, id: \.bundleIdentifier) { app in
                                let isHighlighted = app.assignedNumber == highlightedNumber
                                AppSwitcherItem(app: app, isHighlighted: isHighlighted, badgeStyle: badgeStyle, iconSize: iconSize)
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

    func updateContent(applications: [TrackedApplication], highlightedNumber: Int? = nil, badgeStyle: BadgeStyle? = nil, layoutMode: LayoutMode = .dynamic, gridRows: Int = 2, gridColumns: Int = 5, maxTrackedApplications: Int = 10) {
        if let newStyle = badgeStyle {
            self.badgeStyle = newStyle
        }

        let appsWithNumbers = applications.filter { $0.assignedNumber != nil }
        let appCount = appsWithNumbers.count

        guard let screen = NSScreen.main else { return }
        let screenWidth = screen.frame.width

        let padding: CGFloat = 20
        let baseIconSize: CGFloat = 64
        let spacing: CGFloat = 12

        let itemsPerRow: Int
        let rowCount: Int
        let iconsInWidestRow: Int

        let maxAppsToShow: Int

        switch layoutMode {
        case .grid:
            // In grid mode, the grid dimensions define the maximum apps to show
            let maxAppsInGrid = gridRows * gridColumns
            maxAppsToShow = min(appCount, maxAppsInGrid)

            itemsPerRow = gridColumns
            let actualRowsNeeded = (maxAppsToShow + gridColumns - 1) / gridColumns
            rowCount = min(gridRows, actualRowsNeeded)

            // Calculate the widest row based on actual app distribution
            if rowCount == 1 {
                // Single row: show up to itemsPerRow (gridColumns) apps
                iconsInWidestRow = min(maxAppsToShow, itemsPerRow)
            } else {
                // Multiple rows: widest row has gridColumns (except possibly the last row)
                let appsInLastRow = maxAppsToShow % gridColumns
                if appsInLastRow == 0 {
                    iconsInWidestRow = gridColumns
                } else {
                    // Last row might have fewer apps, but we size for gridColumns for consistency
                    iconsInWidestRow = gridColumns
                }
            }

        case .dynamic:
            // In dynamic mode, respect maxTrackedApplications
            maxAppsToShow = min(appCount, maxTrackedApplications)

            let maxWindowWidth = screenWidth * 0.8
            let maxFitInOneRow = max(1, Int((maxWindowWidth - 2 * padding + spacing) / (baseIconSize + spacing)))

            if maxAppsToShow <= maxFitInOneRow {
                itemsPerRow = maxAppsToShow
                rowCount = 1
                iconsInWidestRow = maxAppsToShow
            } else {
                rowCount = (maxAppsToShow + maxFitInOneRow - 1) / maxFitInOneRow
                itemsPerRow = (maxAppsToShow + rowCount - 1) / rowCount
                iconsInWidestRow = itemsPerRow
            }
        }

        // Calculate icon size - reduce if needed to fit all icons
        let maxAvailableWidth = screenWidth * 0.9 - (2 * padding)
        let requiredWidthAtBaseSize = CGFloat(iconsInWidestRow) * baseIconSize + CGFloat(max(0, iconsInWidestRow - 1)) * spacing

        let iconSize: CGFloat
        if requiredWidthAtBaseSize > maxAvailableWidth {
            // Calculate smaller icon size to fit
            let minIconSize: CGFloat = 32 // Minimum icon size
            let calculatedSize = (maxAvailableWidth - CGFloat(max(0, iconsInWidestRow - 1)) * spacing) / CGFloat(iconsInWidestRow)
            iconSize = max(minIconSize, calculatedSize)
        } else {
            iconSize = baseIconSize
        }

        let overlayView = AppSwitcherOverlay(
            applications: applications,
            highlightedNumber: highlightedNumber,
            badgeStyle: self.badgeStyle,
            itemsPerRow: itemsPerRow,
            rowCount: rowCount,
            iconSize: iconSize,
            maxAppsToShow: maxAppsToShow
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

        let contentWidth = CGFloat(iconsInWidestRow) * iconSize + CGFloat(max(0, iconsInWidestRow - 1)) * spacing
        let windowWidth = contentWidth + (padding * 2)

        let contentHeight = CGFloat(rowCount) * iconSize + CGFloat(max(0, rowCount - 1)) * spacing
        let windowHeight = contentHeight + (padding * 2)

        var newFrame = frame
        newFrame.size = NSSize(width: windowWidth, height: windowHeight)

        let screenFrame = screen.frame
        newFrame.origin.x = screenFrame.midX - (windowWidth / 2)
        newFrame.origin.y = screenFrame.midY - (windowHeight / 2)

        setFrame(newFrame, display: true)
    }
}
