//
//  ConsumerPointItem.swift
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

// MARK: -
// MARK: -

/**
 Consumer Point Item
 
 A collection view item which allows for display of a point.

*/

class ConsumerPointItem: NSCollectionViewItem {
    
    /// The identifier of the point item.
    static let nibName = "ConsumerPointItem"

    /// The identifier of the point item.
    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "consumerPointItemIdentifier")

    /// The size of the point item.
    static let itemSize: NSSize = NSSize(width: 380.0, height: 276.0)

    /// The text to use when there is no module, or a module is 'started'.
    static let emptyValue: String = "--"
    
    /// Used for display of the point address.
    @IBOutlet var address: NSTextField!
    
    /// Used for display of the point priority.
    @IBOutlet var priority: NSTextField!
    
    /// Used for display of the point name.
    @IBOutlet var name: NSTextField!
    
    /// Used for display of the winning producer name.
    @IBOutlet var producerName: NSTextField!
    
    /// Used for display of the winning producer CID.
    @IBOutlet var producerCID: NSTextField!
    
    /// Used for display and editing the position module values.
    @IBOutlet var posX, posY, posZ, posUnit: NSTextField!
    
    /// Used for display and editing the position velocity/acceleration module values.
    @IBOutlet var posVelX, posVelY, posVelZ, posAccelX, posAccelY, posAccelZ: NSTextField!
    
    /// Used for display and editing the rotation module values.
    @IBOutlet var rotX, rotY, rotZ: NSTextField!
    
    /// Used for display and editing the rotation velocity/acceleration module values.
    @IBOutlet var rotVelX, rotVelY, rotVelZ, rotAccelX, rotAccelY, rotAccelZ: NSTextField!
    
    /// Used for display and editing the scale module values.
    @IBOutlet var scaleX, scaleY, scaleZ: NSTextField!
    
    /// Used for display and editing the parent module values.
    @IBOutlet var parentSystem, parentGroup, parentPoint: NSTextField!
    
    /// Used for display and editing the parent scale value.
    @IBOutlet var parentRelative: NSButton!

    override func viewDidLoad() {
        
        super.viewDidLoad()

    }
    
    /**
     Refreshes any fields related to the position module.
     
     - Parameters:
        - module: An optional position module.
     
    */
    func refreshPosition(_ module: OTPModulePosition?) {

        let enable = module != nil

        posX.isEnabled = enable
        posY.isEnabled = enable
        posZ.isEnabled = enable
        
        if let module = module {
            
            posX.stringValue = "\(module.x)"
            posY.stringValue = "\(module.y)"
            posZ.stringValue = "\(module.z)"
            posUnit.stringValue = module.scaling == .mm ? "mm" : "μm"

        } else {
            
            posX.stringValue = Self.emptyValue
            posY.stringValue = Self.emptyValue
            posZ.stringValue = Self.emptyValue
            posUnit.stringValue = "μm"
            
        }
        
    }
    
    /**
     Refreshes any fields related to the position velocity/acceleration module.
     
     - Parameters:
        - module: An optional position velocity/acceleration module.
     
    */
    func refreshPositionVelAccel(_ module: OTPModulePositionVelAccel?) {
        
        let enable = module != nil
        
        posVelX.isEnabled = enable
        posVelY.isEnabled = enable
        posVelZ.isEnabled = enable
        posAccelX.isEnabled = enable
        posAccelY.isEnabled = enable
        posAccelZ.isEnabled = enable
        
        if let module = module {

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
     
    */
    func refreshRotation(_ module: OTPModuleRotation?) {
        
        let enable = module != nil
        
        rotX.isEnabled = enable
        rotY.isEnabled = enable
        rotZ.isEnabled = enable
        
        if let module = module {
            
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
     
    */
    func refreshRotationVelAccel(_ module: OTPModuleRotationVelAccel?) {
        
        let enable = module != nil
        
        rotVelX.isEnabled = enable
        rotVelY.isEnabled = enable
        rotVelZ.isEnabled = enable
        rotAccelX.isEnabled = enable
        rotAccelY.isEnabled = enable
        rotAccelZ.isEnabled = enable
        
        if let module = module {

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
    
}
