import Foundation

// Render inline markdown (**bold**, *italic*, `code`) into an AttributedString, preserving
// whitespace; falls back to the raw string. Reasoning models (deepseek-v4-flash) often format
// with markdown, so all model-generated text is shown through this.
extension String {
    var echoMarkdown: AttributedString {
        (try? AttributedString(markdown: self, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible))) ?? AttributedString(self)
    }
}

// DTOs matching echo-api responses.

struct AccountResponse: Decodable {
    let token: String
    let deviceSecret: String?
    let player: Player?
}
struct Player: Decodable { let display: String }

struct Turn: Decodable, Equatable {
    let n: Int
    let reaction: String
    let question: String
    let answer_type: String          // chips | slider | text
    let options: [String]?
    let slider_labels: [String]?
}

struct Hypothesis: Decodable, Equatable {
    let tags: [String]?
    let prediction: String?
}
struct Seal: Decodable, Equatable {
    let hash: String?
    let hypothesis: Hypothesis?
    let salt: String?
}

struct Progress: Decodable, Equatable { let answered: Int; let total: Int }

struct StartResponse: Decodable {
    let sessionId: String
    let total: Int
    let turn: Turn
}

struct AnswerResponse: Decodable {
    let done: Bool
    let progress: Progress
    let turn: Turn?
    let seal: Seal?
    let portrait: Portrait?
}

struct PortraitBody: Decodable, Equatable {
    let who: String
    let decide: String
    let value: String
    let blindspot: String
}
struct Portrait: Decodable, Equatable {
    let archetype: String
    let traits: [String]
    let portrait: PortraitBody
    let quotable: String
}

// An answer the player composes for the current turn.
enum AnswerKind {
    case chip(String)
    case slider(Int)
    case text(String)

    /// The string the server expects (slider sends "<n>/100").
    var payload: String {
        switch self {
        case .chip(let s): return s
        case .slider(let n): return "\(n)/100"
        case .text(let s): return s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
