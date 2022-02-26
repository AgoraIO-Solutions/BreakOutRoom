//
//  ClassroomModelManagerProxy.swift
//  Core
//
//  Created by XC on 2021/6/1.
//
#if LEANCLOUD
import Foundation
import Core
import LeanCloud
import RxSwift
import Classroom

class LeanCloudClassroomModelManager: IClassroomModelManager {
    
    static func queryMemberCount(room: LCObject) throws -> Int {
        let query = LCQuery(className: ClassroomMember.TABLE)
        try query.where(ClassroomMember.ROOM, .equalTo(room))
        return query.count().intValue
    }
    
    static func querySpeakerCount(room: LCObject) throws -> Int {
        let query = LCQuery(className: ClassroomMember.TABLE)
        try query.where(ClassroomMember.ROOM, .equalTo(room))
        try query.where(ClassroomMember.ROLE, .notEqualTo(ClassroomRoomRole.listener.rawValue))
        return query.count().intValue
    }
    
    static func from(object: LCObject) throws -> ClassroomRoom {
        let objectId: String = object.objectId!.stringValue!
        let channelName: String = object.get(ClassroomRoom.CHANNEL_NAME)!.stringValue!
        let anchor: User = try LeanCloudUserManager.from(object: object.get(ClassroomRoom.ANCHOR_ID) as! LCObject)
        let room = ClassroomRoom(id: objectId, channelName: channelName, anchor: anchor)
        room.total = try queryMemberCount(room: object)
        room.speakersTotal = try querySpeakerCount(room: object)
        if (room.coverCharacters.count == 0) {
            room.coverCharacters.append(room.anchor)
        }
        return room
    }
    
    static func from(object: LCObject, room: ClassroomRoom) throws -> ClassroomMember {
        let userObject = object.get(ClassroomMember.USER) as! LCObject
        let user = try LeanCloudUserManager.from(object: userObject)
        let isMuted = (object.get(ClassroomMember.MUTED)?.intValue ?? 0) == 1
        let _role = object.get(ClassroomMember.ROLE)?.intValue ?? 0
        let role: ClassroomRoomRole
        switch _role {
        case ClassroomRoomRole.listener.rawValue:
            role = .listener
        case ClassroomRoomRole.manager.rawValue:
            role = .manager
        case ClassroomRoomRole.leftSpeaker.rawValue:
            role = .leftSpeaker
        case ClassroomRoomRole.rightSpeaker.rawValue:
            role = .rightSpeaker
        default:
            role = .listener
        }
        let isSelfMuted = (object.get(ClassroomMember.SELF_MUTED)?.intValue ?? 0) == 1
        let streamId = object.get(ClassroomMember.STREAM_ID)?.uintValue ?? 0
        let id = object.objectId!.stringValue!
        return ClassroomMember(id: id, isMuted: isMuted, isSelfMuted: isSelfMuted, role: role, room: room, streamId: streamId, user: user)
    }
    
    static func toObject(member: ClassroomMember) throws -> LCObject {
        let object = LCObject(className: ClassroomMember.TABLE)
        try object.set(ClassroomMember.ROOM, value: LCObject(className: ClassroomRoom.TABLE, objectId: member.room.id))
        try object.set(ClassroomMember.USER, value: LCObject(className: User.TABLE, objectId: member.user.id))
        try object.set(ClassroomMember.STREAM_ID, value: member.streamId)
        try object.set(ClassroomMember.ROLE, value: member.role.rawValue)
        try object.set(ClassroomMember.MUTED, value: member.isMuted ? 1 : 0)
        try object.set(ClassroomMember.SELF_MUTED, value: member.isSelfMuted ? 1 : 0)
        return object
    }

    static func toActionObject(action: ClassroomAction) throws -> LCObject {
        let object = LCObject(className: ClassroomAction.TABLE)
        try object.set(ClassroomAction.ROOM, value: LCObject(className: ClassroomRoom.TABLE, objectId: action.room.id))
        try object.set(ClassroomAction.MEMBER, value: LCObject(className: ClassroomMember.TABLE, objectId: action.member.id))
        try object.set(ClassroomAction.ACTION, value: action.action.rawValue)
        try object.set(ClassroomAction.STATUS, value: action.status.rawValue)
        return object
    }
    
