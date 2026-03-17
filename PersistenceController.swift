internal import CoreData
import Foundation

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "SmartSummary", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data store failed: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "HistoryRecord"
        entity.managedObjectClassName = NSStringFromClass(HistoryRecord.self)

        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .UUIDAttributeType
        id.isOptional = false

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = false

        let sourceText = NSAttributeDescription()
        sourceText.name = "sourceText"
        sourceText.attributeType = .stringAttributeType
        sourceText.isOptional = false

        let summaryText = NSAttributeDescription()
        summaryText.name = "summaryText"
        summaryText.attributeType = .stringAttributeType
        summaryText.isOptional = false

        let keyPointsData = NSAttributeDescription()
        keyPointsData.name = "keyPointsData"
        keyPointsData.attributeType = .binaryDataAttributeType
        keyPointsData.isOptional = true

        let language = NSAttributeDescription()
        language.name = "language"
        language.attributeType = .stringAttributeType
        language.isOptional = false

        let contentType = NSAttributeDescription()
        contentType.name = "contentType"
        contentType.attributeType = .stringAttributeType
        contentType.isOptional = false

        let summaryLength = NSAttributeDescription()
        summaryLength.name = "summaryLength"
        summaryLength.attributeType = .stringAttributeType
        summaryLength.isOptional = false

        let modelUsed = NSAttributeDescription()
        modelUsed.name = "modelUsed"
        modelUsed.attributeType = .stringAttributeType
        modelUsed.isOptional = false

        entity.properties = [
            id,
            createdAt,
            sourceText,
            summaryText,
            keyPointsData,
            language,
            contentType,
            summaryLength,
            modelUsed
        ]

        model.entities = [entity]
        return model
    }
}
