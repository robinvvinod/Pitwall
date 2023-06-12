//
//  ComparisonScene.swift
//  pitwall-ios
//
//  Created by Robin on 2/6/23.
//

import SceneKit
import SceneKit.ModelIO

class ComparisonScene: SCNScene, SCNSceneRendererDelegate {
    
    private var car1Pos: CarPositions
    private var car2Pos: CarPositions
    private var cameraPos: CameraPosition
    private var cameraNode: SCNNode
    private var car1: SCNNode
    private var car2: SCNNode
    
    init(car1Pos: CarPositions, car2Pos: CarPositions, cameraPos: CameraPosition) {
        self.car1Pos = car1Pos
        self.car2Pos = car2Pos
        self.cameraPos = cameraPos
        
        // Setting up camera and car nodes. Needs to be done before calling super.init()
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
        
        super.init()
        
        self.background.contents = MDLSkyCubeTexture(name: "sky",
                                          channelEncoding: .float16,
                                        textureDimensions: vector_int2(128, 128),
                                                turbidity: 0,
                                             sunElevation: 1.5,
                                upperAtmosphereScattering: 0.5,
                                             groundAlbedo: 0.5)
        self.lightingEnvironment.contents = self.background.contents
        
        // Generate track path drawing using lead cars coords, with a fixed width of 12m
        for i in 0..<car1Pos.positions.count - 1 {
            self.drawTrack(positionA: car1Pos.positions[i].coords, positionB: car1Pos.positions[i+1].coords, width: 12, offset: -0.5)
        }
                
        self.car1.scale = SCNVector3(x: 0.75, y: 0.75, z: 0.75)
        self.car1.position = self.car1Pos.positions[0].coords
        self.car1.opacity = 0.9
        self.rootNode.addChildNode(self.car1)
        
        self.car2.scale = SCNVector3(x: 0.75, y: 0.75, z: 0.75)
        self.car2.position = self.car2Pos.positions[0].coords
        self.car2.opacity = 0.9
        self.rootNode.addChildNode(self.car2)
        
        self.cameraNode.camera = SCNCamera()
        self.cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
        self.cameraNode.camera?.zFar = 500
        let lookAt = SCNLookAtConstraint(target: car1)
        lookAt.isGimbalLockEnabled = true
        self.cameraNode.constraints = [lookAt]
        self.car1.addChildNode(self.cameraNode) // Camera is added as a child node of car1, and will be positioned relative to car 1 always
        
        let car1Seq = self.generateActionSequence(carPos: self.car1Pos)
        let car2Seq = self.generateActionSequence(carPos: self.car2Pos)
        
        self.car1.runAction(car1Seq)
        self.car2.runAction(car2Seq)
    }
    
    private func generateActionSequence(carPos: CarPositions) -> SCNAction {
        var seq: [SCNAction] = []
        for i in 0...(carPos.positions.count - 1) {
            /*
             These placeholder vars are needed to avoid the lookWithDurationAction block from using reference-type values of x,y,z from
             the carPos instance at the time the action is called, instead of the values when the block is instantiated.
            */
            let x = carPos.positions[i].coords.x
            let y = carPos.positions[i].coords.y
            let z = carPos.positions[i].coords.z
            let dur = carPos.positions[i].duration

            /*
             Every action in the sequence is a grouped action comprising of the move to the current coordinate and the rotation of the car
             to look at the destination coordinate. These 2 actions are exectured in parallel.
            */
            let lookWithDurationAction = SCNAction.run { node in
                SCNTransaction.begin()
                SCNTransaction.animationDuration = dur
                node.look(at: SCNVector3(x: x, y: y, z: z), up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,1))
                SCNTransaction.commit()
            }
            
            let group = SCNAction.group([
                SCNAction.move(to: SCNVector3(x: x, y: y, z: z), duration: dur),
                lookWithDurationAction
            ])
            seq.append(group)
        }
        return SCNAction.sequence(seq)
    }
        
    private func tracePath(positionA: SCNVector3, positionB: SCNVector3, color: UIColor, radius: CGFloat, offset: Float) {
        let vector = SCNVector3(positionA.x - positionB.x, (positionA.y + offset) - (positionB.y + offset), positionA.z - positionB.z)
        let distance = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        let midPosition = SCNVector3 (x: (positionA.x + positionB.x) / 2, y: (positionA.y + positionB.y) / 2, z: (positionA.z + positionB.z) / 2)
        
        let lineGeometry = SCNCylinder(radius: radius, height: CGFloat(distance))
        lineGeometry.firstMaterial!.diffuse.contents = color

        let lineNode = SCNNode(geometry: lineGeometry)
        lineNode.position = midPosition
        lineNode.look(at: positionB, up: SCNVector3(0,1,0), localFront: lineNode.worldUp)
        self.rootNode.addChildNode(lineNode)
    }
    
    private func drawTrack(positionA: SCNVector3, positionB: SCNVector3, width: CGFloat, offset: Float) {
        let vector = SCNVector3(positionA.x - positionB.x, (positionA.y + offset) - (positionB.y + offset), positionA.z - positionB.z)
        let distance = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        let midPosition = SCNVector3 (x: (positionA.x + positionB.x) / 2, y: (positionA.y + positionB.y) / 2, z: (positionA.z + positionB.z) / 2)

        let lineGeometry = SCNBox(width: width, height: 0.01, length: CGFloat(distance), chamferRadius: 0)
        lineGeometry.firstMaterial!.diffuse.contents = UIColor.darkGray

        let lineNode = SCNNode(geometry: lineGeometry)
        lineNode.position = midPosition
        lineNode.look(at: positionB, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,1))
        self.rootNode.addChildNode(lineNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Update camera position every frame
        self.cameraNode.position = self.cameraPos.coords
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

