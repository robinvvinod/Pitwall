//
//  LapComparisonView.swift
//  pitwall-ios
//
//  Created by Robin on 29/5/23.
//

import SwiftUI
import SceneKit

struct LapSimulationView: View {
        
    let viewModel: LapSimulationViewModel
    
    var body: some View {
        sceneView
    }
    
    @State private var prevX: Double = 0 // Stores last x coord in gesture to check direction of gesture when next x coord comes in
    @State private var zSign: Bool = true // true is +ve z, false is -ve z
    private let xModifier: Float = 0.5 // Scales gesture distance to change in coords of viewModel.cameraPos
    
    var sceneView: some View {
        let scene = SimulScene(car1Seq: viewModel.car1Seq, car2Seq: viewModel.car2Seq, cameraPos: viewModel.cameraPos, trackNode: viewModel.trackNode, startPos: viewModel.startPos)
        return SimulSceneView(scene: scene)
            .gesture(orbitGesture)
    }
    
    var orbitGesture: some Gesture {
        return DragGesture()
            .onChanged { translate in

                if translate.translation.width > prevX { // Moving to the east
                    viewModel.cameraPos.coords.x += zSign ? xModifier : -xModifier // controls direction of magnitude change of viewModel.cameraPos.coords.x
                } else {
                    viewModel.cameraPos.coords.x += zSign ? -xModifier : xModifier
                }

                prevX = translate.translation.width

                /*
                    This block ensures that cameraPos.coords.x is always within [-cameraPos.radius, cameraPos.radius]
                    If cameraPos.coords.x > cameraPos.radius, cameraPos.coords.x will decrease until -cameraPos.radius
                    If cameraPos.coords.x < -cameraPos.radius, cameraPos.coords.x will increase until cameraPos.radius
                    Direction of change is determined by zSign

                    This allows for "rolling" over of cameraPos.coords.x when crossing boundary points
                */
                if (viewModel.cameraPos.coords.x > viewModel.cameraPos.radius) && (zSign == true) {
                    zSign = false
                    viewModel.cameraPos.coords.x = viewModel.cameraPos.radius
                } else if (viewModel.cameraPos.coords.x > viewModel.cameraPos.radius) && (zSign == false) {
                    zSign = true
                    viewModel.cameraPos.coords.x = viewModel.cameraPos.radius
                } else if (viewModel.cameraPos.coords.x < -viewModel.cameraPos.radius) && (zSign == true) {
                    zSign = false
                    viewModel.cameraPos.coords.x = -viewModel.cameraPos.radius
                } else if (viewModel.cameraPos.coords.x < -viewModel.cameraPos.radius) && (zSign == false) {
                    zSign = true
                    viewModel.cameraPos.coords.x = -viewModel.cameraPos.radius
                }

                // If zSign is -ve, cameraPos is "behind" the point of reference and cameraPos.coords.z should be negative
                viewModel.cameraPos.coords.z = zSign ? sqrt(pow(viewModel.cameraPos.radius,2) - pow(viewModel.cameraPos.coords.x, 2)) : -sqrt(pow(viewModel.cameraPos.radius,2) - pow(viewModel.cameraPos.coords.x, 2))
            }
    }
}
