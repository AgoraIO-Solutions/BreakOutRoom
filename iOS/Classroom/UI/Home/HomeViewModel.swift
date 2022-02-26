//
//  HomeViewModel.swift
//  Classroom
//
//  Created by XC on 2021/4/21.
//

import Foundation
import RxSwift
import RxRelay
import RxCocoa
import IGListKit
import Core

class HomeViewModel {
    let activityIndicator = ActivityIndicator()
    var roomList: [ClassroomRoom] = []
    private var scheduler = SerialDispatchQueueScheduler(internalSerialQueueName: "io")
    
    func setup() -> Observable<Result<Void>> {
        return RoomManager.shared().getAccount().map { $0.transform() }
            // UIRefreshControl bug?
            .delay(DispatchTimeInterval.microseconds(200), scheduler: scheduler)
    }
    
    func account() -> User? {
        return RoomManager.shared().account
    }

    func dataSource() -> Observable<Result<Array<ClassroomRoom>>> {
        return RoomManager.shared().getRooms()
            .map { [unowned self] data in
                if (data.success) {
                    self.roomList.removeAll()
                    self.roomList.append(contentsOf: data.data ?? [])
                }
                return data
            }
            .trackActivity(activityIndicator)
            .subscribe(on: scheduler)
    }
    
    func createRoom(with name: String) -> Observable<Result<ClassroomRoom>> {
        let account = self.account()
        if let anchor = account {
            return RoomManager.shared().create(room: ClassroomRoom(id: "", channelName: name, anchor: anchor))
        } else {
            return Observable.just(Result(success: false, message: "account is nil!"))
        }
    }
    
    func join(room: ClassroomRoom) -> Observable<Result<ClassroomRoom>> {
        return RoomManager.shared().join(room: room)
    }
}

