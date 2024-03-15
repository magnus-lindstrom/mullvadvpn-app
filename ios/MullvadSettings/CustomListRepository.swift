//
//  CustomListRepository.swift
//  MullvadVPN
//
//  Created by Mojgan on 2024-01-25.
//  Copyright © 2024 Mullvad VPN AB. All rights reserved.
//

import Combine
import Foundation
import MullvadLogging
import MullvadTypes

public enum CustomRelayListError: LocalizedError, Equatable {
    case duplicateName

    public var errorDescription: String? {
        switch self {
        case .duplicateName:
            NSLocalizedString(
                "DUPLICATE_CUSTOM_LISTS_ERROR",
                tableName: "CustomLists",
                value: "Name is already taken.",
                comment: ""
            )
        }
    }
}

public struct CustomListRepository: CustomListRepositoryProtocol {
    private let logger = Logger(label: "CustomListRepository")

    private let settingsParser: SettingsParser = {
        SettingsParser(decoder: JSONDecoder(), encoder: JSONEncoder())
    }()

    public init() {}

    public func save(list: CustomList) throws {
        var lists = fetchAll()

        if let index = lists.firstIndex(where: { $0.id == list.id }) {
            lists[index] = list
            try write(lists)
        } else if lists.contains(where: { $0.name == list.name }) {
            throw CustomRelayListError.duplicateName
        } else {
            lists.append(list)
            try write(lists)
        }
    }

    public func delete(id: UUID) {
        do {
            var lists = fetchAll()
            if let index = lists.firstIndex(where: { $0.id == id }) {
                lists.remove(at: index)
                try write(lists)
            }
        } catch {
            logger.error(error: error)
        }
    }

    public func fetch(by id: UUID) -> CustomList? {
        try? read().first(where: { $0.id == id })
    }

    public func fetchAll() -> [CustomList] {
        (try? read()) ?? []
    }
}

extension CustomListRepository {
    private func read() throws -> [CustomList] {
        let data = try SettingsManager.store.read(key: .customRelayLists)

        return try settingsParser.parseUnversionedPayload(as: [CustomList].self, from: data)
    }

    private func write(_ list: [CustomList]) throws {
        let data = try settingsParser.produceUnversionedPayload(list)

        try SettingsManager.store.write(data, for: .customRelayLists)
    }
}
