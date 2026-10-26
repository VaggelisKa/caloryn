import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite("Chatbot log instructions")
struct ChatbotLogInstructionsTests {
    private static func fieldNames(in link: String) -> [String] {
        link.split(separator: "?", maxSplits: 1)
            .last
            .map { $0.split(separator: "&").map { String($0.prefix { $0 != "=" }) } } ?? []
    }

    @Test("The example line in the instructions parses to the food it describes")
    func exampleParses() {
        #expect(
            LogLinkDraft.parse(ChatbotLogInstructions.exampleLink) == .success(
                LogLinkDraft(
                    name: "Greek yogurt with honey",
                    kcal: 212,
                    grams: 200,
                    proteinG: 18.5,
                    carbsG: 24,
                    fatG: 4.2,
                    meal: nil
                )
            )
        )
    }

    @Test("The template and the example each stand on a line of their own")
    func linesStandAlone() {
        let lines = ChatbotLogInstructions.text.components(separatedBy: "\n")

        #expect(lines.contains(ChatbotLogInstructions.linkTemplate))
        #expect(lines.contains(ChatbotLogInstructions.exampleLink))
    }

    @Test("The example uses the template's fields in the template's order, name right after v")
    func exampleFollowsTemplate() {
        let templateFields = Self.fieldNames(in: ChatbotLogInstructions.linkTemplate)

        #expect(templateFields == ["v", "name", "kcal", "grams", "protein", "carbs", "fat"])
        #expect(Self.fieldNames(in: ChatbotLogInstructions.exampleLink) == templateFields)
    }

    @Test("Pasting the instructions themselves logs nothing")
    func instructionsAreNotALoggableLink() {
        #expect(LogLinkDraft.parse(ChatbotLogInstructions.text) == .failure(.multipleLinks))
    }

    @Test(
        "The instructions tell the chatbot every rule the parser enforces",
        arguments: [
            "exactly one line inside a code block",
            "Put name right after v=1",
            "percent-encode every character that is not an English letter (A–Z, a–z) or a digit (0–9)",
            "A space is %20, never +",
            "a dot for decimals",
            "no commas, units or spaces",
            "totals for the whole portion",
            "Always include grams",
            "leave that field out. Never write 0 for a value you don’t know",
            "Don’t add any other fields",
            "One food per line",
        ]
    )
    func rulesAreStated(rule: String) {
        #expect(ChatbotLogInstructions.text.contains(rule))
    }
}
