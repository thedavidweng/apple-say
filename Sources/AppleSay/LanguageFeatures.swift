import Foundation
import NaturalLanguage
import SwiftUI
@preconcurrency import Translation
import AppleSayCore

struct TranslationSuggestion: Equatable {
    let source: Locale.Language
    let target: Locale.Language
    let sourceName: String
    let targetName: String
}

struct TranslationRequest: Equatable {
    let source: Locale.Language
    let target: Locale.Language
    let document: String
}

struct TranslationDetectionInput: Hashable {
    let document: String
    let targetIdentifier: String
    let dismissedTargetIdentifier: String?
    let writingToolsActive: Bool
}

struct TranslationProposal: Identifiable {
    let id = UUID()
    let original: String
    let translated: String
    let targetName: String
}

enum NativeLanguageFeatures {
    @available(macOS 15.0, *)
    static func translationSuggestion(
        for document: String,
        targetIdentifier: String,
        displayLocale: Locale
    ) async -> TranslationSuggestion? {
        guard !targetIdentifier.isEmpty,
              let plan = DocumentTranslationPlan(document: document) else { return nil }
        let sample = plan.units.map(\.text).joined(separator: "\n")
        guard sample.count >= 4 else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        let requiredConfidence = sample.count < 30 ? 0.9 : 0.7
        guard let hypothesis = recognizer.languageHypotheses(withMaximum: 1).first,
              hypothesis.value >= requiredConfidence else { return nil }

        let source = Locale.Language(identifier: hypothesis.key.rawValue)
        let target = Locale(identifier: targetIdentifier).language
        guard !source.isEquivalent(to: target) else { return nil }

        let status = await LanguageAvailability().status(from: source, to: target)
        guard status != .unsupported else { return nil }
        return TranslationSuggestion(
            source: source,
            target: target,
            sourceName: displayLocale.localizedString(forIdentifier: source.minimalIdentifier)
                ?? source.minimalIdentifier,
            targetName: displayLocale.localizedString(forIdentifier: target.minimalIdentifier)
                ?? target.minimalIdentifier
        )
    }

    @available(macOS 15.0, *)
    @MainActor
    static func translate(_ request: TranslationRequest, using session: TranslationSession) async throws -> String {
        guard let plan = DocumentTranslationPlan(document: request.document) else {
            throw TranslationError.nothingToTranslate
        }
        var translations: [String] = []
        translations.reserveCapacity(plan.units.count)
        // TranslationSession's batch request is not Sendable in the current SDK.
        // Keep each call on the SwiftUI-owned session instead of weakening Swift 6 isolation.
        for unit in plan.units {
            translations.append(try await session.translate(unit.text).targetText)
        }
        return plan.applying(translations)
    }
}

@available(macOS 15.0, *)
struct TranslationRunner: View {
    let request: TranslationRequest
    let completion: (Result<String, Error>) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(source: request.source, target: request.target) { session in
                do {
                    completion(.success(try await NativeLanguageFeatures.translate(request, using: session)))
                } catch {
                    completion(.failure(error))
                }
            }
            .accessibilityHidden(true)
    }
}

struct TranslationReviewSheet: View {
    let proposal: TranslationProposal
    let strings: AppStrings
    let cancel: () -> Void
    let replace: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(strings.text("Review Translation", "检查翻译"))
                .font(.title2.bold())
            Text(strings.text(
                "Translated to \(proposal.targetName) on this Mac. Review the result before replacing the Document.",
                "已在此 Mac 上翻译为\(proposal.targetName)。请在替换文稿前检查结果。"
            ))
            .foregroundStyle(.secondary)

            HSplitView {
                reviewColumn(title: strings.text("Original", "原文"), text: proposal.original)
                reviewColumn(title: strings.text("Translation", "译文"), text: proposal.translated)
            }

            HStack {
                Spacer()
                Button(strings.text("Cancel", "取消"), action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button(strings.text("Replace Document", "替换文稿"), action: replace)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 440)
    }

    private func reviewColumn(title: String, text: String) -> some View {
        GroupBox(title) {
            ScrollView {
                Text(text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 280)
    }
}
