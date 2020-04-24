//
//  ProducerPointItem.swift
//
//  Copyright (c) 2020 Daniel Murfin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Cocoa
import OTPKit

/**
 Producer Point Item Delegate
 
 Required methods for objects implementing this delegate.

*/

protocol ProducerPointItemDelegate: AnyObject {
    
    /**
     Notifies the delegate to remove an existing point.
     
     - Parameters:
        - pointIndex: The index of the point.
     
    */
    func removePoint(_ pointIndex: Int)
    
    /**
     Notifies the delegate to add a new module.
     
     - Parameters:
        - moduleType: The module type to be added.
        - pointIndex: The index of the point.

    */
    func addModule(_ moduleType: OTPModule.Type, toPointAtIndex pointIndex: Int)
    
    /**
     Notifies the delegate to remove an existing module.
     
     - Parameters:
        - moduleType: The module type to be removed.
        - pointIndex: The index of the point.
     
    */
    func removeModule(_ moduleType: OTPModule.Type, fromPointAtIndex pointIndex: Int)
    
    /**
     Notifies the delegate to update the name of this point.
     
     - Parameters:
        - name: The new name of this point.
        - pointIndex: The index of the point.
     
    */
    func updateName(_ name: String, forPointAtIndex pointIndex: Int)
    
    /**
     Notifies the delegate to update this module for this point.
     
     - Parameters:
        - module: The module to be updated for this point.
        - pointIndex: The index of the point.
     
    */
    func updateModule(_ module: OTPModule, forPointAtIndex pointIndex: Int)
    
    /**
     Notifies the delegate to start or stop a fade for this point.
     
     - Parameters:
        - pattern: The pattern to be used for the fade.
        - pointIndex: The index of the point.

    */
    func startStopFade(withPattern pattern: Fade.Pattern, forPointAtIndex pointIndex: Int)

}

// MARK: -
// MARK: -

/**
 Producer Point Item
 
 A collection view item which allows for editing of a point.

*/

class ProducerPointItem: NSCollectionViewItem {
    
    /// The identifier of the point item.
    static let nibName = "ProducerPointItem"

