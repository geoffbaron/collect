import SwiftUI

/// Hosts the entire scan flow in one NavigationStack inside a sheet.
/// Steps: PromptSelection → (optional) RoomLayout scan → VideoCapture → AnalysisProgress → Results
struct ScanFlowView: View {
    let room: Room
    @Binding var isPresented: Bool

    enum Step {
        case promptSelection
        case videoCapture(PromptTemplate, RoomLayout?)
        case analysis(PromptTemplate, URL, RoomLayout?)
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
                step = .results(template, scanResult, url, layout)
            } onFailed: { _ in
                // Stay on analysis screen — it shows a retry button
            }

        case .results(let template, let scanResult, let url, let layout):
            ResultsView(
                room: room,
                template: template,
                scanResult: scanResult,
                videoURL: url,
                capturedLayout: layout
            ) {
                isPresented = false
            }
        }
    }
}
