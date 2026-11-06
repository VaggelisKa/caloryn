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
                    nutrients: [
                        .protein: 18.5, .carbs: 24, .fat: 4.2, .fiber: 0,
                        .sugars: 22.5, .saturatedFat: 2.6, .sodium: 0.072
                    ],
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

        #expect(templateFields == [
            "v", "name", "kcal", "grams", "protein", "carbs", "fat", "fiber", "sugars", "saturated_fat", "sodium_mg",
        ])
        #expect(Self.fieldNames(in: ChatbotLogInstructions.exampleLink) == templateFields)
    }

    @Test("The template begins with the current version, which the parser accepts")
    func templateUsesCurrentVersion() {
        #expect(ChatbotLogInstructions.linkTemplate.hasPrefix("caloryn://log?v=2&name="))
        #expect(LogLinkDraft.supportedVersions.contains(LogLinkDraft.currentVersion))
    }

    @Test("Every nutrient the parser accepts is named in the instructions exactly once")
    func everyNutrientIsNamed() {
        let named = ChatbotLogInstructions.templateNutrients + ChatbotLogInstructions.extraNutrients

        #expect(Set(named) == Set(LogLinkNutrient.allCases))
        #expect(named.count == LogLinkNutrient.allCases.count)
        for nutrient in LogLinkNutrient.allCases {
            #expect(ChatbotLogInstructions.text.contains(nutrient.rawValue), "\(nutrient.rawValue)")
        }
    }

    @Test("Pasting the instructions themselves logs nothing")
    func instructionsAreNotALoggableLink() {
        #expect(LogLinkDraft.parse(ChatbotLogInstructions.text) == .failure(.multipleLinks))
    }

    @Test(
        "The instructions tell the chatbot every rule the parser enforces",
        arguments: [
            "exactly one line inside a code block",
            "Put name right after v=2",
            "percent-encode every character that is not an English letter (A–Z, a–z) or a digit (0–9)",
            "A space is %20, never +",
            "a dot for decimals",
            "no commas, units or spaces",
            "a total for the whole portion",
            "sodium_mg and cholesterol_mg are in milligrams",
            "only when you know the value: added_sugars, sucrose,",
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
