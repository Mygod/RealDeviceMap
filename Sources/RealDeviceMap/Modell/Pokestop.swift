//
//  Gym.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import Foundation
import PerfectLib
import PerfectMySQL
import POGOProtos

class Pokestop: JSONConvertibleObject, WebHookEvent, Hashable {
    
    class ParsingError: Error {}
    
    override func getJSONValues() -> [String : Any] {
        return [
            "id":id,
            "lat":lat,
            "lon":lon,
            "name":name as Any,
            "url":url as Any,
            "lure_expire_timestamp":lureExpireTimestamp as Any,
            "last_modified_timestamp":lastModifiedTimestamp as Any,
            "enabled":enabled as Any,
            "quest_type": questType as Any,
            "quest_target": questTarget as Any,
            "quest_template": questTemplate as Any,
            "quest_conditions": questConditions as Any,
            "quest_rewards": questRewards as Any,
            "quest_timestamp": questTimestamp as Any,
            "updated": updated
        ]
    }
    
    func getWebhookValues(type: String) -> [String : Any] {
        if type == "quest" {
            let message: [String: Any] = [
                "pokestop_id":id,
                "latitude":lat,
                "longitude":lon,
                "type": questType!,
                "target": questTarget!,
                "template": questTemplate!,
                "conditions": questConditions!,
                "rewards": questRewards!,
                "updated": questTimestamp!
            ]
            return [
                "type": "quest",
                "message": message
            ]
        } else {
            let message: [String: Any] = [
                "pokestop_id":id,
                "latitude":lat,
                "longitude":lon,
                "name":name ?? "Unknown",
                "url":url ?? "",
                "lure_expiration":lureExpireTimestamp ?? 0,
                "last_modified":lastModifiedTimestamp ?? 0,
                "enabled":enabled ?? true,
                "updated": updated
            ]
            return [
                "type": "pokestop",
                "message": message
            ]
        }
    }
    
    public var hashValue: Int {
        return id.hashValue
    }
    
    var id: String
    var lat: Double
    var lon: Double
    
    var enabled: Bool?
    var lureExpireTimestamp: UInt32?
    var lastModifiedTimestamp: UInt32?
    var name: String?
    var url: String?
    var updated: UInt32
    
    var questType: UInt32?
    var questTemplate: String?
    var questTarget: UInt16?
    var questTimestamp: UInt32?
    var questConditions: [[String: Any]]?
    var questRewards: [[String: Any]]?
    
