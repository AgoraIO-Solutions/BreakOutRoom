//
//  Model.swift
//  Classroom
//
//  Created by XC on 2021/4/21.
//

import Foundation
import RxSwift
import Core

public class ClassroomRoom: Equatable {
    public static func == (lhs: ClassroomRoom, rhs: ClassroomRoom) -> Bool {
        return lhs.id == rhs.id
    }
    
    public var id: String
    public let channelName: String
    public var anchor: User
    public var total: Int = 0
    public var speakersTotal: Int = 0
    public var coverCharacters: [User] = []
    
    public init(id: String, channelName: String, anchor: User) {
        self.id = id
        self.channelName = channelName
        self.anchor = anchor
    }
}

public enum ClassroomRoomRole: Int {
    case listener = 0
    case manager = 1
    case leftSpeaker = 2
    case rightSpeaker = 3
}

public class ClassroomMember {
    public var id: String
    public var isMuted: Bool
    public var isSelfMuted: Bool
    public var role: ClassroomRoomRole = .listener
    //var isSpeaker: Bool = false
    public var room: ClassroomRoom
    public var streamId: UInt
    public var user: User
    
    public var isManager: Bool = false
    public var isLocal: Bool = false
    
    public init(id: String, isMuted: Bool, isSelfMuted: Bool, role: ClassroomRoomRole, room: ClassroomRoom, streamId: UInt, user: User) {
        self.id = id
        self.isMuted = isMuted
        self.isSelfMuted = isSelfMuted
        self.role = role
        self.room = room
        self.streamId = streamId
        self.user = user
        self.isManager = room.anchor.id == id
    }
    
    public func isSpeaker() -> Bool {
        return isManager || role != .listener
    }
    
    public func action(with action: ClassroomActionType) -> ClassroomAction {
        return ClassroomAction(id: "", action: action, status: .ing, member: self, room: self.room)
    }
}

public enum ClassroomActionType: Int {
    case handsUp = 1
    case invite = 2
    case requestLeft = 3
    case requestRight = 4
    case error
    
    public static func from(value: Int) -> ClassroomActionType {
        switch value {
        case 1:
            return .handsUp
        case 2:
            return .invite
        case 3:
            return .requestLeft
        case 4:
            return .requestRight
        default:
            return .error
        }
    }
}

public enum ClassroomActionStatus: Int {
    case ing = 1
    case agree = 2
    case refuse = 3
    case error
    
    public static func from(value: Int) -> ClassroomActionStatus {
        switch value {
        case 1:
            return .ing
        case 2:
            return .agree
        case 3:
            return .refuse
        default:
            return .error
        }
    }
}

public class ClassroomAction {
    public var id: String
    public var action: ClassroomActionType
    public var status: ClassroomActionStatus
    
    public var member: ClassroomMember
    public var room: ClassroomRoom
    
    public init(id: String, action: ClassroomActionType, status: ClassroomActionStatus, member: ClassroomMember, room: ClassroomRoom) {
        self.id = id
        self.action = action
        self.status = status
        self.member = member
        self.room = room
    }
}

public class ClassroomMessage {
    public var channelId: String
    public var userId: String
    public var value: String
    
    public init(channelId: String, userId: String, value: String) {
        self.channelId = channelId
        self.userId = userId
        self.value = value
    }
}


extension ClassroomRoom {
    private static var manager: IClassroomModelManager {
        InjectionService.shared.resolve(IClassroomModelManager.self)
    }
    
    static func create(room: ClassroomRoom) -> Observable<Result<String>> {
        return ClassroomRoom.manager.create(room: room)
    }
    
    func delete() -> Observable<Result<Void>> {
        return ClassroomRoom.manager.delete(room: self)
    }
    
    static func getRooms() -> Observable<Result<Array<ClassroomRoom>>> {
        return ClassroomRoom.manager.getRooms()
    }
    
    static func getRoom(by objectId: String) -> Observable<Result<ClassroomRoom>> {
        return ClassroomRoom.manager.getRoom(by: objectId)
    }
    
    static func update(room: ClassroomRoom) -> Observable<Result<String>> {
        return ClassroomRoom.manager.update(room: room)
    }
    
    func getMembers() -> Observable<Result<Array<ClassroomMember>>> {
        return ClassroomRoom.manager.getMembers(room: self)
    }
    
    func getCoverSpeakers() -> Observable<Result<Array<ClassroomMember>>> {
        return ClassroomRoom.manager.getCoverSpeakers(room: self)
    }
    
    func subscribeMembers() -> Observable<Result<Array<ClassroomMember>>> {
        return ClassroomRoom.manager.subscribeMembers(room: self)
    }
}

extension ClassroomMember {
    private static var manager: IClassroomModelManager {
        InjectionService.shared.resolve(IClassroomModelManager.self)
    }
    
    func join(streamId: UInt) -> Observable<Result<Void>>{
        return ClassroomMember.manager.join(member: self, streamId: streamId)
    }
    
    func mute(mute: Bool) -> Observable<Result<Void>> {
        return ClassroomMember.manager.mute(member: self, mute: mute)
    }
    
    func selfMute(mute: Bool) -> Observable<Result<Void>> {
        return ClassroomMember.manager.selfMute(member: self, mute: mute)
    }
    
    func asListener() -> Observable<Result<Void>> {
        return ClassroomMember.manager.asListener(member: self)
    }
    
    func asLeftSpeaker(agree: Bool) -> Observable<Result<Void>> {
        return ClassroomMember.manager.asLeftSpeaker(member: self, agree: agree)
    }
    
    func asRightSpeaker(agree: Bool) -> Observable<Result<Void>> {
        return ClassroomMember.manager.asRightSpeaker(member: self, agree: agree)
    }
    
    func leave() -> Observable<Result<Void>> {
        return ClassroomMember.manager.leave(member: self)
    }
    
    func subscribeActions() -> Observable<Result<ClassroomAction>> {
        return ClassroomMember.manager.subscribeActions(member: self)
    }
    
    func handsup() -> Observable<Result<Void>> {
        return ClassroomMember.manager.handsup(member: self)
    }
    
    func requestLeft() -> Observable<Result<Void>> {
        return ClassroomMember.manager.requestLeft(member: self)
    }
    
    func requestRight() -> Observable<Result<Void>> {
        return ClassroomMember.manager.requestRight(member: self)
    }
    
    func inviteSpeaker(member: ClassroomMember) -> Observable<Result<Void>> {
        return ClassroomMember.manager.inviteSpeaker(master: self, member: member)
    }
    
    func rejectInvition() -> Observable<Result<Void>> {
        return ClassroomMember.manager.rejectInvition(member: self)
    }
}

extension ClassroomAction {
    func setLeftSpeaker(agree: Bool) -> Observable<Result<Void>> {
        return member.asLeftSpeaker(agree: agree)
    }
    
    func setRightSpeaker(agree: Bool) -> Observable<Result<Void>> {
        return member.asRightSpeaker(agree: agree)
    }
    
    func setLeftInvition(agree: Bool) -> Observable<Result<Void>> {
        if (agree) {
            return member.asLeftSpeaker(agree: agree)
        } else {
            return member.rejectInvition()
        }
    }
    
    func setRightInvition(agree: Bool) -> Observable<Result<Void>> {
        if (agree) {
            return member.asRightSpeaker(agree: agree)
        } else {
            return member.rejectInvition()
        }
    }
}
