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
        
        car1.scale = SCNVector3(x: 0.75, y: 0.75, z: 0.75)
        car1.position = SCNVector3Make(0.0, 0.0, 0.0)
        car1.opacity = 0.9
        self.rootNode.addChildNode(car1)
        
        car2.scale = SCNVector3(x: 0.75, y: 0.75, z: 0.75)
        car2.position = SCNVector3Make(0.0, 0.0, 0.0)
        car2.opacity = 0.9
        self.rootNode.addChildNode(car2)
        
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
        cameraNode.camera?.zFar = 500
        let lookAt = SCNLookAtConstraint(target: car1)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]
        car1.addChildNode(cameraNode) // Camera is added as a child node of car1, and will be positioned relative to car 1 always
        
        self.nextMove(node: car1, carPos: car1Pos, color: UIColor.blue)
        self.nextMove(node: car2, carPos: car2Pos, color: UIColor.orange)
    }
        
    private func nextMove(node: SCNNode, carPos: CarPositions, color: UIColor) {
        if carPos.count < carPos.positions.count - 1 {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = carPos.positions[carPos.count].duration
            node.look(at: carPos.positions[carPos.count].coords, up: self.rootNode.worldUp, localFront: SCNVector3(0,0,1))
            SCNTransaction.commit()
            
            node.runAction(SCNAction.move(to: carPos.positions[carPos.count].coords, duration: carPos.positions[carPos.count].duration)) {
                // Trace path of movement
                if carPos.count > 0 {
                    let positionA = carPos.positions[carPos.count - 1].coords
                    let positionB = carPos.positions[carPos.count].coords
                    self.tracePath(positionA: positionA, positionB: positionB, color: color, radius: 0.1, offset: 0.5)
                }
                
                carPos.count += 1
                self.nextMove(node: node, carPos: carPos, color: color)
            }
        }
    }
    
    private func tracePath(positionA: SCNVector3, positionB: SCNVector3, color: UIColor, radius: CGFloat, offset: Float) {
        let vector = SCNVector3(positionA.x - positionB.x, (positionA.y + offset) - (positionB.y + offset), positionA.z - positionB.z)
        let distance = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        let midPosition = SCNVector3 (x: (positionA.x + positionB.x) / 2, y: (positionA.y + positionB.y) / 2, z: (positionA.z + positionB.z) / 2)
        
        let lineGeometry = SCNCylinder(radius: radius, height: CGFloat(distance))
        lineGeometry.firstMaterial!.diffuse.contents = color

        let lineNode = SCNNode(geometry: lineGeometry)
        lineNode.position = midPosition
        lineNode.look(at: positionB, up: self.rootNode.worldUp, localFront: lineNode.worldUp)
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
        lineNode.look(at: positionB, up: self.rootNode.worldUp, localFront: SCNVector3(0,0,1))
        self.rootNode.addChildNode(lineNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        self.cameraNode.position = self.cameraPos.coords
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

