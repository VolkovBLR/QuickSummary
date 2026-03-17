internal import CoreData
import Foundation

@objc(HistoryRecord)
final class HistoryRecord: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<HistoryRecord> {
        NSFetchRequest<HistoryRecord>(entityName: "HistoryRecord")
    }

    @NSManaged var id: UUID
    @NSManaged var createdAt: Date
    @NSManaged var sourceText: String
    @NSManaged var summaryText: String
    @NSManaged var keyPointsData: Data?
    @NSManaged var language: String
    @NSManaged var contentType: String
    @NSManaged var summaryLength: String
    @NSManaged var modelUsed: String
}

extension HistoryRecord {
    var keyPointsList: [String] {
        get {
            guard let data = keyPointsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            keyPointsData = try? JSONEncoder().encode(newValue)
        }
    }
}