    /// The identifier of the point item.
    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "producerPointItemIdentifier")

    /// The size of the point item.
    static let itemSize: NSSize = NSSize(width: 310.0, height: 374.0)

    /// The text to use when there is no module, or a module is 'started'.
    static let emptyValue: String = "--"
    
    /// Used for display of the point address.
    @IBOutlet var address: NSTextField!
    
    /// Used for display of the point priority.
    @IBOutlet var priority: NSTextField!
    
    /// Used for display and editing of the point name.
    @IBOutlet var name: NSTextField!
    
    /// Used for starting and stopping the pattern fader.
    @IBOutlet var startStopButton: NSButton!
    
    /// Used for editing the pattern for the pattern fader.
    @IBOutlet var pattern: NSPopUpButton!
    
    /// Used for adding a position module.
    @IBOutlet var positionModule: NSButton!
    
    /// Used for display and editing the position module values.
    @IBOutlet var posX, posY, posZ, posUnit: NSTextField!

    /// Used for display and editing the position model scale value.
    @IBOutlet var posScale: NSButton!
    
    /// Used for adding a position velocity/acceleration module.
    @IBOutlet var positionVelAccelModule: NSButton!
    
    /// Used for display and editing the position velocity/acceleration module values.
    @IBOutlet var posVelX, posVelY, posVelZ, posAccelX, posAccelY, posAccelZ: NSTextField!
    
    /// Used for adding a rotation module.
    @IBOutlet var rotationModule: NSButton!
    
    /// Used for display and editing the rotation module values.
    @IBOutlet var rotX, rotY, rotZ: NSTextField!
    
    /// Used for adding a rotation velocity/acceleration module.
    @IBOutlet var rotationVelAccelModule: NSButton!
    
    /// Used for display and editing the rotation velocity/acceleration module values.
    @IBOutlet var rotVelX, rotVelY, rotVelZ, rotAccelX, rotAccelY, rotAccelZ: NSTextField!
    
    /// Used for adding a scale module.
    @IBOutlet var scaleModule: NSButton!
    
    /// Used for display and editing the scale module values.
    @IBOutlet var scaleX, scaleY, scaleZ: NSTextField!
    
    /// Used for adding a parent module.
    @IBOutlet var parentModule: NSButton!
    
    /// Used for display and editing the parent module values.
    @IBOutlet var parentSystem, parentGroup, parentPoint: NSTextField!
    
    /// Used for display and editing the parent scale value.
    @IBOutlet var parentRelative: NSButton!

    /// The presented index of this item.
    var index: Int?
    
    /// The delegate to receive notifications.
    weak var delegate: ProducerPointItemDelegate?

    override func viewDidLoad() {
        
        super.viewDidLoad()

        // assign the text field delegates
        name.delegate = self
        posX.delegate = self
        posY.delegate = self
        posZ.delegate = self
        posVelX.delegate = self
        posVelY.delegate = self
        posVelZ.delegate = self
        posAccelX.delegate = self
        posAccelY.delegate = self
        posAccelZ.delegate = self
        rotX.delegate = self
        rotY.delegate = self
        rotZ.delegate = self
        rotVelX.delegate = self
        rotVelY.delegate = self
        rotVelZ.delegate = self
        rotAccelX.delegate = self
        rotAccelY.delegate = self
        rotAccelZ.delegate = self
        scaleX.delegate = self
        scaleY.delegate = self
        scaleZ.delegate = self
        parentSystem.delegate = self
        parentGroup.delegate = self
        parentPoint.delegate = self
        
        // update the patterns available, and select the appropriate item
        pattern.removeAllItems()
        pattern.addItems(withTitles: Fade.Pattern.titles)

    }
    
    /**
     Refreshes any fields related to the pattern fader.
     
     - Parameters:
        - pattern: An optional fade pattern currently in progress.
     
    */
    func refreshPattern(activePattern: Fade.Pattern?) {
        
        // enable/disable the pattern selection
        pattern.isEnabled = activePattern == nil
        
        // select the pattern running (if any)
        if let activePattern = activePattern {
            pattern.selectItem(at: Fade.Pattern.allCases.firstIndex(of: activePattern) ?? 0)
        } else {
            pattern.selectItem(at: 0)
        }

        startStopButton.title = activePattern == nil ? "Start Fade" : "Stop Fade"
        
    }
    
    /**
     Refreshes any fields related to the position module.
     
     - Parameters:
        - module: An optional position module.
        - fading: Whether a fade is currently running.
     
    */
    func refreshPosition(_ module: OTPModulePosition?, fading: Bool) {
        
        let enable = fading ? false : module != nil

        positionModule.checked = module != nil
        positionModule.isEnabled = !fading
        positionVelAccelModule.isEnabled = enable
        posX.isEnabled = enable
        posY.isEnabled = enable
        posZ.isEnabled = enable
        posScale.isEnabled = enable
        
        if let module = module, !fading {
            
            posX.stringValue = "\(module.x)"
            posY.stringValue = "\(module.y)"
            posZ.stringValue = "\(module.z)"
            posUnit.stringValue = module.scaling == .mm ? "mm" : "μm"
            posScale.checked = module.scaling == .mm

        } else {
            
            posX.stringValue = Self.emptyValue
            posY.stringValue = Self.emptyValue
            posZ.stringValue = Self.emptyValue
            posUnit.stringValue = "μm"
            posScale.checked = false
            
        }
        
    }
    
    /**
     Refreshes any fields related to the position velocity/acceleration module.
     
     - Parameters:
        - module: An optional position velocity/acceleration module.
        - fading: Whether a fade is currently running.
     
    */
    func refreshPositionVelAccel(_ module: OTPModulePositionVelAccel?, fading: Bool) {
        
        let enable = fading ? false : module != nil
        
        positionVelAccelModule.checked = module != nil
        posVelX.isEnabled = enable
        posVelY.isEnabled = enable
        posVelZ.isEnabled = enable
        posAccelX.isEnabled = enable
        posAccelY.isEnabled = enable
        posAccelZ.isEnabled = enable
        
        if let module = module, !fading {

            posVelX.stringValue = "\(module.vX)"
            posVelY.stringValue = "\(module.vY)"
            posVelZ.stringValue = "\(module.vZ)"
            posAccelX.stringValue = "\(module.aX)"
            posAccelY.stringValue = "\(module.aY)"
            posAccelZ.stringValue = "\(module.aZ)"

        } else {
            
            posVelX.stringValue = Self.emptyValue
            posVelY.stringValue = Self.emptyValue
            posVelZ.stringValue = Self.emptyValue
            posAccelX.stringValue = Self.emptyValue
            posAccelY.stringValue = Self.emptyValue
            posAccelZ.stringValue = Self.emptyValue
            
        }
        
    }
    
    /**
     Refreshes any fields related to the rotation module.
     
     - Parameters:
        - module: An optional rotation module.
        - fading: Whether a fade is currently running.
     
    */
    func refreshRotation(_ module: OTPModuleRotation?, fading: Bool) {
        
        let enable = fading ? false : module != nil

        rotationModule.checked = module != nil
        rotationModule.isEnabled = !fading
        rotationVelAccelModule.isEnabled = enable
        rotX.isEnabled = enable
        rotY.isEnabled = enable
        rotZ.isEnabled = enable
        
        if let module = module, !fading {
            
            rotX.stringValue = "\(Double(module.x) / 1000000)"
            rotY.stringValue = "\(Double(module.y) / 1000000)"
            rotZ.stringValue = "\(Double(module.z) / 1000000)"

        } else {
            
            rotX.stringValue = Self.emptyValue
            rotY.stringValue = Self.emptyValue
            rotZ.stringValue = Self.emptyValue
            
        }
        
    }
    
    /**
     Refreshes any fields related to the rotation velocity/acceleration module.
     
     - Parameters:
        - module: An optional rotation velocity/acceleration module.
        - fading: Whether a fade is currently running.
     
    */
    func refreshRotationVelAccel(_ module: OTPModuleRotationVelAccel?, fading: Bool) {
        
        let enable = fading ? false : module != nil
        
        rotationVelAccelModule.checked = module != nil
        rotVelX.isEnabled = enable
        rotVelY.isEnabled = enable
        rotVelZ.isEnabled = enable
        rotAccelX.isEnabled = enable
        rotAccelY.isEnabled = enable
        rotAccelZ.isEnabled = enable
        
        if let module = module, !fading {

            rotVelX.stringValue = "\(Double(module.vX) / 1000)"
            rotVelY.stringValue = "\(Double(module.vY) / 1000)"
            rotVelZ.stringValue = "\(Double(module.vZ) / 1000)"
            rotAccelX.stringValue = "\(Double(module.aX) / 1000)"
            rotAccelY.stringValue = "\(Double(module.aY) / 1000)"
            rotAccelZ.stringValue = "\(Double(module.aZ) / 1000)"

        } else {
            
            rotVelX.stringValue = Self.emptyValue
            rotVelY.stringValue = Self.emptyValue
            rotVelZ.stringValue = Self.emptyValue
            rotAccelX.stringValue = Self.emptyValue
            rotAccelY.stringValue = Self.emptyValue
            rotAccelZ.stringValue = Self.emptyValue
            
        }
       
    }
    
    /**
     Refreshes any fields related to the scale module.
     
     - Parameters:
        - module: An optional scale module.
     
    */
    func refreshScale(_ module: OTPModuleScale?) {
        
        let enable = module != nil
        
        scaleModule.checked = enable
        scaleX.isEnabled = enable
        scaleY.isEnabled = enable
        scaleZ.isEnabled = enable
        
        if let module = module {
            
            scaleX.stringValue = "\(Double(module.x) / 1000000)"
            scaleY.stringValue = "\(Double(module.y) / 1000000)"
            scaleZ.stringValue = "\(Double(module.z) / 1000000)"

        } else {
            
            scaleX.stringValue = Self.emptyValue
            scaleY.stringValue = Self.emptyValue
            scaleZ.stringValue = Self.emptyValue
            
        }
        
    }
    
    /**
     Refreshes any fields related to the parent module.
     
     - Parameters:
        - module: An optional parent module.
     
    */
    func refreshParent(_ module: OTPModuleParent?) {
        
        let enable = module != nil
        
        parentModule.checked = enable
        parentSystem.isEnabled = enable
        parentGroup.isEnabled = enable
        parentPoint.isEnabled = enable
        parentRelative.isEnabled = enable
        
        if let module = module {
            
            parentSystem.stringValue = "\(module.systemNumber)"
            parentGroup.stringValue = "\(module.groupNumber)"
            parentPoint.stringValue = "\(module.pointNumber)"
            parentRelative.checked = module.relative

        } else {
            
            parentSystem.stringValue = Self.emptyValue
            parentGroup.stringValue = Self.emptyValue
            parentPoint.stringValue = Self.emptyValue
            parentRelative.checked = false
            
        }
        
    }
    
    /**
     Adds or removes the module associated with this button.
     
     - Parameters:
        - sender: The button sending this action.
     
     */
    @IBAction func addRemoveModule(_ sender: NSButton) {

        // a point index must have been provided
        guard let pointIndex = index else { return }

        // all module types (including associated)
        var moduleTypes: [OTPModule.Type]
        switch sender {
        case positionModule:
            moduleTypes = [OTPModulePosition.self, OTPModulePositionVelAccel.self]
        case positionVelAccelModule:
            moduleTypes = [OTPModulePositionVelAccel.self]
        case rotationModule:
            moduleTypes = [OTPModuleRotation.self, OTPModuleRotationVelAccel.self]
        case rotationVelAccelModule:
            moduleTypes = [OTPModuleRotationVelAccel.self]
        case scaleModule:
            moduleTypes = [OTPModuleScale.self]
        case parentModule:
            moduleTypes = [OTPModuleParent.self]
        default:
            moduleTypes = [OTPModulePosition.self]
        }
        
        // notify the delegate to add or remove the module
        if sender.checked, let moduleType = moduleTypes.first {
            delegate?.addModule(moduleType, toPointAtIndex: pointIndex)
        } else {
            // remove any associated first
            moduleTypes.reversed().forEach { delegate?.removeModule($0, fromPointAtIndex: pointIndex) }
        }
        
    }
    
    /**
     Updates the module associated with this button.
     
     - Parameters:
        - sender: The button sending this action.
     
    */
    @IBAction func changeModule(_ sender: NSButton) {
        
        // a point index must have been provided
        guard let pointIndex = index else { return }

        switch sender {
        case posScale:
            
            let module = OTPModulePosition(x: posX.intValue, y: posY.intValue, z: posZ.intValue, scaling: posScale.checked ? .mm : .μm)
            delegate?.updateModule(module, forPointAtIndex: pointIndex)
            
        case parentRelative:
            
            // there must be valid values for each field
            guard let system = OTPSystemNumber(parentSystem.stringValue), let group = OTPGroupNumber(parentGroup.stringValue), let point = OTPPointNumber(parentPoint.stringValue) else { return }
                        
            do {
                
                let address = try OTPAddress(system, group, point)
                
                let module = OTPModuleParent(address: address, relative: parentRelative.checked)
                delegate?.updateModule(module, forPointAtIndex: pointIndex)

            } catch {
                
                // restore the state of the check box
                sender.checked.toggle()
                
            }

        default:
            break
        }

    }
    
    /**
     Removes this point.
     
     - Parameters:
        - sender: The button sending this action.
     
    */
    @IBAction func removePoint(_ sender: NSButton) {
        
        // a point index must have been provided
        guard let pointIndex = index else { return }
        
        delegate?.removePoint(pointIndex)

    }
    
    /**
     Starts or stops a fade for this point.
     
     - Parameters:
        - sender: The button sending this action.
     
    */
    @IBAction func startStopFade(_ sender: NSButton) {
        
        // a point index must have been provided
        guard let pointIndex = index else { return }
        
        // get the selected pattern
        let pattern = Fade.Pattern.allCases[self.pattern.indexOfSelectedItem]
        
        // notify the delegate to start the fade
        delegate?.startStopFade(withPattern: pattern, forPointAtIndex: pointIndex)

    }
    
}