    static func from(object: LCObject) throws -> ClassroomAction {
        let id = object.objectId!.stringValue!
        let room: ClassroomRoom = try from(object: object.get(ClassroomAction.ROOM) as! LCObject)
        let member: ClassroomMember = try from(object: object.get(ClassroomAction.MEMBER) as! LCObject, room: room)
        let action: Int = object.get(ClassroomAction.ACTION)!.intValue!
        let status: Int = object.get(ClassroomAction.STATUS)!.intValue!
        
        return ClassroomAction(id: id, action: ClassroomActionType.from(value: action), status: ClassroomActionStatus.from(value: status), member: member, room: room)
    }
    
    static func getClassroomAction(objectId: String) -> Observable<Result<ClassroomAction>> {
        return Database.query(className: ClassroomAction.TABLE, objectId: objectId) { (query) in
            try query.where(ClassroomAction.ROOM, .included)
            try query.where("\(ClassroomAction.ROOM).\(ClassroomRoom.ANCHOR_ID)", .included)
            try query.where(ClassroomAction.MEMBER, .included)
            try query.where("\(ClassroomAction.MEMBER).\(ClassroomMember.USER)", .included)
        } transform: { (object: LCObject) -> ClassroomAction in
            return try from(object: object)
        }
    }
    
    func create(room: ClassroomRoom) -> Observable<Result<String>> {
        return Database.save {
            let object = LCObject(className: ClassroomRoom.TABLE)
            let anchor = LCObject(className: User.TABLE, objectId: room.anchor.id)
            try object.set(ClassroomRoom.CHANNEL_NAME, value: room.channelName)
            try object.set(ClassroomRoom.ANCHOR_ID, value: anchor)
            return object
        }
    }
    
    func delete(room: ClassroomRoom) -> Observable<Result<Void>> {
        return Database.delete(className: ClassroomRoom.TABLE, objectId: room.id)
    }
    
    func getRooms() -> Observable<Result<Array<ClassroomRoom>>> {
        return Database.query(className: ClassroomRoom.TABLE) { (query) in
            try query.where(ClassroomRoom.CHANNEL_NAME, .selected)
            try query.where(ClassroomRoom.ANCHOR_ID, .selected)
            try query.where(ClassroomRoom.ANCHOR_ID, .included)
            try query.where("createdAt", .descending)
        } transform: { (list) -> Array<ClassroomRoom> in
            let rooms: Array<ClassroomRoom> = try list.map { room in
                return try LeanCloudClassroomModelManager.from(object: room)
            }
            return rooms
        }
    }
    
    func getRoom(by objectId: String) -> Observable<Result<ClassroomRoom>> {
        return Database.query(className: ClassroomRoom.TABLE, objectId: objectId) { query in
            try query.where(ClassroomRoom.ANCHOR_ID, .included)
        } transform: { (data: LCObject) -> ClassroomRoom in
            let channelName: String = data.get(ClassroomRoom.CHANNEL_NAME)!.stringValue!
            let anchor = try LeanCloudUserManager.from(object: data.get(ClassroomRoom.ANCHOR_ID) as! LCObject)
            return ClassroomRoom(id: objectId, channelName: channelName, anchor: anchor)
        }
    }
    
    func update(room: ClassroomRoom) -> Observable<Result<String>> {
        return Database.save {
            let object = LCObject(className: ClassroomRoom.TABLE, objectId: room.id)
            try object.set(ClassroomRoom.CHANNEL_NAME, value: room.channelName)
            try object.set(ClassroomRoom.ANCHOR_ID, value: LCObject(className: User.TABLE, objectId: room.anchor.id))
            return object
        }
    }
    
    func getMembers(room: ClassroomRoom) -> Observable<Result<Array<ClassroomMember>>> {
        return Database.query(className: ClassroomMember.TABLE) { (query) in
            let room = LCObject(className: ClassroomRoom.TABLE, objectId: room.id)
            try query.where(ClassroomMember.ROOM, .equalTo(room))
            try query.where(ClassroomMember.USER, .included)
            try query.where("createdAt", .ascending)
        } transform: { (list) -> Array<ClassroomMember> in
            let members: Array<ClassroomMember> = try list.map { data in
                let member: ClassroomMember = try LeanCloudClassroomModelManager.from(object: data, room: room)
                member.isManager = member.user.id == room.anchor.id
                return member
            }
            return members
        }
    }
    
