//
//  CameraController.swift
//  iOSCamera
//
//  Created by 임성현 on 2020/08/10.
//  Copyright © 2020 임성현. All rights reserved.
//

import AVFoundation
import UIKit

class CameraController {
    // AVCaptureSession 생성
    var captureSession: AVCaptureSession?
    
    // iOS장치 카메라를 나타내는 변수
    var frontCamera: AVCaptureDevice?
    var rearCamera: AVCaptureDevice?
    
    // capture device input을 생성하여 capture device를 capture session에 연결
    var currentCameraPosition: CameraPosition?
    var frontCameraInput: AVCaptureDeviceInput?
    var rearCameraInput: AVCaptureDeviceInput?
    
    // photo output 구성
    var photoOutput: AVCapturePhotoOutput?
    
    
    // 출력을 표시하는 미리보기 레이어
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    
    // 플래시 기능
    var flashMode = AVCaptureDevice.FlashMode.off
    
    public enum CameraPosition {
        case front
        case rear
    }
    
    // captureSession을 생성하는 동안 발생할 수 있는 다양한 오류들.
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    // captureSession을 구성하고 시작하는 함수. 완료되면 완료 핸들러를 호출
    // 1. captureSession 생성
    // 2. 필요한 capture device를 얻고 구성
    // 3. capture device를 사용하여 input 생성
    // 4. 캡처 된 이미지를 처리하도록 photo output 구성
    func prepare(completionHandler: @escaping (Error?) -> Void) {
        // 1. captureSession 생성
        func createCaptureSession() {
            self.captureSession = AVCaptureSession()
        }
        // 2. 필요한 capture device를 얻고 구성
        func configureCaptureDevices() throws {
            // 장치에서 사용할 수 있는 카메라 찾기.
            // AVCaptureDeviceDiscoverySession을 사용하여 현재 장치에서 사용할 수 있는 모든 카메라를 찾아 비옵션 AVCaptureDevice의 배열로 변환.
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
            
            guard session.devices.count > 1 else {
                return
            }
            
            // 앞의 코드에서 카메라를 살펴보고, 전면 or 후면 을 결정. 후방에는 auto focus로 추가 구성.
            for camera in session.devices.compactMap({ $0 }) {
                if camera.position == .front {
                    self.frontCamera = camera
                }
                
                if camera.position == .back {
                    self.rearCamera = camera
                    
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
        }
        // 3. capture device를 사용하여 input 생성
        func configureDeviceInputs() throws {
            // captureSession 이 있는지 확인.
            guard let captureSession = self.captureSession else {
                throw CameraControllerError.captureSessionIsMissing
            }
            
            // device input. 후면 카메라가 기본값이다.
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if captureSession.canAddInput(self.rearCameraInput!) {
                    captureSession.addInput(self.rearCameraInput!)
                }
                
                self.currentCameraPosition = .rear
            } else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                
                if captureSession.canAddInput(self.frontCameraInput!) {
                    captureSession.addInput(self.frontCameraInput!)
                } else {
                    throw CameraControllerError.inputsAreInvalid
                }
                
                self.currentCameraPosition = .front
            } else {
                throw CameraControllerError.noCamerasAvailable
            }
        }
        // 4. 캡처된 이미지를 처리하도록 photo output 생성
        func configurePhotoOutput() throws {
            guard let captureSession = self.captureSession else {
                throw CameraControllerError.captureSessionIsMissing
            }
            
            self.photoOutput = AVCapturePhotoOutput()
            self.photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])], completionHandler: nil)
            
            if captureSession.canAddOutput(self.photoOutput!) {
                captureSession.addOutput(self.photoOutput!)
            }
            
            captureSession.startRunning()
        }
        
        // 4개의 함수를 호출하고 오류를 잡은 후 완료 핸들러 호출하는 비동기 블록
        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
            } catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                
                return
            }
            
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }
    
    // 위 코드에서 Camera Device가 준비되었으므로 화면에 capture한 내용을 표시한다.
    // 캡처 미리보기를 만들어 제공된 보기에 표시하는 역할.
    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else {
            throw CameraControllerError.captureSessionIsMissing
        }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        // Orientation - portrait(세로 방향)
        self.previewLayer?.connection?.videoOrientation = .portrait
        
        view.layer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer?.frame = view.frame
    }
    
    // 카메라 전환 함수
    // 기존 카메라에 대한 capture input을 제거하고 전환하려는 카메라에 새로운 capture input을 추가
    func switchCameras() throws {
        // 유효하고 실행중인 captureSession이 있는지 확인, 활성화된 카메라 확인
        guard let currentCameraPosition = currentCameraPosition, let captureSesseion = self.captureSession, captureSesseion.isRunning else {
            throw CameraControllerError.captureSessionIsMissing
        }
        
        // captureSession 설정 시작
        captureSesseion.beginConfiguration()
        
        func switchToFrontCamera() throws {
            // captureSession의 모든 input 배열을 가져와 요청 카메라로 전환할 수 있는 지 확인
            guard let inputs = captureSesseion.inputs as? [AVCaptureInput], let rearCameraInput = self.rearCameraInput, inputs.contains(rearCameraInput), let frontCamera = self.frontCamera else {
                throw CameraControllerError.invalidOperation
            }
            
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            captureSesseion.removeInput(rearCameraInput)
            
            if captureSesseion.canAddInput(self.frontCameraInput!) {
                captureSesseion.addInput(self.frontCameraInput!)
                
                self.currentCameraPosition = .front
            } else {
                throw CameraControllerError.invalidOperation
            }
        }
        
        func switchToRearCamera() throws {
            guard let inputs = captureSesseion.inputs as? [AVCaptureInput], let frontCameraInput = self.frontCameraInput, inputs.contains(frontCameraInput), let rearCamera = self.rearCamera else {
                throw CameraControllerError.invalidOperation
            }
            
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            
            captureSesseion.removeInput(frontCameraInput)
            
            if captureSesseion.canAddInput(self.rearCameraInput!) {
                captureSesseion.addInput(self.rearCameraInput!)
                
                self.currentCameraPosition = .rear
            } else {
                throw CameraControllerError.invalidOperation
            }
        }
        
        switch currentCameraPosition {
        case .front:
            try switchToRearCamera()
        case .rear:
            try switchToFrontCamera()
        }
        
        // 설정 후 captureSession 저장
        captureSesseion.commitConfiguration()
    }
}
