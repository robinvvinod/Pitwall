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
                    
        let car1geo = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        car1geo.firstMaterial?.diffuse.contents = UIColor.blue
        
        let car1 = SCNNode(geometry: car1geo)
        car1.position = SCNVector3Make(0.0, 0.0, 0.0)
        self.rootNode.addChildNode(car1)
        
        let car2geo = SCNSphere(radius: 1)
        car2geo.firstMaterial?.diffuse.contents = UIColor.orange
        
        let car2 = SCNNode(geometry: SCNSphere(radius: 1))
        car2.position = SCNVector3Make(0.0, 0.0, 0.0)
        self.rootNode.addChildNode(car2)
        
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
        cameraNode.constraints = [SCNLookAtConstraint(target: car1)]
        car1.addChildNode(cameraNode) // Camera is added as a child node of car1, and will be positioned relative to car 1 always
        
        self.nextMove(node: car1, carPos: car1Pos)
        self.nextMove(node: car2, carPos: car2Pos)
    }
        
    private func nextMove(node: SCNNode, carPos: CarPositions) {
        if carPos.count < carPos.positions.count - 1 {
            node.runAction(SCNAction.move(to: SCNVector3(x: carPos.positions[carPos.count].x, y: carPos.positions[carPos.count].y, z: carPos.positions[carPos.count].z), duration: carPos.positions[carPos.count].duration)) {
                carPos.count += 1
                self.nextMove(node: node, carPos: carPos)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        self.cameraNode.position = SCNVector3(x: self.cameraPos.x, y: self.cameraPos.y, z: self.cameraPos.z)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
