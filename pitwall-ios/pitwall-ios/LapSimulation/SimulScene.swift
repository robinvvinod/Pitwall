//
//  ComparisonScene.swift
//  pitwall-ios
//
//  Created by Robin on 2/6/23.
//

import SceneKit
import SceneKit.ModelIO

class SimulScene: SCNScene, SCNSceneRendererDelegate {
    
    var carNodes = [SCNNode]()
    var actionSequences: [SCNAction]
    var startPosList: [(startPos: SCNVector3, lookAt: SCNVector3)]
    private var trackNode: SCNNode
    private var cameraPos: LapSimulationViewModel.CameraPosition
    private var cameraNode: SCNNode
    
    init(actionSequences: [SCNAction], cameraPos: LapSimulationViewModel.CameraPosition, trackNode: SCNNode, startPosList: [(startPos: SCNVector3, lookAt: SCNVector3)]) {
        self.actionSequences = actionSequences
        self.cameraPos = cameraPos
        self.trackNode = trackNode
        self.startPosList = startPosList
        self.cameraNode = SCNNode()

        super.init()
        
        background.contents = MDLSkyCubeTexture(name: "sky",
                                          channelEncoding: .float16,
                                        textureDimensions: vector_int2(128, 128),
                                                turbidity: 0,
                                             sunElevation: 1.5,
                                upperAtmosphereScattering: 0.5,
                                             groundAlbedo: 0.5)
        lightingEnvironment.contents = background.contents
        
        let colorMap = [UIColor.blue, UIColor.green, UIColor.orange, UIColor.purple, UIColor.red]
        rootNode.addChildNode(self.trackNode)
        for i in 0...(self.actionSequences.count - 1) {
            self.carNodes.append(loadModel(color: colorMap[i]))
            rootNode.addChildNode(self.carNodes[i])
            self.carNodes[i].position = self.startPosList[i].startPos
            self.carNodes[i].look(at: self.startPosList[i].lookAt, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,1))
        }
        
        self.cameraNode.camera = SCNCamera()
        self.cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
        self.cameraNode.camera?.zFar = 1000
        let lookAt = SCNLookAtConstraint(target: self.carNodes[0])
        lookAt.isGimbalLockEnabled = true
        self.cameraNode.constraints = [lookAt]
        self.carNodes[0].addChildNode(self.cameraNode) // Camera is added as a child node of car1, and will be positioned relative to car 1 always
    }
    
    private func loadModel(color: UIColor) -> SCNNode {
        /*
         "F1 2022 {FREE!!}" (https://skfb.ly/oFxwG) by 3dblenderlol is licensed under Creative Commons Attribution (http://creativecommons.org/licenses/by/4.0/).
        */
        
        let asset = SCNScene(named: "SceneKitAssets.scnassets/f1_model.scn")!
        guard let node = asset.rootNode.childNode(withName: "model", recursively: false) else {
            return SCNNode()
        }
        
        node.scale = SCNVector3(x: 1.08, y: 1, z: 1.18)
//        node.opacity = 0.5
        
        if let carMesh = node.childNode(withName: "car", recursively: false) {
            carMesh.enumerateChildNodes { subNode, stop  in
                if let materials = subNode.geometry?.materials {
                    for mat in materials {
                        mat.diffuse.contents = color
                    }
                }
            }
        }

        return node.flattenedClone()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Update camera position every frame
        cameraNode.position = cameraPos.coords
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