    init(id: String, lat: Double, lon: Double, name: String?, url: String?, enabled: Bool?, lureExpireTimestamp: UInt32?, lastModifiedTimestamp: UInt32?, updated: UInt32, questType: UInt32?, questTarget: UInt16?, questTimestamp: UInt32?, questConditions: [[String: Any]]?, questRewards: [[String: Any]]?, questTemplate: String?) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.name = name
        self.url = url
        self.enabled = enabled
        self.lureExpireTimestamp = lureExpireTimestamp
        self.lastModifiedTimestamp = lastModifiedTimestamp
        self.updated = updated
        self.questType = questType
        self.questTarget = questTarget
        self.questTimestamp = questTimestamp
        self.questConditions = questConditions
        self.questRewards = questRewards
        self.questTemplate = questTemplate
    }
    
    init(json: [String: Any]) throws {
        
        guard
            let id = json["pokestop_id"] as? String,
            let lat = json["latitude"] as? Double,
            let lon = json["longitude"] as? Double
        else {
            throw ParsingError()
        }
        let enabled = json["enabled"] as? Bool
        var lastModifiedTimestamp = json["last_modified"] as? Int
        var lureExpireTimestamp = json["lure_expiration"] as? Int
        let url = json["imageURL"] as? String
        
        if lastModifiedTimestamp != nil {
            lastModifiedTimestamp = lastModifiedTimestamp! / 1000
        }
        if lureExpireTimestamp != nil {
            lureExpireTimestamp = lureExpireTimestamp! / 1000
        }
        
        self.id = id
        self.lat = lat
        self.lon = lon
        self.enabled = enabled
        self.lastModifiedTimestamp = lastModifiedTimestamp?.toUInt32()
        self.lureExpireTimestamp = lureExpireTimestamp?.toUInt32()
        if url != "" {
            self.url = url
        }
  
        self.updated = UInt32(Date().timeIntervalSince1970)
    }
    
    init(fortData: POGOProtos_Map_Fort_FortData) {
        
        self.id = fortData.id
        self.lat = fortData.latitude
        self.lon = fortData.longitude
        self.enabled = fortData.enabled
        self.lureExpireTimestamp = UInt32(fortData.lureInfo.lureExpiresTimestampMs / 1000)
        self.lastModifiedTimestamp = UInt32(fortData.lastModifiedTimestampMs / 1000)
        if fortData.imageURL != "" {
            self.url = fortData.imageURL
        }
        
        self.updated = UInt32(Date().timeIntervalSince1970)
        
    }
    
    public func addDetails(fortData: POGOProtos_Networking_Responses_FortDetailsResponse) {
        
        self.id = fortData.fortID
        self.lat = fortData.latitude
        self.lon = fortData.longitude
        if !fortData.imageUrls.isEmpty {
            self.url = fortData.imageUrls[0]
        }
        self.name = fortData.name
        
        self.updated = UInt32(Date().timeIntervalSince1970)
        
    }
    
    public func addQuest(questData: POGOProtos_Data_Quests_Quest) {
        
        self.questType = questData.questType.rawValue.toUInt32()
        self.questTarget = UInt16(questData.goal.target)
        self.questTemplate = questData.templateID.lowercased()
        
        var conditions = [[String: Any]]()
        var rewards = [[String: Any]]()
        
        for conditionData in questData.goal.condition {
            var condition = [String: Any]()
            var infoData = [String: Any]()
            condition["type"] = conditionData.type.rawValue
            
            switch conditionData.type {
            case .withBadgeType:
                let info = conditionData.withBadgeType
                infoData["amount"] = info.amount
                infoData["badge_rank"] = info.badgeRank
                var badgeTypesById = [Int]()
                for badge in info.badgeType {
                    badgeTypesById.append(badge.rawValue)
                }
                infoData["badge_types"] = badgeTypesById
            case .withItem:
                let info = conditionData.withItem
                if info.item.rawValue != 0 {
                    infoData["item_id"] = info.item.rawValue
                }
            case .withRaidLevel:
                let info = conditionData.withRaidLevel
                var raidLevelById = [Int]()
                for raidLevel in info.raidLevel {
                    raidLevelById.append(raidLevel.rawValue)
                }
                infoData["raid_levels"] = raidLevelById
            case .withPokemonType:
                let info = conditionData.withPokemonType
                var pokemonTypesById = [Int]()
                for type in info.pokemonType {
                    pokemonTypesById.append(type.rawValue)
                }
                infoData["pokemon_type_ids"] = pokemonTypesById
            case .withPokemonCategory:
                let info = conditionData.withPokemonCategory
                if info.categoryName != "" {
                    infoData["category_name"] = info.categoryName
                }
                var pokemonById = [Int]()
                for pokemon in info.pokemonIds {
                    pokemonById.append(pokemon.rawValue)
                }
                infoData["pokemon_ids"] = pokemonById
            case .withWinRaidStatus: break
            case .withThrowType:
                let info = conditionData.withThrowType
                if info.throwType.rawValue != 0 {
                    infoData["throw_type_id"] = info.throwType.rawValue
                }
                infoData["hit"] = info.hit
            case .withThrowTypeInARow:
                if conditionData.hasWithThrowType {
                    let info = conditionData.withThrowType
                    if info.throwType.rawValue != 0 {
                        infoData["throw_type_id"] = info.throwType.rawValue
                    }
                    infoData["hit"] = info.hit
                }
            case .withWinGymBattleStatus: break
            case .withSuperEffectiveCharge: break
            case .withUniquePokestop: break
            case .withQuestContext: break
            case .withPlayerLevel: break
            case .withWinBattleStatus: break
            case .withCurveBall: break
            case .withNewFriend: break
            case .withDaysInARow: break
            case .withWeatherBoost: break
            case .withDailyCaptureBonus: break
            case .withDailySpinBonus: break
            default:
                break
            }
            
            if !infoData.isEmpty {
                condition["info"] = infoData
            }
            conditions.append(condition)
        }
        
        for rewardData in questData.questRewards {
            var reward = [String: Any]()
            var infoData = [String: Any]()
            reward["type"] = rewardData.type.rawValue
            
            switch rewardData.type {
                
            case .experience:
                let info = rewardData.exp
                infoData["amount"] = info
            case .item:
                let info = rewardData.item
                infoData["amount"] = info.amount
                infoData["item_id"] = info.item.rawValue
            case .stardust:
                let info = rewardData.stardust
                infoData["amount"] = info
            case .candy:
                let info = rewardData.candy
                infoData["amount"] = info.amount
                infoData["pokemon_id"] = info.pokemonID.rawValue
            case .pokemonEncounter:
                let info = rewardData.pokemonEncounter
                infoData["pokemon_id"] = info.pokemonID.rawValue
                infoData["costume_id"] = info.pokemonDisplay.costume.rawValue
                infoData["form_id"] = info.pokemonDisplay.form.rawValue
                infoData["gender_id"] = info.pokemonDisplay.gender.rawValue
                infoData["shiny"] = info.pokemonDisplay.shiny
                infoData["ditto"] = info.isHiddenDitto
            case .avatarClothing: break
            case .quest: break
            default: break
            }
            
            reward["info"] = infoData
            rewards.append(reward)
        }
        
        self.questConditions = conditions
        self.questRewards = rewards
        self.questTimestamp = UInt32(Date().timeIntervalSince1970)
        self.updated = UInt32(Date().timeIntervalSince1970)
    }
    
    public func save() throws {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let oldPokestop: Pokestop?
        do {
            oldPokestop = try Pokestop.getWithId(id: id)
        } catch {
            oldPokestop = nil
        }
        let mysqlStmt = MySQLStmt(mysql)
        
        if oldPokestop == nil {
            WebHookController.global.addPokestopEvent(pokestop: self)
            if lureExpireTimestamp ?? 0 > 0 {
                WebHookController.global.addLureEvent(pokestop: self)
            }
            if questTimestamp ?? 0 > 0 {
                WebHookController.global.addQuestEvent(pokestop: self)
            }
            let sql = """
                INSERT INTO pokestop (id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp, updated, quest_type, quest_timestamp, quest_target, quest_conditions, quest_rewards, quest_template)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            _ = mysqlStmt.prepare(statement: sql)
            mysqlStmt.bindParam(id)
        } else {
            if oldPokestop!.name != nil && self.name == nil {
                self.name = oldPokestop!.name
            }
            if oldPokestop!.url != nil && self.url == nil {
                self.url = oldPokestop!.url
            }
            if oldPokestop!.questType != nil && self.questType == nil {
                self.questType = oldPokestop!.questType
                self.questTarget = oldPokestop!.questTarget
                self.questConditions = oldPokestop!.questConditions
                self.questRewards = oldPokestop!.questRewards
                self.questTimestamp = oldPokestop!.questTimestamp
                self.questTemplate = oldPokestop!.questTemplate
            }
            
            if oldPokestop!.lureExpireTimestamp ?? 0 < self.lureExpireTimestamp ?? 0 {
                WebHookController.global.addLureEvent(pokestop: self)
            }
            if questTimestamp ?? 0 > oldPokestop!.questTimestamp ?? 0 {
                WebHookController.global.addQuestEvent(pokestop: self)
            }
            
            let sql = """
                UPDATE pokestop
                SET lat = ? , lon = ? , name = ? , url = ? , enabled = ? , lure_expire_timestamp = ? , last_modified_timestamp = ? , updated = ?, quest_type = ?, quest_timestamp = ?, quest_target = ?, quest_conditions = ?, quest_rewards = ?, quest_template = ?
                WHERE id = ?
            """
            _ = mysqlStmt.prepare(statement: sql)
        }
        
        mysqlStmt.bindParam(lat)
        mysqlStmt.bindParam(lon)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(url)
        mysqlStmt.bindParam(enabled)
        mysqlStmt.bindParam(lureExpireTimestamp)
        mysqlStmt.bindParam(lastModifiedTimestamp)
        mysqlStmt.bindParam(updated)
        mysqlStmt.bindParam(questType)
        mysqlStmt.bindParam(questTimestamp)
        mysqlStmt.bindParam(questTarget)
        mysqlStmt.bindParam(questConditions.jsonEncodeForceTry())
        mysqlStmt.bindParam(questRewards.jsonEncodeForceTry())
        mysqlStmt.bindParam(questTemplate)
        
        if oldPokestop != nil {
            mysqlStmt.bindParam(id)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }

    public static func getAll(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, updated: UInt32, questsOnly: Bool, showQuests: Bool) throws -> [Pokestop] {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        var sql = """
            SELECT id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp, updated, quest_type, quest_timestamp, quest_target, CAST(quest_conditions AS CHAR), CAST(quest_rewards AS CHAR), quest_template
            FROM pokestop
            WHERE lat >= ? AND lat <= ? AND lon >= ? AND lon <= ? AND updated > ?
        """
        if questsOnly {
            sql += " AND quest_type IS NOT NULL"
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(minLat)
        mysqlStmt.bindParam(maxLat)
        mysqlStmt.bindParam(minLon)
        mysqlStmt.bindParam(maxLon)
        mysqlStmt.bindParam(updated)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var pokestops = [Pokestop]()
        while let result = results.next() {
            let id = result[0] as! String
            let lat = result[1] as! Double
            let lon = result[2] as! Double
            let name = result[3] as? String
            let url = result[4] as? String
            let enabledInt = result[5] as? UInt8
            let enabled = enabledInt?.toBool()
            let lureExpireTimestamp = result[6] as? UInt32
            let lastModifiedTimestamp = result[7] as? UInt32
            let updated = result[8] as! UInt32
            
            let questType: UInt32?
            let questTimestamp: UInt32?
            let questTarget: UInt16?
            let questConditions: [[String: Any]]?
            let questRewards: [[String: Any]]?
            let questTemplate: String?
            
            if showQuests {
                questType = result[9] as? UInt32
                questTimestamp = result[10] as? UInt32
                questTarget = result[11] as? UInt16
                questConditions = (result[12] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
                questRewards = (result[13] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
                questTemplate = result[14] as? String
            } else {
                questType = nil
                questTimestamp = nil
                questTarget = nil
                questConditions = nil
                questRewards = nil
                questTemplate = nil
            }
            
            pokestops.append(Pokestop(id: id, lat: lat, lon: lon, name: name, url: url, enabled: enabled, lureExpireTimestamp: lureExpireTimestamp, lastModifiedTimestamp: lastModifiedTimestamp, updated: updated, questType: questType, questTarget: questTarget, questTimestamp: questTimestamp, questConditions: questConditions, questRewards: questRewards, questTemplate: questTemplate))
        }
        return pokestops
        
    }
    
    public static func getIn(ids: [String]) throws -> [Pokestop] {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        var inSQL = "("
        for _ in 1..<ids.count {
            inSQL += "?, "
        }
        inSQL += "?)"
        
        
        let sql = """
            SELECT id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp, updated, quest_type, quest_timestamp, quest_target, CAST(quest_conditions AS CHAR), CAST(quest_rewards AS CHAR), quest_template
            FROM pokestop
            WHERE id IN \(inSQL)
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        for id in ids {
            mysqlStmt.bindParam(id)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var pokestops = [Pokestop]()
        while let result = results.next() {
            let id = result[0] as! String
            let lat = result[1] as! Double
            let lon = result[2] as! Double
            let name = result[3] as? String
            let url = result[4] as? String
            let enabledInt = result[5] as? UInt8
            let enabled = enabledInt?.toBool()
            let lureExpireTimestamp = result[6] as? UInt32
            let lastModifiedTimestamp = result[7] as? UInt32
            let updated = result[8] as! UInt32
            let questType = result[9] as? UInt32
            let questTimestamp = result[10] as? UInt32
            let questTarget = result[11] as? UInt16
            let questConditions = (result[12] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
            let questRewards = (result[13] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
            let questTemplate = result[14] as? String
            
            pokestops.append(Pokestop(id: id, lat: lat, lon: lon, name: name, url: url, enabled: enabled, lureExpireTimestamp: lureExpireTimestamp, lastModifiedTimestamp: lastModifiedTimestamp, updated: updated, questType: questType, questTarget: questTarget, questTimestamp: questTimestamp, questConditions: questConditions, questRewards: questRewards, questTemplate: questTemplate))
        }
        return pokestops
        
    }

    public static func getWithId(id: String) throws -> Pokestop? {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT id, lat, lon, name, url, enabled, lure_expire_timestamp, last_modified_timestamp, updated, quest_type, quest_timestamp, quest_target, CAST(quest_conditions AS CHAR), CAST(quest_rewards AS CHAR), quest_template
            FROM pokestop
            WHERE id = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }
        
        let result = results.next()!
        
        let id = result[0] as! String
        let lat = result[1] as! Double
        let lon = result[2] as! Double
        let name = result[3] as? String
        let url = result[4] as? String
        let enabledInt = result[5] as? UInt8
        let enabled = enabledInt?.toBool()
        let lureExpireTimestamp = result[6] as? UInt32
        let lastModifiedTimestamp = result[7] as? UInt32
        let updated = result[8] as! UInt32
        let questType = result[9] as? UInt32
        let questTimestamp = result[10] as? UInt32
        let questTarget = result[11] as? UInt16
        let questConditions = (result[12] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
        let questRewards = (result[13] as? String)?.jsonDecodeForceTry() as? [[String: Any]]
        let questTemplate = result[14] as? String
        
        return Pokestop(id: id, lat: lat, lon: lon, name: name, url: url, enabled: enabled, lureExpireTimestamp: lureExpireTimestamp, lastModifiedTimestamp: lastModifiedTimestamp, updated: updated, questType: questType, questTarget: questTarget, questTimestamp: questTimestamp, questConditions: questConditions, questRewards: questRewards, questTemplate: questTemplate)

    }
    
    public static func clearQuests(ids: [String]) throws {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[POKESTOP] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        var inSQL = "("
        for _ in 1..<ids.count {
            inSQL += "?, "
        }
        inSQL += "?)"
        
        let sql = """
            UPDATE pokestop
            SET updated = ?, quest_type = NULL, quest_timestamp = NULL, quest_target = NULL, quest_conditions = NULL, quest_rewards = NULL, quest_template = NULL
            WHERE id IN \(inSQL)
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(Int(Date().timeIntervalSince1970))
        for id in ids {
            mysqlStmt.bindParam(id)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[POKESTOP] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        
    }
    
    static func == (lhs: Pokestop, rhs: Pokestop) -> Bool {
        return lhs.id == rhs.id
    }
    
}
