//
//  CanvasViewController.swift
//  VPL
//
//  Created by Nathan Flurry on 3/13/18.
//  Copyright © 2018 Nathan Flurry. All rights reserved.
//

import UIKit

class CanvasViewController: UIViewController {
    /// Shortcut for custom node popover.
    var customNodeShortcut: String = "X"
    
    /// View nodes that can be created.
    var spawnableNodes: [DisplayableNode.Type] = []
    
    /// Output of the code.
    var outputView: UITextView!
    
    /// Canvas that holds all of the nodes
    var nodeCanvas: DisplayNodeCanvas!
    
    /// Canvas for all of the drawing for quick shortcuts
    var drawingCanvas: DrawingCanvas!
    
    /// Timer for committing shortcuts
    var commitDrawingTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add the text
        outputView = UITextView(frame: CGRect.zero)
        outputView.isEditable = false
        outputView.isSelectable = true
        view.addSubview(outputView)
        outputView.translatesAutoresizingMaskIntoConstraints = false
        outputView.rightAnchor.constraint(equalTo: view.rightAnchor).activate()
        outputView.topAnchor.constraint(equalTo: view.topAnchor).activate()
        outputView.bottomAnchor.constraint(equalTo: view.bottomAnchor).activate()
        outputView.widthAnchor.constraint(equalToConstant: 180).activate()
        
        // Add the node canvas
        nodeCanvas = DisplayNodeCanvas(frame: CGRect.zero)
        nodeCanvas.updateCallback = {
            let assembled = self.nodeCanvas.assemble()
            self.outputView.text = assembled
        }
        view.addSubview(nodeCanvas)
        nodeCanvas.translatesAutoresizingMaskIntoConstraints = false
        nodeCanvas.leftAnchor.constraint(equalTo: view.leftAnchor).activate()
        nodeCanvas.topAnchor.constraint(equalTo: view.topAnchor).activate()
        nodeCanvas.bottomAnchor.constraint(equalTo: view.bottomAnchor).activate()
        nodeCanvas.rightAnchor.constraint(equalTo: outputView.leftAnchor).activate()
        
        // Add drawing canvas
        drawingCanvas = DrawingCanvas(frame: view.bounds)
        drawingCanvas.onInputStart = {
            // Cancel the timer
            self.commitDrawingTimer?.invalidate()
            self.commitDrawingTimer = nil
        }
        drawingCanvas.onInputFinish = {
            // Start a timer to commit the drawing
            let timer = Timer(timeInterval: 0.5, repeats: false) { _ in
                // Remove the timer
                self.commitDrawingTimer = nil
                
                // Get the drawing
                guard let output = self.drawingCanvas.complete() else {
                    print("Drawing has no image.")
                    return
                }
                
                // Process
                try! OCRRequest(image: output, singleCharacter: true) { (result, breakdown) in
                    assert(breakdown.count == 1)
                    
                    // Get the character's center
                    guard let firstBreakdown = breakdown.first, let charResult = firstBreakdown else {
                        print("Failed to get first char breakdown.")
                        return
                    }
                    guard case let .some(character, _, charBox) = charResult else {
                        print("Could not get char box.")
                        return
                    }
                    let charCenter = CGPoint(x: charBox.midX, y: charBox.midY)
                    
                    // Overlay the breakdown for debug info
                    self.drawingCanvas.overlayOCRBreakdown(breakdown: breakdown)
                    
                    // Present custom node popover
                    if character == self.customNodeShortcut {
                        self.nodeListPopover(nodes: self.spawnableNodes, charBox: charBox, showShortcuts: true)
                    } else {
                        // Find the nodes for the character
                        let availableNodes = self.spawnableNodes.filter { $0.shortcutCharacter == character }
                        
                        // Create the node or popup a list
                        if availableNodes.count > 1 {
                            self.nodeListPopover(nodes: availableNodes, charBox: charBox, showShortcuts: false)
                        } else if let node = availableNodes.first {
                            self.create(node: node, position: charCenter)
                        } else {
                            print("No nodes with shortcut: \(character)")
                        }
                    }
                }
            }
            RunLoop.main.add(timer, forMode: RunLoopMode.defaultRunLoopMode)
            self.commitDrawingTimer = timer
        }
        view.addSubview(drawingCanvas)
        view.bringSubview(toFront: nodeCanvas)
        drawingCanvas.translatesAutoresizingMaskIntoConstraints = false
        drawingCanvas.leftAnchor.constraint(equalTo: view.leftAnchor).activate()
        drawingCanvas.topAnchor.constraint(equalTo: view.topAnchor).activate()
        drawingCanvas.bottomAnchor.constraint(equalTo: view.bottomAnchor).activate()
        drawingCanvas.rightAnchor.constraint(equalTo: outputView.leftAnchor).activate()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @discardableResult
    func create(node nodeType: DisplayableNode.Type, position: CGPoint) -> DisplayNode? {
        // Create the node
        let node = nodeType.init()
        
        // Create and insert the display node
        let displayNode = DisplayNode(node: node)
        displayNode.layoutIfNeeded()
        displayNode.center = position
        nodeCanvas.insert(node: displayNode)
        
        return displayNode
    }
    
    /// Creates a popover to create a node.
    func nodeListPopover(nodes: [DisplayableNode.Type], charBox: CGRect, showShortcuts: Bool) {
        // Create the controller
        let alert = UIAlertController(
            title: "Spawn Node",
            message: showShortcuts ? "Node shortcuts are displayed in parentheses." : nil,
            preferredStyle: .actionSheet
        )
        
        // Configure the popover
        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = charBox
        
        // Display the nodes
        let sortedNodes = nodes.sorted { $0.name < $1.name }
        for node in sortedNodes {
            // Create the title with the shortcut (only if listing all nodes)
            var title = node.name
            if let shortcut = node.shortcutCharacter, showShortcuts {
                title += " (\(shortcut))"
            }
            
            // Create an action to spawn the node
            let action = UIAlertAction(title: title, style: .default) { _ in
                self.create(node: node, position: CGPoint(x: charBox.midX, y: charBox.midY))
            }
            alert.addAction(action)
        }
        
        // Present it
        self.present(alert, animated: true)
    }
}
