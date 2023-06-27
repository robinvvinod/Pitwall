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
        self.cameraNode = SCNNode()
        self.car1 = SCNNode()
        self.car2 = SCNNode()

        super.init()
        
        self.car1 = loadModel(color: UIColor.orange)
        self.car2 = loadModel(color: UIColor.white)

        background.contents = MDLSkyCubeTexture(name: "sky",
                                          channelEncoding: .float16,
                                        textureDimensions: vector_int2(128, 128),
                                                turbidity: 0,
                                             sunElevation: 1.5,
                                upperAtmosphereScattering: 0.5,
                                             groundAlbedo: 0.5)
        lightingEnvironment.contents = background.contents
        
        rootNode.addChildNode(self.trackNode)
        rootNode.addChildNode(self.car1)
        rootNode.addChildNode(self.car2)
        
        self.cameraNode.camera = SCNCamera()
        self.cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
        self.cameraNode.camera?.zFar = 1000
        let lookAt = SCNLookAtConstraint(target: car1)
        lookAt.isGimbalLockEnabled = true
        self.cameraNode.constraints = [lookAt]
        self.car1.addChildNode(self.cameraNode) // Camera is added as a child node of car1, and will be positioned relative to car 1 always
        
        self.car1.runAction(car1Seq)
        self.car2.runAction(car2Seq)
    }
    
    private func loadModel(color: UIColor) -> SCNNode {
        /*
         "F1 2022 {FREE!!}" (https://skfb.ly/oFxwG) by 3dblenderlol is licensed under Creative Commons Attribution (http://creativecommons.org/licenses/by/4.0/).
        */
        
        guard let url = Bundle.main.url(forResource: "f1_model", withExtension: "obj", subdirectory: "SceneKitAssets.scnassets") else { fatalError("Failed to find model file.")
        }

        let asset = MDLAsset(url:url)
        guard let carObject = asset.object(at: 0) as? MDLMesh else {
            fatalError("Failed to get mesh from asset.")
        }
        
        let node = SCNNode(mdlObject: carObject)
        node.geometry?.firstMaterial?.emission.contents = color
        node.scale = SCNVector3(x: 1.08, y: 1, z: 1.18)
        node.opacity = 0.5
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Update camera position every frame
        cameraNode.position = cameraPos.coords
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

