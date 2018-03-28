//
//  ViewController.swift
//  ARTargeting
//
//  Created by 宋 奎熹 on 2018/3/19.
//  Copyright © 2018年 宋 奎熹. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    private let frontSightRadius    : CGFloat        = 25.0
    private let generationCycle     : TimeInterval   = 3.0
    
    private var currentScore: Int = 0 {
        didSet {
            DispatchQueue.main.async { [unowned self] in
                let node = self.scoreNode
                let text = node.geometry as! SCNText
                text.string = "\(self.currentScore)"
                
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.random()
                node.geometry?.materials = [material]
            }
        }
    }
    private lazy var blurView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .dark)
        return UIVisualEffectView(effect: blurEffect)
    }()
    private lazy var waitLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: screenWidth / 2.0 - 150, y: screenHeight / 2.0 - 100, width: 300, height: 200))
        label.font = UIFont.systemFont(ofSize: 35.0, weight: .bold)
        label.textColor = .white
        label.text = "Move around\nyour device"
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
    private var targetNodes = Set<TargetNode>()
    private var planes: [UUID: PlaneNode] = [:]
    private lazy var scoreNode: SCNNode = {
        let text = SCNText(string: "0", extrusionDepth: 0.5)
        text.chamferRadius = 1.0
        text.flatness = 0.1
        text.font = UIFont.systemFont(ofSize: 40.0, weight: .bold)
        let node = SCNNode(geometry: text)
        node.scale = SCNVector3(0.05, 0.05, 0.05)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.random()
        node.geometry?.materials = [material]
        node.position = SCNVector3(-0.5, 0, -10)
        let (minBound, maxBound) = text.boundingBox
        node.pivot = SCNMatrix4MakeTranslation((maxBound.x - minBound.x) / 2, minBound.y, 0.5 / 2)
        return node
    }()
    
    private lazy var generateTimer: Timer = {
        weak var weakSelf = self
        return Timer(timeInterval: generationCycle, repeats: true) { _ in
            weakSelf?.generateTarget()
        }
    }()
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var frontSight: FrontSightView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        sceneView.scene.physicsWorld.contactDelegate = self
        sceneView.scene.physicsWorld.gravity = SCNVector3(0, -1, 0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = .horizontal

        sceneView.session.run(configuration)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
        
        self.blurView.frame = self.waitLabel.frame
        self.view.addSubview(self.blurView)
        self.view.addSubview(self.waitLabel)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { [unowned self] in
            self.waitLabel.text = "Tap to Shoot!"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(6)) { [unowned self] in
            self.waitLabel.removeFromSuperview()
            self.blurView.removeFromSuperview()
            
            RunLoop.main.add(self.generateTimer, forMode: .commonModes)
        }
        
        self.sceneView.scene.rootNode.addChildNode(scoreNode)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
    deinit {
        generateTimer.invalidate()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    private func generateTarget() {
        let count = Int(arc4random() % 3) + 1
        
        var i = 0
        while i < count {
            let x: Float = (Float(arc4random() % 20) / 5.0) - 2.0
            let y: Float = (Float(arc4random() % 10) / 5.0)
            let z: Float = -(Float(arc4random() % 20) / 5.0) - 2.0
            
            let targetNode = TargetNode.generateTarget()
            targetNode.position = SCNVector3(x, y, z)
            targetNode.rotation = SCNVector4(x: 1, y: 0, z: 0, w: .pi / 2.0)
            
            self.targetNodes.insert(targetNode)
            targetNode.physicsBody?.applyForce(SCNVector3(0, 0.25, 0), asImpulse: true)
            self.sceneView.scene.rootNode.addChildNode(targetNode)
            
            i += 1
        }
    }

    @objc private func handleTap(gestureRecognize: UITapGestureRecognizer) {
        let bulletNode = BulletNode()

        let (direction, position) = getUserVector()
        
//        let originalZ: Float = Float(-5.0 + bulletRadius * 2.0)
//        bulletNode.position = SCNVector3(position.x + (originalZ - position.z) * direction.x / direction.z,
//                                         position.y + (originalZ - position.z) * direction.y / direction.z,
//                                         originalZ)
        bulletNode.position = position + direction * 2.0
        print(bulletNode.position)
        
        bulletNode.physicsBody?.applyForce(SCNVector3(direction.x * 3,
                                                      direction.y * 3,
                                                      direction.z * 3),
                                           asImpulse: true)
        bulletNode.playSound(.shoot)
        sceneView.scene.rootNode.addChildNode(bulletNode)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        for node in sceneView.scene.rootNode.childNodes where node is BulletNode &&  node.presentation.position.distance(from: .zero) > 20 {
            node.removeFromParentNode()
        }
//        var targetToRemove: [TargetNode] = []
//        for target in targetNodes where target.presentation.position.y < -20 && !target.hit {
//            targetToRemove.append(target)
//        }
//        DispatchQueue.main.async { [unowned self] in
//            targetToRemove.forEach {
//                $0.removeFromParentNode()
//                self.targetNodes.remove($0)
//            }
//        }
        
        let (pos, dir) = getUserVector()
        
        for targetNode in targetNodes {
            let targetVector = targetNode.presentation.position + pos * (-1)
            print(targetVector.theta(from: dir))
        }
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        print("Add a node")
        guard let anchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        let plane = PlaneNode(withAnchor: anchor)
        planes[anchor.identifier] = plane
        node.addChildNode(plane)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let plane = planes[anchor.identifier] else {
            return
        }
        
        plane.update(anchor: anchor as! ARPlaneAnchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        planes.removeValue(forKey: anchor.identifier)
    }
    
    private func getUserVector() -> (direction: SCNVector3, position: SCNVector3) {
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform)
            let direction = SCNVector3(-mat.m31, -mat.m32, -mat.m33)
            let position = SCNVector3(mat.m41, mat.m42, mat.m43)
            return (direction, position)
        }
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }
    
}

