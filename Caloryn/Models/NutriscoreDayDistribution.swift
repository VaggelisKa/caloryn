import Foundation

enum NutriscoreDayDistribution {
    static let recognizedGrades = ["a", "b", "c", "d", "e"]

    static func distribution(of grades: [String?]) -> [(grade: String, count: Int)] {
        let logged = grades.compactMap { $0 }
        return recognizedGrades
            .map { grade in
                (grade, logged.filter { $0.lowercased() == grade }.count)
            }
            .filter { $0.count > 0 }
    }

    static func hasData(_ grades: [String?]) -> Bool {
        grades.contains { $0 != nil }
    }
}