    func getCoverSpeakers(room: ClassroomRoom) -> Observable<Result<Array<ClassroomMember>>> {
        return Database.query(className: ClassroomMember.TABLE) { (query) in
            let room = LCObject(className: ClassroomRoom.TABLE, objectId: room.id)
            try query.where(ClassroomMember.ROOM, .equalTo(room))
            try query.where(ClassroomMember.ROLE, .notEqualTo(ClassroomRoomRole.listener.rawValue))
            query.limit = 3
            try query.where(ClassroomMember.USER, .included)
        } transform: { (list) -> Array<ClassroomMember> in
            let members: Array<ClassroomMember> = try list.map { data in
                let member = try LeanCloudClassroomModelManager.from(object: data, room: room)
                member.isManager = member.user.id == room.anchor.id
                return member
            }
            return members
        }
    }
    
    func subscribeMembers(room: ClassroomRoom) -> Observable<Result<Array<ClassroomMember>>> {
        return Database.subscribe(className: ClassroomMember.TABLE) { query in
            let room = LCObject(className: ClassroomRoom.TABLE, objectId: room.id)
            try query.where(ClassroomMember.ROOM, .equalTo(room))
        } onEvent: { (event) -> Bool in
            return true
        }
        .startWith(Result(success: true))
        .flatMap { [unowned self] result -> Observable<Result<Array<ClassroomMember>>> in
            return result.onSuccess { self.getMembers(room: room) }
        }
    }
    
    func join(member: ClassroomMember, streamId: UInt) -> Observable<Result<Void>> {
        member.streamId = streamId
        return Database.delete(className: ClassroomMember.TABLE) { query in
            let user = LCObject(className: User.TABLE, objectId: member.user.id)
            try query.where(ClassroomMember.USER, .equalTo(user))
        }
        .concatMap { result -> Observable<Result<Void>> in
            if (result.success) {
                return Database.save {
                    return try LeanCloudClassroomModelManager.toObject(member: member)
                }.map { result in
                    if (result.success) {
                        member.id = result.data!
                    }
                    return Result(success: result.success, message: result.message)
                }
            } else {
                return Observable.just(Result(success: false, message: result.message))
            }
        }
    }
    
    func mute(member: ClassroomMember, mute: Bool) -> Observable<Result<Void>> {
        return Database.save {
            Logger.log(message: "save mute \(mute)", level: .info)
            let object = LCObject(className: ClassroomMember.TABLE, objectId: member.id)
            try object.set(ClassroomMember.MUTED, value: mute ? 1 : 0)
            return object
        }
        .map { $0.transform() }
    }

    func selfMute(member: ClassroomMember, mute: Bool) -> Observable<Result<Void>> {
        return Database.save {
            Logger.log(message: "save selfMute \(mute)", level: .info)
            let object = LCObject(className: ClassroomMember.TABLE, objectId: member.id)
            try object.set(ClassroomMember.SELF_MUTED, value: mute ? 1 : 0)
            return object
        }
        .map { $0.transform() }
    }
    
    func asListener(member: ClassroomMember) -> Observable<Result<Void>> {
        return Database.save {
            Logger.log(message: "save asListener", level: .info)
            let object = LCObject(className: ClassroomMember.TABLE, objectId: member.id)
            try object.set(ClassroomMember.ROLE, value: ClassroomRoomRole.listener.rawValue)
            return object
        }
        .map { $0.transform() }
    }
    
    func asLeftSpeaker(member: ClassroomMember, agree: Bool) -> Observable<Result<Void>> {
        return Database.save {
            Logger.log(message: "save asSpeaker \(agree)", level: .info)
            let object = LCObject(className: ClassroomMember.TABLE, objectId: member.id)
            try object.set(ClassroomMember.ROLE, value: agree ? ClassroomRoomRole.leftSpeaker.rawValue : ClassroomRoomRole.listener.rawValue)
            if (agree) {
                try object.set(ClassroomMember.MUTED, value: 0)
                try object.set(ClassroomMember.SELF_MUTED, value: 0)
            }
            return object
        }
        .map { $0.transform() }
    }
    
