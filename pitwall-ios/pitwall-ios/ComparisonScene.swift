//
//  ComparisonScene.swift
//  pitwall-ios
//
//  Created by Robin on 2/6/23.
//

import SceneKit

class ComparisonScene: SCNScene, SCNSceneRendererDelegate {
    
    private var car1Pos: CarPositions
    private var car2Pos: CarPositions
    private var cameraPos: CameraPosition
    private var cameraNode: SCNNode
    
    init(car1Pos: CarPositions, car2Pos: CarPositions, cameraPos: CameraPosition) {
        self.car1Pos = car1Pos
        self.car2Pos = car2Pos
        self.cameraPos = cameraPos
        let cameraNode = SCNNode()
        self.cameraNode = cameraNode
        super.init()
        
        self.background.contents = MDLSkyCubeTexture(name: "sky",
                                          channelEncoding: .float16,
                                        textureDimensions: vector_int2(128, 128),
                                                turbidity: 0,
                                             sunElevation: 1.5,
                                upperAtmosphereScattering: 0.5,
                                             groundAlbedo: 0.5)
        self.lightingEnvironment.contents = self.background.contents
        
        for i in 0..<car1Pos.positions.count - 1 {
            self.rootNode.addChildNode(self.drawTrack(positionA: SCNVector3(car1Pos.positions[i].coords.x, car1Pos.positions[i].coords.y - 0.5, car1Pos.positions[i].coords.z), positionB: SCNVector3(car1Pos.positions[i+1].coords.x, car1Pos.positions[i+1].coords.y - 0.5, car1Pos.positions[i+1].coords.z)))
        }
                    
        let car1geo = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        car1geo.firstMaterial?.diffuse.contents = UIColor.blue
        
        let car1 = SCNNode(geometry: car1geo)
        car1.position = SCNVector3Make(0.0, 0.0, 0.0)
        self.rootNode.addChildNode(car1)
        
        let car2geo = SCNSphere(radius: 0.5)
        car2geo.firstMaterial?.diffuse.contents = UIColor.orange
        
        let car2 = SCNNode(geometry: car2geo)
        car2.position = SCNVector3Make(0.0, 0.0, 0.0)
        self.rootNode.addChildNode(car2)
        
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
        let lookAt = SCNLookAtConstraint(target: car1)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]
        car1.addChildNode(cameraNode) // Camera is added as a child node of car1, and will be positioned relative to car 1 always
        
        self.nextMove(node: car1, carPos: car1Pos, color: UIColor.blue)
        self.nextMove(node: car2, carPos: car2Pos, color: UIColor.orange)
    }
        
    private func nextMove(node: SCNNode, carPos: CarPositions, color: UIColor) {
        if carPos.count < carPos.positions.count - 1 {
            node.runAction(SCNAction.move(to: carPos.positions[carPos.count].coords, duration: carPos.positions[carPos.count].duration)) {
                // Trace path of movement
                if carPos.count > 0 {
                    let positionA = carPos.positions[carPos.count - 1].coords
                    let positionB = carPos.positions[carPos.count].coords
                    self.tracePath(positionA: positionA, positionB: positionB, color: color)
                }
                
                carPos.count += 1
                self.nextMove(node: node, carPos: carPos, color: color)
            }
        }
    }
    
    private func tracePath(positionA: SCNVector3, positionB: SCNVector3, color: UIColor) {
        let vector = SCNVector3(positionA.x - positionB.x, positionA.y - positionB.y, positionA.z - positionB.z)
        let distance = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        let midPosition = SCNVector3 (x: (positionA.x + positionB.x) / 2, y: (positionA.y + positionB.y) / 2, z: (positionA.z + positionB.z) / 2)
        
        let lineGeometry = SCNCylinder(radius: 0.01, height: CGFloat(distance))
        lineGeometry.firstMaterial!.diffuse.contents = color

        let lineNode = SCNNode(geometry: lineGeometry)
        lineNode.position = midPosition
        lineNode.look(at: positionB, up: self.rootNode.worldUp, localFront: lineNode.worldUp)
        self.rootNode.addChildNode(lineNode)
    }
    
    private func drawTrack(positionA: SCNVector3, positionB: SCNVector3) -> SCNNode {
        let vector = SCNVector3(positionA.x - positionB.x, positionA.y - positionB.y, positionA.z - positionB.z)
        let distance = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        let midPosition = SCNVector3 (x: (positionA.x + positionB.x) / 2, y: (positionA.y + positionB.y) / 2, z: (positionA.z + positionB.z) / 2)

        let lineGeometry = SCNBox(width: 3, height: 0.1, length: CGFloat(distance), chamferRadius: 0)
        lineGeometry.firstMaterial!.diffuse.contents = UIColor.green

        let lineNode = SCNNode(geometry: lineGeometry)
        lineNode.position = midPosition
        lineNode.look(at: positionB, up: self.rootNode.worldUp, localFront: SCNVector3(0,0,1))
        return lineNode
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        self.cameraNode.position = self.cameraPos.coords
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

