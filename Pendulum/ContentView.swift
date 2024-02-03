//
//  ContentView.swift
//  Pendulum
//
//  Created by Игорь Михайлов on 30.11.2023.
//

import SwiftUI

extension UIScreen{
    static let screenWidth = UIScreen.main.bounds.size.width
    static let screenHeight = UIScreen.main.bounds.size.height
    static let screenSize = UIScreen.main.bounds.size
}

enum Projection: String, CaseIterable {
    case dotted, line
}

extension CGPoint {
    func distance(to point: CGPoint) -> Double {
        sqrt(pow(self.x - point.x, 2) + pow(self.y - point.y, 2))
    }
}

struct IdentifiablePath: Identifiable {
    var id = UUID()
    var path: Path
}

struct CanvasRenderPart: View, Equatable {
    static func == (lhs: CanvasRenderPart, rhs: CanvasRenderPart) -> Bool {
        lhs.data.id == lhs.data.id
    }
    
    var data: IdentifiablePath
    
    var body: some View {
        Canvas { context, size in
            context.translateBy(x: size.width/2, y: size.height/2)
            context.fill(data.path, with: .color(.white))
        }
    }
}

class Pendulum {
    var speed = 2.0
    var coef = Double.pi
    var type = Projection.line
    var lineWidth = 1.0
    var isRunning = false {
        didSet {
            lastPosition = pos2
        }
    }
    
    var rotation1 = Angle.degrees(0)
    var rotation2 = Angle.degrees(0)
    var pos1: CGPoint
    var pos2: CGPoint
    
    var stickLength = 90.0 {
        didSet {
            recalculatePositions()
        }
    }
    var stickLength2 = 90.0 {
        didSet {
            recalculatePositions()
        }
    }
    
    var oldPaths = [IdentifiablePath]()
    var underPath = Path()
    var path = Path()
    var countOfPoints = 0
    var lastPosition: CGPoint
    
    init(stickLength1: Double, stickLength2: Double) {
        pos1 = CGPoint(x: 0, y: stickLength1)
        pos2 = CGPoint(x: 0, y: stickLength1+stickLength2)
        lastPosition = pos2
    }
    
    func recalculatePositions() {
        pos1 =  .init(x: cos(rotation1.radians + .pi/2)*stickLength, y: sin(rotation1.radians + .pi/2)*stickLength)
        pos2 = .init(x: pos1.x + cos(rotation2.radians + .pi/2)*stickLength2, y: pos1.y + sin(rotation2.radians + .pi/2)*stickLength2)
    }
    
    func erase() {
        oldPaths = []
        path = Path()
        countOfPoints = 0
    }
    
    func refresh() {
        erase()
        rotation1 = .zero
        rotation2 = .zero
        recalculatePositions()
        lastPosition = pos2
    }
    
    func update(_ date: Date, size: CGSize) {
        for _ in 0..<Int(speed) {
            rotation1 -= .degrees(0.2)
            rotation2 -= .degrees(0.2*coef)
            recalculatePositions()
            
            if lastPosition.distance(to: pos2) > 5 {
                if type == .line {
                    var subPath = Path()
                    subPath.move(to: lastPosition)
                    subPath.addLine(to: pos2)
                    subPath = subPath.stroke(lineWidth: lineWidth).path(in: .init(origin: .zero, size: size))
                    path.addPath(subPath)
                    
                    lastPosition = pos2
                    countOfPoints += 1
                } else {
                    var subPath = Path()
                    subPath.addEllipse(in: .init(x: pos2.x - lineWidth/2, y: pos2.y - lineWidth/2, width: lineWidth, height: lineWidth))
                    subPath = subPath.stroke(lineWidth: 1).path(in: .init(origin: .zero, size: size))
                    path.addPath(subPath)
                    
                    lastPosition = pos2
                    countOfPoints += 1
                }
            }
        }
        if countOfPoints > 1000 {
            oldPaths.append(IdentifiablePath(path: path))
            underPath = path
            
            path = Path()
            countOfPoints = 0
        }
    }
}

