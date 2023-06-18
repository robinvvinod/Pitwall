//
//  ComparisonScene.swift
//  pitwall-ios
//
//  Created by Robin on 2/6/23.
//

import SceneKit
import SceneKit.ModelIO

class ComparisonScene: SCNScene, SCNSceneRendererDelegate {
    
    private var car1Seq: SCNAction
    private var car2Seq: SCNAction
    private var trackNode: SCNNode
    private var cameraPos: CameraPosition
    private var cameraNode: SCNNode
    private var car1: SCNNode
    private var car2: SCNNode
    
    init(car1Seq: SCNAction, car2Seq: SCNAction, cameraPos: CameraPosition, trackNode: SCNNode) {
        self.car1Seq = car1Seq
        self.car2Seq = car2Seq
        self.cameraPos = cameraPos
        self.trackNode = trackNode
        let cameraNode = SCNNode()
        self.cameraNode = cameraNode
        
        guard let url = Bundle.main.url(forResource: "f1_model", withExtension: "obj", subdirectory: "SceneKitAssets.scnassets") else { fatalError("Failed to find model file.")
        }

        let asset = MDLAsset(url:url)
        guard let carObject = asset.object(at: 0) as? MDLMesh else {
            fatalError("Failed to get mesh from asset.")
        }

        self.car1 = SCNNode(mdlObject: carObject)
        self.car2 = SCNNode(mdlObject: carObject)
//        self.car1 = SCNNode(geometry: SCNSphere(radius: 0.5))
//        self.car2 = SCNNode(geometry: SCNSphere(radius: 0.5))
        
        super.init()

        self.background.contents = MDLSkyCubeTexture(name: "sky",
                                          channelEncoding: .float16,
                                        textureDimensions: vector_int2(128, 128),
                                                turbidity: 0,
                                             sunElevation: 1.5,
                                upperAtmosphereScattering: 0.5,
                                             groundAlbedo: 0.5)
        self.lightingEnvironment.contents = self.background.contents
        
        self.rootNode.addChildNode(self.trackNode)
                
        self.car1.scale = SCNVector3(x: 0.75, y: 0.75, z: 0.75)
//        self.car1.position = self.car1Pos.positions[0].coords
        self.rootNode.addChildNode(self.car1)
        
        self.car2.scale = SCNVector3(x: 0.75, y: 0.75, z: 0.75)
//        self.car2.position = self.car2Pos.positions[0].coords
        self.rootNode.addChildNode(self.car2)
        
        self.cameraNode.camera = SCNCamera()
        self.cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
        self.cameraNode.camera?.zFar = 500
        let lookAt = SCNLookAtConstraint(target: car1)
        lookAt.isGimbalLockEnabled = true
        self.cameraNode.constraints = [lookAt]
        self.car1.addChildNode(self.cameraNode) // Camera is added as a child node of car1, and will be positioned relative to car 1 always
        
        self.car1.runAction(car1Seq)
        self.car2.runAction(car2Seq)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Update camera position every frame
        self.cameraNode.position = self.cameraPos.coords
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

