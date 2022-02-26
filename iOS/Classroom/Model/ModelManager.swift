//
//  ModelManager.swift
//  Classroom
//
//  Created by XC on 2021/6/4.
//

import Foundation
import RxSwift
import Core

extension ClassroomRoom {
    public static let TABLE: String = "ROOM_MARRY"
    public static let ANCHOR_ID: String = "anchorId"
    public static let CHANNEL_NAME: String = "channelName"
}

extension ClassroomMember {
    public static let TABLE: String = "MEMBER_MARRY"
    public static let MUTED: String = "isMuted"
    public static let SELF_MUTED: String = "isSelfMuted"
    public static let ROLE: String = "role"
    public static let ROOM: String = "roomId"
    public static let STREAM_ID = "streamId"
    public static let USER = "userId"
}

extension ClassroomAction {
    public static let TABLE: String = "ACTION_MARRY"
    public static let ACTION: String = "action"
    public static let MEMBER: String = "memberId"
    public static let ROOM: String = "roomId"
    public static let STATUS: String = "status"
}

public protocol IClassroomModelManager {
    func create(room: ClassroomRoom) -> Observable<Result<String>>
    func delete(room: ClassroomRoom) -> Observable<Result<Void>>
    func getRooms() -> Observable<Result<Array<ClassroomRoom>>>
    func getRoom(by objectId: String) -> Observable<Result<ClassroomRoom>>
    func update(room: ClassroomRoom) -> Observable<Result<String>>
    func getMembers(room: ClassroomRoom) -> Observable<Result<Array<ClassroomMember>>>
    func getCoverSpeakers(room: ClassroomRoom) -> Observable<Result<Array<ClassroomMember>>>
    func subscribeMembers(room: ClassroomRoom) -> Observable<Result<Array<ClassroomMember>>>
    
    func join(member: ClassroomMember, streamId: UInt) -> Observable<Result<Void>>
    func mute(member: ClassroomMember, mute: Bool) -> Observable<Result<Void>>
    func selfMute(member: ClassroomMember, mute: Bool) -> Observable<Result<Void>>
    func asListener(member: ClassroomMember) -> Observable<Result<Void>>
    func asLeftSpeaker(member: ClassroomMember, agree: Bool) -> Observable<Result<Void>>
    func asRightSpeaker(member: ClassroomMember, agree: Bool) -> Observable<Result<Void>>
    func leave(member: ClassroomMember) -> Observable<Result<Void>>
    func subscribeActions(member: ClassroomMember) -> Observable<Result<ClassroomAction>>
    func handsup(member: ClassroomMember) -> Observable<Result<Void>>
    func requestLeft(member: ClassroomMember) -> Observable<Result<Void>>
    func requestRight(member: ClassroomMember) -> Observable<Result<Void>>
    func inviteSpeaker(master: ClassroomMember, member: ClassroomMember) -> Observable<Result<Void>>
    func rejectInvition(member: ClassroomMember) -> Observable<Result<Void>>
}