// MARK: -
// MARK: -

/**
 Point Item Extension
 
 Extensions to `PointItem` to handle text field delegate notifications.

*/

extension ProducerPointItem: NSTextFieldDelegate {
    
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        
        // a point index must have been provided
        guard let pointIndex = index else { return true }
        
        let string = fieldEditor.string

        switch control {
        case name:
            delegate?.updateName(string, forPointAtIndex: pointIndex)
        case posX, posY, posZ:
            let module = OTPModulePosition(x: posX.intValue, y: posY.intValue, z: posZ.intValue, scaling: posScale.checked ? .mm : .μm)
            delegate?.updateModule(module, forPointAtIndex: pointIndex)
        case posVelX, posVelY, posVelZ, posAccelX, posAccelY, posAccelZ:
            let module = OTPModulePositionVelAccel(vX: posVelX.intValue, vY: posVelY.intValue, vZ: posVelZ.intValue, aX: posAccelX.intValue, aY: posAccelY.intValue, aZ: posAccelZ.intValue)
            delegate?.updateModule(module, forPointAtIndex: pointIndex)
        case rotX, rotY, rotZ:

            // get valid values for each field
            let rotXValue = OTPModuleRotation.validValue(from: rotX.stringValue)
            let rotYValue = OTPModuleRotation.validValue(from: rotY.stringValue)
            let rotZValue = OTPModuleRotation.validValue(from: rotZ.stringValue)

            let module = OTPModuleRotation(x: rotXValue, y: rotYValue, z: rotZValue)
            delegate?.updateModule(module, forPointAtIndex: pointIndex)
            
        case rotVelX, rotVelY, rotVelZ, rotAccelX, rotAccelY, rotAccelZ:

            // get valid values for each field
            let rotVelXValue = OTPModuleRotationVelAccel.validValue(from: rotVelX.stringValue)
            let rotVelYValue = OTPModuleRotationVelAccel.validValue(from: rotVelY.stringValue)
            let rotVelZValue = OTPModuleRotationVelAccel.validValue(from: rotVelZ.stringValue)
            let rotAccelXValue = OTPModuleRotationVelAccel.validValue(from: rotAccelX.stringValue)
            let rotAccelYValue = OTPModuleRotationVelAccel.validValue(from: rotAccelY.stringValue)
            let rotAccelZValue = OTPModuleRotationVelAccel.validValue(from: rotAccelZ.stringValue)

            let module = OTPModuleRotationVelAccel(vX: rotVelXValue, vY: rotVelYValue, vZ: rotVelZValue, aX: rotAccelXValue, aY: rotAccelYValue, aZ: rotAccelZValue)
            delegate?.updateModule(module, forPointAtIndex: pointIndex)

        case scaleX, scaleY, scaleZ:
            
            // get valid values for each field
            let scaleXValue = OTPModuleScale.validValue(from: scaleX.stringValue)
            let scaleYValue = OTPModuleScale.validValue(from: scaleY.stringValue)
            let scaleZValue = OTPModuleScale.validValue(from: scaleZ.stringValue)
            
            let module = OTPModuleScale(x: scaleXValue, y: scaleYValue, z: scaleZValue)
            delegate?.updateModule(module, forPointAtIndex: pointIndex)
            
        case parentSystem, parentGroup, parentPoint:
            
            // there must be valid values for each field
            guard let system = OTPSystemNumber(parentSystem.stringValue), let group = OTPGroupNumber(parentGroup.stringValue), let point = OTPPointNumber(parentPoint.stringValue) else { return true }
                        
            do {
                
                let address = try OTPAddress(system, group, point)
                
                let module = OTPModuleParent(address: address, relative: parentRelative.checked)
                delegate?.updateModule(module, forPointAtIndex: pointIndex)

            } catch {
                // continue
            }

        default:
            break
        }

        return true
        
    }
    
}
