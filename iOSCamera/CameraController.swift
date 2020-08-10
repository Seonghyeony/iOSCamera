//
//  CameraController.swift
//  iOSCamera
//
//  Created by 임성현 on 2020/08/10.
//  Copyright © 2020 임성현. All rights reserved.
//

import AVFoundation

class CameraController {
    // captureSession을 구성하고 시작하는 함수. 완료되면 완료 핸들러를 호출
    // 1. captureSession 생성
    // 2. 필요한 capture device를 얻고 구성
    // 3. capture device를 사용하여 input 생성
    // 4. 캡처 된 이미지를 처리하도록 photo output 구성
    func prepare(completionHandler: @escaping (Error?) -> Void) {
        func createCaptureSession() {
            
        }
        func configureCaptureDevices() throws {
            
        }
        func configureDeviceInput() throws {
            
        }
        func configurePhotoOutput() throws {
            
        }
    }
}