struct ContentView: View {
    @State var pendulum = Pendulum(stickLength1: 90.0, stickLength2: 90.0)
    
    func drawCircle(in context: GraphicsContext, size: Double, x: Double, y: Double, fill: Bool = false) {
        let shape = fill ? (Circle() as (any Shape)) : Circle().stroke(lineWidth: 1)
        let origin = CGPoint(x: x-size/2, y: y-size/2)
        let size = CGSize(width: size, height: size)
        
        context.fill(shape.path(in: .init(origin: origin, size: size)), with: .color(.white))
    }
    
    func drawStick(in context: GraphicsContext, height: Double, x: Double, y: Double, rotation: Angle) {
        let origin = CGPoint(x: x-0.5, y: y)
        let size = CGSize(width: 1, height: height)
        
        context.fill(Rectangle().rotation(rotation, anchor: .top).path(in: .init(origin: origin, size: size)), with: .color(.white))
    }
    
    var body: some View {
        VStack {
                TimelineView(.animation) { timeline in
                    ZStack {
                        Canvas { context, size in
                            if pendulum.isRunning {
                                pendulum.update(timeline.date, size: size)
                            }
                            
                            let centerSize = 10.0
                            let stickLength = pendulum.stickLength
                            let stickLength2 = pendulum.stickLength2
                            
                            context.translateBy(x: size.width/2, y: size.height/2)
                            
                            drawCircle(in: context, size: centerSize, x: 0, y: 0)
                            drawStick(in: context, height: stickLength, x: 0, y: 0, rotation: pendulum.rotation1)
                            drawCircle(in: context, size: centerSize, x: pendulum.pos1.x, y: pendulum.pos1.y)
                            drawStick(in: context, height: stickLength2, x: pendulum.pos1.x, y: pendulum.pos1.y, rotation: pendulum.rotation2)
                            drawCircle(in: context, size: centerSize, x: pendulum.pos2.x, y: pendulum.pos2.y, fill: true)
                            
                            context.fill(pendulum.path, with: .color(.white))
                            context.fill(pendulum.underPath, with: .color(.white))
                        }
                        
                        ForEach(pendulum.oldPaths) { data in
                            CanvasRenderPart(data: data)
                                .equatable()
                                .onAppear { pendulum.underPath = Path() }
                        }
                    }
                }
            
            VStack {
                HStack {
                    Button(action: pendulum.erase) {
                        Image(systemName: "eraser.fill")
                            .font(.subheadline)
                            .padding(10)
                            .foregroundStyle(.white)
                            .background(.white.opacity(0.5))
                            .clipShape(Circle())
                            .padding(.trailing, 10)
                    }
                    Button(action: pendulum.refresh) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 45))
                            .foregroundStyle(.white)
                            .padding(.trailing)
                    }
                    
                    Toggle("", isOn: $pendulum.isRunning)
                }
                VStack {
                    HStack {
                        Text("Speed")
                            .frame(width: 70, alignment: .leading)
                        Slider(value: $pendulum.speed, in: 1...100, step: 1)
                    }
                    HStack {
                        Text("Rotation")
                            .frame(width: 70, alignment: .leading)
                        Slider(value: $pendulum.coef, in: 0...7)
                    }
                    
                    HStack {
                        Text("Length")
                            .frame(width: 70, alignment: .leading)
                        Slider(value: $pendulum.stickLength, in: 25...UIScreen.screenWidth/4)
                        Slider(value: $pendulum.stickLength2, in: 25...UIScreen.screenWidth/4)
                    }
                    HStack {
                        Text("Style")
                            .frame(width: 70, alignment: .leading)
                        Picker("Type", selection: $pendulum.type) {
                            ForEach(Projection.allCases, id: \.self) { type in
                                Text(type.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Slider(value: $pendulum.lineWidth, in: 0.5...5)
                    }
                }
                .font(.system(size: 14, weight: .heavy, design: .rounded))
            }
            .padding([.horizontal, .bottom])
            .tint(.white.opacity(0.5))
        }
        
        .background(.black)
    }
}

#Preview {
    ContentView()
}