extension ViewController: SCNPhysicsContactDelegate {
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.target.rawValue
            || contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.target.rawValue {
            
            var targetNode: TargetNode = TargetNode()
            if contact.nodeA is TargetNode {
                targetNode = contact.nodeA as! TargetNode
            } else {
                targetNode = contact.nodeB as! TargetNode
            }
            
            guard !targetNode.hit else {
                return
            }
            
            currentScore += targetNode.hitScore
            
            let particleSystem = SCNParticleSystem(named: "art.scnassets/Explode.scnp", inDirectory: nil)
            particleSystem?.particleColor = targetNode.type?.color ?? .clear
            let particleSystemNode = SCNNode()
            particleSystemNode.addParticleSystem(particleSystem!)
            particleSystemNode.position = targetNode.presentation.position
            sceneView.scene.rootNode.addChildNode(particleSystemNode)
            
            particleSystemNode.playSound(.hit)
            
            self.targetNodes.remove(targetNode)
            targetNode.removeFromParentNode()
            
            let text = SCNText(string: "\(targetNode.hitScore > 0 ? "+" : "")\(targetNode.hitScore)", extrusionDepth: 1.0)
            text.chamferRadius = 1.0
            text.flatness = 0.1
            text.font = UIFont.systemFont(ofSize: 10.0, weight: .bold)
            let addScoreNode = SCNNode(geometry: text)
            addScoreNode.scale = SCNVector3(0.01, 0.01, 0.01)
            let material = SCNMaterial()
            material.diffuse.contents = targetNode.type?.color ?? .white
            addScoreNode.geometry?.materials = Array<SCNMaterial>(repeating: material, count: 5)
            addScoreNode.position = targetNode.presentation.position
            
            sceneView.scene.rootNode.addChildNode(addScoreNode)
           
            addScoreNode.runAction(SCNAction.sequence([SCNAction.move(by: SCNVector3(0, 0.1, 0), duration: 1.0), SCNAction.removeFromParentNode()]))
            
            targetNode.hit = true
        }
    }

}
