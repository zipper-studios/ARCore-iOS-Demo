//
//  ViewController.swift
//  ARCoreTutorial
//
//  Created by Nicoleta Pop on 5/13/19.
//  Copyright © 2019 Nicoleta Pop. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import ARCore
import Firebase

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, GARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    private var garSession: GARSession!
    private var anchorIDList: [String] = []
    
    private lazy var firebaseDbRoot = Database.database().reference().child("hotspot_list")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        garSession = try! GARSession(apiKey: "INSERT_YOUR_API_KEY", bundleIdentifier: nil)
        garSession.delegate = self
        garSession.delegateQueue = DispatchQueue.main
        
        fetchAnchors()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        
        let touchLoc = touch.location(in: sceneView)
        let hitResults = sceneView.hitTest(touchLoc, types: [.existingPlane, .existingPlaneUsingExtent, .estimatedHorizontalPlane])
        
        if let firstResult = hitResults.first {
            hostAnchor(transform: firstResult.worldTransform)
        }
    }
    
    
    @IBAction func resolveAnchorsTapped(_ sender: Any) {
        resolveAnchors()
    }
    
    private func fetchAnchors() {
        firebaseDbRoot.observe(.value) { (dataSnapshot) in
            guard let snapshotValue = dataSnapshot.value as? [String: Any] else {
                return
            }
            
            let values = snapshotValue.values
            
            values.forEach({ (value) in
                if let dict = value as? [String: Any], let anchorId = dict["hosted_anchor_id"] as? String {
                    self.anchorIDList.append(anchorId)
                }
            })
            
        }
    }
    
    private func hostAnchor(transform: matrix_float4x4) {
        let anchor = ARAnchor(transform: transform)
        sceneView.session.add(anchor: anchor)
        
        do {
            try garSession.hostCloudAnchor(anchor)
            
        } catch {
            print(error)
            
            let alertViewController = UIAlertController(title: "Error", message: "Could not host anchors", preferredStyle: .alert)
            let oKAlertAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            let tryAgainAlertAction = UIAlertAction(title: "Try Again", style: .default) { (action) in
                self.hostAnchor(transform: transform)
            }
            
            alertViewController.addAction(oKAlertAction)
            alertViewController.addAction(tryAgainAlertAction)
            
            self.present(alertViewController, animated: true, completion: nil)
        
        }
    }
    
    private func resolveAnchors() {
        self.anchorIDList.forEach { (anchorId) in
            do {
                try garSession.resolveCloudAnchor(withIdentifier: anchorId)
            } catch {
                print(error)
                
                let alertViewController = UIAlertController(title: "Error", message: "Could not host anchors because \(error.localizedDescription)", preferredStyle: .alert)
                let oKAlertAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                let tryAgainAlertAction = UIAlertAction(title: "Try Again", style: .default) { (action) in
                    self.resolveAnchors()
                }
                
                alertViewController.addAction(oKAlertAction)
                alertViewController.addAction(tryAgainAlertAction)
                
                self.present(alertViewController, animated: true, completion: nil)
            }
            
        }
        
        self.anchorIDList.removeAll()
        self.firebaseDbRoot.removeValue()
        
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        
        if !(anchor is ARPlaneAnchor) {
            let scene = SCNScene(named: "art.scnassets/ship.scn")!
            return scene.rootNode.childNode(withName: "ship", recursively: false)
        }
        return nil
        
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
      
        do {
            try garSession.update(frame)
        
        } catch {
            print(error)
            
            let alertViewController = UIAlertController(title: "Error", message: "Could not update frames", preferredStyle: .alert)
            let oKAlertAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            
            alertViewController.addAction(oKAlertAction)
            
            self.present(alertViewController, animated: true, completion: nil)
            
        }
    }
    
    func session(_ session: GARSession, didHostAnchor anchor: GARAnchor) {
        let cloudId = anchor.cloudIdentifier
        firebaseDbRoot.childByAutoId().child("hosted_anchor_id").setValue(cloudId)
    }
    
    func session(_ session: GARSession, didResolve anchor: GARAnchor) {
        let anchor = ARAnchor(transform: anchor.transform)
        sceneView.session.add(anchor: anchor)
    }
    
    func session(_ session: GARSession, didFailToHostAnchor anchor: GARAnchor) {
        let alertViewController = UIAlertController(title: "Error", message: "Could not host anchor with cloudId: \(String(describing: anchor.cloudIdentifier)) and cloudState: \(String(describing: anchor.cloudState.rawValue))", preferredStyle: .alert)
        let oKAlertAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        
        alertViewController.addAction(oKAlertAction)
        
        self.present(alertViewController, animated: true, completion: nil)
        
    }
    
    func session(_ session: GARSession, didFailToResolve anchor: GARAnchor) {
        let alertViewController = UIAlertController(title: "Error", message: "Could not resolve anchor with cloudId: \(String(describing: anchor.cloudIdentifier)) and cloudState: \(String(describing:anchor.cloudState.rawValue))", preferredStyle: .alert)
        let oKAlertAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        
        alertViewController.addAction(oKAlertAction)
        
        self.present(alertViewController, animated: true, completion: nil)
        
    }
}
