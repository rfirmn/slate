import Foundation
import CoreData

/// Managed objects never leave the context queue. Only Codable values cross actor boundaries.
actor LocalStore {
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext
    init(inMemory: Bool = false, storeURL: URL? = nil) async throws {
        let entity = NSEntityDescription(); entity.name = "Record"; entity.managedObjectClassName = "NSManagedObject"
        entity.properties = [("key", NSAttributeType.stringAttributeType), ("scope", .stringAttributeType), ("kind", .stringAttributeType), ("payload", .binaryDataAttributeType)].map { name, type in
            let a = NSAttributeDescription(); a.name = name; a.attributeType = type; a.isOptional = false; return a
        }
        entity.uniquenessConstraints = [["scope", "kind", "key"]]
        let model = NSManagedObjectModel(); model.entities = [entity]
        let persistent = NSPersistentContainer(name: "Slate", managedObjectModel: model)
        container = persistent
        let description = NSPersistentStoreDescription()
        if inMemory { description.type = NSInMemoryStoreType } else {
            if let storeURL {
                try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                description.url = storeURL
            } else {
                let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Slate", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                description.url = directory.appendingPathComponent("Slate.sqlite")
            }
        }
        description.shouldMigrateStoreAutomatically = true; description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in persistent.loadPersistentStores { _, error in if let error { continuation.resume(throwing: error) } else { continuation.resume() } } }
        context = persistent.newBackgroundContext()
    }
    func put<T: Encodable & Sendable>(_ value: T, key: String, scope: String, kind: String) async throws {
        let data = try JSONCoding.encoder().encode(value)
        let context = self.context
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Record"); request.predicate = NSPredicate(format: "scope == %@ AND kind == %@ AND key == %@", scope, kind, key); request.fetchLimit = 1
            let object = try context.fetch(request).first ?? NSEntityDescription.insertNewObject(forEntityName: "Record", into: context)
            object.setValue(key, forKey: "key"); object.setValue(scope, forKey: "scope"); object.setValue(kind, forKey: "kind"); object.setValue(data, forKey: "payload"); try context.save()
        }
    }
    func values<T: Decodable & Sendable>(scope: String, kind: String, as: T.Type = T.self) async throws -> [T] {
        let context = self.context
        let blobs: [Data] = try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Record"); request.predicate = NSPredicate(format: "scope == %@ AND kind == %@", scope, kind)
            return try context.fetch(request).compactMap { $0.value(forKey: "payload") as? Data }
        }
        return try blobs.map { try JSONCoding.decoder().decode(T.self, from: $0) }
    }
    func remove(key: String? = nil, scope: String, kind: String? = nil) async throws {
        let context = self.context
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Record")
            var predicates = [NSPredicate(format: "scope == %@", scope)]
            if let key { predicates.append(NSPredicate(format: "key == %@", key)) }; if let kind { predicates.append(NSPredicate(format: "kind == %@", kind)) }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            for object in try context.fetch(request) { context.delete(object) }; try context.save()
        }
    }
    func close() throws {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores { try coordinator.remove(store) }
    }
}