    func asRightSpeaker(member: ClassroomMember, agree: Bool) -> Observable<Result<Void>> {
        return Database.save {
            Logger.log(message: "save asRightSpeaker \(agree)", level: .info)
            let object = LCObject(className: ClassroomMember.TABLE, objectId: member.id)
            try object.set(ClassroomMember.ROLE, value: agree ? ClassroomRoomRole.rightSpeaker.rawValue : ClassroomRoomRole.listener.rawValue)
            if (agree) {
                try object.set(ClassroomMember.MUTED, value: 0)
                try object.set(ClassroomMember.SELF_MUTED, value: 0)
            }
            return object
        }
        .map { $0.transform() }
    }
    
    func leave(member: ClassroomMember) -> Observable<Result<Void>> {
        Logger.log(message: "Member leave isManager:\(member.isManager)", level: .info)
        if (member.isManager) {
            return Observable.zip(
                self.delete(room: member.room),
                Database.delete(className: ClassroomMember.TABLE) { query in
                    let room = LCObject(className: ClassroomRoom.TABLE, objectId: member.room.id)
                    try query.where(ClassroomMember.ROOM, .equalTo(room))
                },
                Database.delete(className: ClassroomAction.TABLE) { query in
                    let room = LCObject(className: ClassroomRoom.TABLE, objectId: member.room.id)
                    try query.where(ClassroomAction.ROOM, .equalTo(room))
                }
            ).map { (args) in
                let (result0, result1, result2) = args
                if (result0.success && result1.success && result2.success) {
                    return result0
                } else {
                    return result0.success ? result1.success ? result2 : result1 : result0
                }
            }
        } else {
            return Database.delete(className: ClassroomMember.TABLE) { query in
                let user = LCObject(className: User.TABLE, objectId: member.user.id)
                try query.where(ClassroomMember.USER, .equalTo(user))
            }
        }
    }
    
    func subscribeActions(member: ClassroomMember) -> Observable<Result<ClassroomAction>> {
        return Database.subscribe(className: ClassroomAction.TABLE) { query in
            let room = LCObject(className: ClassroomRoom.TABLE, objectId: member.room.id)
            try query.where(ClassroomAction.ROOM, .equalTo(room))
//            try query.where(Action.ROOM, .included)
//            try query.where(Action.MEMBER, .included)
            if (!member.isManager) {
                let member = LCObject(className: ClassroomMember.TABLE, objectId: member.id)
                try query.where(ClassroomAction.MEMBER, .equalTo(member))
            }
        } onEvent: { (event) -> String? in
            switch event {
            case .create(object: let object):
//                Logger.log(message: object.jsonString, level: .info)
                return object.objectId!.stringValue!
            default:
                return nil
            }
        }
        .filter { result in
            return result.data != nil
        }
        .concatMap { result in
            return LeanCloudClassroomModelManager.getClassroomAction(objectId: result.data!)
        }
    }
    
    func handsup(member: ClassroomMember) -> Observable<Result<Void>> {
        let action = member.action(with: .handsUp)
        return Database.save {
            return try LeanCloudClassroomModelManager.toActionObject(action: action)
        }
        .map { $0.transform() }
    }
    
    func requestLeft(member: ClassroomMember) -> Observable<Result<Void>> {
        let action = member.action(with: .requestLeft)
        return Database.save {
            return try LeanCloudClassroomModelManager.toActionObject(action: action)
        }
        .map { $0.transform() }
    }
    
    func requestRight(member: ClassroomMember) -> Observable<Result<Void>> {
        let action = member.action(with: .requestRight)
        return Database.save {
            return try LeanCloudClassroomModelManager.toActionObject(action: action)
        }
        .map { $0.transform() }
    }
    
    func inviteSpeaker(master: ClassroomMember, member: ClassroomMember) -> Observable<Result<Void>> {
        let action = master.action(with: .invite)
        action.member = member
        return Database.save {
            return try LeanCloudClassroomModelManager.toActionObject(action: action)
        }
        .map { $0.transform() }
    }
    
    func rejectInvition(member: ClassroomMember) -> Observable<Result<Void>> {
        let action = member.action(with: .invite)
        action.status = .refuse
        return Database.save {
            return try LeanCloudClassroomModelManager.toActionObject(action: action)
        }
        .map { $0.transform() }
    }
}

#endif
