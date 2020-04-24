//
//  AddPointController.swift
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
 Add Point Controller Delegate
 
 Required methods for objects implementing this delegate.

*/

protocol AddPointControllerDelegate: AnyObject {
    
    /**
     Provides the delgate with a new point instance.
     
     - Parameters:
        - point: The newly created point.
     
    */
    func addPoint(_ point: OTPPoint)
    
}

/**
 Add Point Controller
 
 Displays a dialog for creating a new point.

*/

final class AddPointController: NSViewController {

    /// Used for entering the system number of the new point.
    @IBOutlet var systemNumber: NSTextField!
    
    /// Used for entering the group number of the new point.
    @IBOutlet var groupNumber: NSTextField!
    
    /// Used for entering the point number of the new point.
    @IBOutlet var pointNumber: NSTextField!
    
    /// Used for entering a name for the new point.
    @IBOutlet var name: NSTextField!
    
    /// Used for selecting the priority of the new point.
    @IBOutlet var priority: NSPopUpButton!
    
    /// Used for creating the new point.
    @IBOutlet var addButton: NSButton!
    
    /// The priority of the producer creating this point.
    var producerPriority: UInt8?
    
    /// The points assigned to this producer.
    var existingPoints: [OTPPoint]?
    
    /// The delegate which should receive notifications from the controller.
    weak var delegate: AddPointControllerDelegate?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // prepare any popups
        preparePopups()
        
        // prepare the add button
        prepareAddButton()
        
    }
    
    /**
     Prepares the user interface for all popups.
    */
    private func preparePopups() {

        // add titles for all priorities
        priority.removeAllItems()
        priority.addItems(withTitles: ProducerModel.priorities.map { "\($0)" })
        
        // select either the producer's priority, or the default priority
        priority.selectItem(at: Int(producerPriority ?? 100))

    }
    
    /**
     Prepares the user interface for the add button.
    */
    private func prepareAddButton() {

        // disable the add button if invalid values are selected
        if let existing = existingPoints, let address = validAddress(), !existing.contains(where: { $0.address == address && $0.priority == selectedPriority() }) {
            addButton.isEnabled = true
        } else {
            addButton.isEnabled = false
        }

    }
    
    /**
     Calculates the selected priority.
     
     - Returns: The selected priority.
     
    */
    private func selectedPriority() -> UInt8 {
        ProducerModel.priorities[priority.indexOfSelectedItem]
    }
    
    /**
     Calculates a valid address from the values entered.
     
     - Returns: An optional address.
     
    */
    private func validAddress() -> OTPAddress? {
        
        guard let system = OTPSystemNumber(systemNumber.stringValue), let group = OTPGroupNumber(groupNumber.stringValue), let point = OTPPointNumber(pointNumber.stringValue) else { return nil }
        
        do {

            let address = try OTPAddress(system, group, point)
            
            // return the valid address
            return address

        } catch {
            return nil
        }
        
    }
    
    /**
     Creates a new point using the values entered.
     
        - Parameters:
            - sender: The button sending this action.
     
    */
    @IBAction func createPoint(_ sender: NSButton) {
        
        // there must be a valid address
        guard let address = validAddress() else { return }
        
        // create the point
        let newPoint = OTPPoint(address: address, priority: selectedPriority(), name: name.stringValue)
        
        // provide the point to the delegate
        delegate?.addPoint(newPoint)
        
        dismiss(self)
        
    }
    
    /**
     Called whenever the priority popup changes its value.
     
        - Parameters:
            - sender: The popup button sending this action.
     
    */
    @IBAction func changePriority(_ sender: NSPopUpButton) {
        
        // prepare the add button
        prepareAddButton()
        
    }
    
}

// MARK: -
// MARK: -

/**
 Add Point Controller Extension
 
 Extensions to `AddPointController` to handle text field delegate notifications.

*/

extension AddPointController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        
        // prepare the add button
        prepareAddButton()
        
    }
    
}
