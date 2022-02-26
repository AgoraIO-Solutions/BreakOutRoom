//
//  Service.swift
//  Classroom
//
//  Created by XC on 2021/4/21.
//

import Foundation
import RxSwift
import Core

protocol IRoomManager {
    var account: User? { get set }
    var member: ClassroomMember? { get set }
    var setting: LocalSetting { get set }
    func updateSetting()
    
    func getAccount() -> Observable<Result<User>>
    func getRooms() -> Observable<Result<Array<ClassroomRoom>>>
    func create(room: ClassroomRoom) -> Observable<Result<ClassroomRoom>>
    func join(room: ClassroomRoom) -> Observable<Result<ClassroomRoom>>
    func leave() -> Observable<Result<Void>>
    
    func closeMicrophone(close: Bool) -> Observable<Result<Void>>
    func isMicrophoneClose() -> Bool
    
    func enableBeauty(enable: Bool)
    func isEnableBeauty() -> Bool
    
    func subscribeMembers() -> Observable<Result<Array<ClassroomMember>>>
    func subscribeActions() -> Observable<Result<ClassroomAction>>
    
    func inviteSpeaker(member: ClassroomMember) -> Observable<Result<Void>>
    func muteSpeaker(member: ClassroomMember) -> Observable<Result<Void>>
    func unMuteSpeaker(member: ClassroomMember) -> Observable<Result<Void>>
    func kickSpeaker(member: ClassroomMember) -> Observable<Result<Void>>
    
    func process(request: ClassroomAction, agree: Bool) -> Observable<Result<Void>>
    func process(invitionLeft: ClassroomAction, agree: Bool) -> Observable<Result<Void>>
    func process(invitionRight: ClassroomAction, agree: Bool) -> Observable<Result<Void>>
    
    func handsUp(left: Bool?) -> Observable<Result<Void>>
    
    func bindLocalVideo(view: UIView?)
    func bindRemoteVideo(view: UIView?, uid: UInt)
    
    func subscribeMessages() -> Observable<Result<ClassroomMessage>>
    func sendMessage(message: String) -> Observable<Result<Void>>
    
    func destory()
}

protocol ErrorDescription {
    associatedtype Item
    static func toErrorString(type: Item, code: Int32) -> String
}
