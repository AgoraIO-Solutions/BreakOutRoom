//
//  MainModel.swift
//  Scene-Examples
//
//  Created by zhaoyongqiang on 2021/11/10.
//

import UIKit

enum SceneType: String {
    /// Single Live
    case singleLive = "SignleLive"
    /// BreakOutRoom
    case breakoutRoom = "BreakOutRoom"
    /// PKLive
    case pkApply = "PKApplyInfo"
    
    var alertTitle: String {
        switch self {
        case .pkApply: return "PK_Recieved_Invite".localized
        default: return ""
        }
    }
}

struct MainModel {
    var title: String = ""
    var desc: String = ""
    var imageNmae: String = ""
    var sceneType: SceneType = .singleLive
    
    static func mainDatas() -> [MainModel] {
        var dataArray = [MainModel]()
        var model = MainModel()
        model.title = "Single_Broadcaster".localized
        model.desc = "Single_Broadcaster".localized
        model.imageNmae = "pic-single"
        model.sceneType = .singleLive
        dataArray.append(model)

        model = MainModel()
        model.title = "PK_Live".localized
        model.desc = "anchors_of_two_different_live_broadcast_rooms".localized
        model.imageNmae = "pic-PK"
        model.sceneType = .pkApply
        dataArray.append(model)

        model = MainModel()
        model.title = "breakoutroom".localized
        model.desc = "multi_person_meetings_small_conference_rooms".localized
        model.imageNmae = "pic-multiple"
        model.sceneType = .breakoutRoom
        dataArray.append(model)
        
        return dataArray
    }
    
    static func sceneId(type: SceneType) -> String {
        type.rawValue
    }
}
