//
//  ComparisonScene.swift
//  pitwall-ios
//
//  Created by Robin on 2/6/23.
//

import SceneKit
import SceneKit.ModelIO

class SimulScene: SCNScene, SCNSceneRendererDelegate {
    
    var car1: SCNNode
    var car2: SCNNode
    var car1Seq: SCNAction
    var car2Seq: SCNAction
    var startPos: (p1: SCNVector3, l1: SCNVector3, p2: SCNVector3, l2: SCNVector3)
    private var trackNode: SCNNode
    private var cameraPos: LapSimulationViewModel.CameraPosition
    private var cameraNode: SCNNode
    
    init(car1Seq: SCNAction, car2Seq: SCNAction, cameraPos: LapSimulationViewModel.CameraPosition, trackNode: SCNNode, startPos: (p1: SCNVector3, l1: SCNVector3, p2: SCNVector3, l2: SCNVector3)) {
        self.car1Seq = car1Seq
        self.car2Seq = car2Seq
        self.cameraPos = cameraPos
        self.trackNode = trackNode
        self.startPos = startPos
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
        
        self.car1.position = startPos.p1
        self.car1.look(at: startPos.l1, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,1))
        self.car2.position = startPos.p2
        self.car2.look(at: startPos.l2, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,1))
        
        self.cameraNode.camera = SCNCamera()
        self.cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
        self.cameraNode.camera?.zFar = 1000
        let lookAt = SCNLookAtConstraint(target: car1)
        lookAt.isGimbalLockEnabled = true
        self.cameraNode.constraints = [lookAt]
        self.car1.addChildNode(self.cameraNode) // Camera is added as a child node of car1, and will be positioned relative to car 1 always
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

