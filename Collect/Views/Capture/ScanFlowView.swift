import SwiftUI

/// Hosts the entire scan flow in one NavigationStack inside a sheet.
/// Steps: PromptSelection → (optional) RoomLayout scan → VideoCapture → AnalysisProgress → Results
struct ScanFlowView: View {
    let room: Room
    @Binding var isPresented: Bool
    @EnvironmentObject private var limitsService: LimitsService

    enum Step {
        case promptSelection
        case videoCapture(PromptTemplate, RoomLayout?)
        case analysis(PromptTemplate, URL, RoomLayout?)
        case groupReview(PromptTemplate, ScanResult, URL, RoomLayout?)
        case results(PromptTemplate, ScanResult, URL, RoomLayout?)
    }

    @State private var step: Step = .promptSelection
    @State private var showLayoutScan = false
    @State private var capturedLayout: RoomLayout?
    @State private var pendingTemplate: PromptTemplate?

    var body: some View {
        NavigationStack {
            currentView
                .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $showLayoutScan) {
            RoomScanSheet(roomName: room.name) { layout in
                capturedLayout = layout
                if let template = pendingTemplate {
                    step = .videoCapture(template, layout)
                }
                pendingTemplate = nil
            } onCancel: {
                // User skipped layout scan — proceed to video without layout
                if let template = pendingTemplate {
                    step = .videoCapture(template, capturedLayout)
                }
                pendingTemplate = nil
            }
        }
    }

    @ViewBuilder
    private var currentView: some View {
        switch step {
        case .promptSelection:
            PromptSelectionView(room: room) { template, includeLayout in
                if includeLayout {
                    pendingTemplate = template
                    showLayoutScan = true
                } else {
                    // Use existing room layout (or nil) without rescanning
                    let existing = room.layoutData.flatMap { RoomLayout.from($0) }
                    step = .videoCapture(template, existing)
                }
            } onCancel: {
                isPresented = false
            }

        case .videoCapture(let template, let layout):
            VideoCaptureView(room: room, template: template) { videoURL in
                step = .analysis(template, videoURL, layout)
            }

        case .analysis(let template, let url, let layout):
            AnalysisProgressView(
                room: room,
                template: template,
                videoURL: url
            ) { scanResult in
                // Route through group review if AI flagged possible duplicates
                if scanResult.possibleDuplicateGroups.isEmpty {
                    step = .results(template, scanResult, url, layout)
                } else {
                    step = .groupReview(template, scanResult, url, layout)
                }
            } onFailed: { _ in
                // Stay on analysis screen — it shows a retry button
            }

        case .groupReview(let template, let scanResult, let url, let layout):
            GroupReviewView(scanResult: scanResult) { resolvedAssets in
                // Build a new ScanResult with the user's grouping decisions applied
                let resolved = ScanResult(assets: resolvedAssets, selectedFrames: scanResult.selectedFrames)
                step = .results(template, resolved, url, layout)
            }

        case .results(let template, let scanResult, let url, let layout):
            ResultsView(
                room: room,
                template: template,
                scanResult: scanResult,
                videoURL: url,
                capturedLayout: layout
            ) {
                Task { await limitsService.refreshUsage() }
                isPresented = false
            }
        }
    }
}
